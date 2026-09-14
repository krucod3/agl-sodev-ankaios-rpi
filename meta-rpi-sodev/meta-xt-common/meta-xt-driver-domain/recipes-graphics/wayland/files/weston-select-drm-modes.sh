#!/bin/sh
# Keep weston.ini's pinned modeline, EXCEPT on a head that demonstrably cannot use it.
#
# WHY THIS EXISTS
# weston.ini pins an explicit modeline on both outputs instead of selecting a mode by
# size, and the header of that file explains at length why: `mode=<WxH>` fails SILENTLY
# to a fallback when the mode is not in the connector's list at the moment weston
# enumerates it, and on the reference bench one panel has no EDID at all while the other
# answers 3.7 s late. Pinning is the right answer for those two panels.
#
# It is the wrong answer for every OTHER display. The pinned timings are 1920x720 --
# 111.75 MHz CVT on HDMI-A-1, and the 12.3FHD panel's own 93.24 MHz DTD on HDMI-A-2 (and
# on HDMI-A-1 too, on the RPi4 bench, where that panel is the one that is plugged in).
# An ordinary monitor does not have a 1920x720 mode, and forcing one at it reproduces
# exactly the failure the pin was introduced to prevent:
#
#     atomic: couldn't commit new state: Invalid argument
#     repaint-flush failed: No such file or directory
#
# repeated for the rest of the session, with the CRTC still scanning out fbcon -- so the
# screen shows the DomD text console -- while the guest sees a healthy virtio-gpu display
# and reports itself fine. That is the single hardest failure mode in this stack to
# diagnose from the guest side, and until this script existed the only fix was to mount
# the DomD rootfs on another machine and hand-edit weston.ini.
#
# THE RULE, AND WHY IT CANNOT REGRESS A WORKING BENCH
# Fall back to the head's own preferred mode only when BOTH of these hold:
#
#   1. the head has a non-empty EDID, and
#   2. the head's mode list does NOT contain the pinned resolution.
#
# Condition 1 keeps the pin wherever the pin is the only source of truth: a panel with no
# DDC at all (measured on the RPi5 bench, HDMI-A-1: /sys/.../edid is 0 bytes for the whole
# session) has nothing better to offer, and `preferred` there would select the generic DRM
# fallback list headed by 1024x768.
#
# Condition 2 keeps the pin wherever EDID and the pin agree. That covers both remaining
# bench heads, and it is worth being precise that they DO agree, because it is what makes
# this change safe without a board to test on:
#
#   RPi5 HDMI-A-2  EDID PNP(RTD) "12.3FHD", preferred DTD = 93.24 1920 1968 2010 2100
#                  720 723 733 740 -- byte-for-byte the pinned line (see weston.ini).
#   RPi4 HDMI-A-1  the same panel, moved to micro-HDMI 1. modetest 2026-08-04:
#                    #0 1920x720 60.00 1920 1968 2010 2100 720 723 733 740 93240
#                       type: preferred, driver
#
# So on every head of both verified benches at least one condition is false and this
# script changes nothing. It can only act on a head that has told us, via EDID, that the
# pinned resolution is not one it supports.
#
# Condition 2 is deliberately a RESOLUTION test, not a timing test: /sys/class/drm/*/modes
# lists modes as WxH only. A monitor that advertises 1920x720 with different timings
# therefore keeps the pin. That is the conservative direction -- it is what happens today,
# so it is not a regression -- and it is rare enough not to be worth a libdrm dependency
# in an ExecStartPre.
#
# STATELESSNESS
# There is no template file and no saved copy. When this script switches a head to
# `preferred` it stashes the pinned line next to it as
#
#     #mode-pinned=93.24 1920 1968 2010 2100 720 723 733 740 +hsync +vsync
#     mode=preferred
#
# and on the next boot it reads the marker back as that head's pinned mode. So the
# decision is recomputed from scratch every boot against whatever is actually plugged in:
# swap a generic monitor for the bench panel and the pin comes back (the marker is dropped
# and `mode=` is restored), swap it the other way and it goes again. Nothing accumulates.
#
# A head whose `mode=` is neither a modeline nor a stashed marker -- `mode=preferred`,
# `mode=1920x1080`, anything hand-written -- is left completely alone. Editing weston.ini
# by hand is therefore still the override it always was; this script only ever rewrites the
# `mode=` line of a head that carries a pin it can reason about.
#
# This never blocks the boot. Every failure path exits 0 and leaves weston.ini untouched:
# a wrong mode is a degraded display, a compositor that never starts is no display at all.
set -u

INI=${WESTON_INI:-/etc/xdg/weston/weston.ini}
DRM=${WESTON_DRM_SYSFS:-/sys/class/drm}

if [ ! -f "$INI" ]; then
    echo "weston-select-drm-modes: $INI does not exist, nothing to do" >&2
    exit 0
fi

# Every [output] that carries a pin we can reason about, as "<head>:<W>x<H>".
# The stashed marker wins over the live mode= line, so a head already switched to
# `preferred` on an earlier boot is still evaluated against its ORIGINAL pin.
pinned=$(awk '
    /^\[/                { sect=$0; name=""; pin=""; next }
    sect != "[output]"   { next }
    /^name=/             { name=substr($0, 6); pin=""; next }
    /^#mode-pinned=/     { pin=substr($0, 14); next }
    /^mode=/ {
        if (pin == "") pin = substr($0, 6)
        if (name == "") next
        # A full modeline is <clock> <hdisp> <hss> <hse> <htotal> <vdisp> ... -- at
        # least 9 numeric fields. Anything shorter is a symbolic or WxH mode.
        n = split(pin, f, /[ \t]+/)
        if (n >= 9 && f[1] ~ /^[0-9]/) print name ":" f[2] "x" f[6]
        next
    }
' "$INI")

want=""
for entry in $pinned; do
    head=${entry%%:*}
    res=${entry#*:}

    conn=""
    for c in "$DRM"/card*-"$head"; do
        [ -d "$c" ] && conn=$c
    done
    if [ -z "$conn" ]; then
        continue
    fi

    [ "$(cat "$conn/status" 2>/dev/null)" = "connected" ] || continue

    # No EDID: the pin is all we have. This is the RPi5 HDMI-A-1 case.
    if [ ! -s "$conn/edid" ]; then
        echo "weston-select-drm-modes: $head has no EDID, keeping the pinned mode" >&2
        continue
    fi

    # EDID agrees that the pinned resolution exists. Both bench panels land here.
    if grep -qx -- "$res" "$conn/modes" 2>/dev/null; then
        continue
    fi

    echo "weston-select-drm-modes: $head has an EDID but does not advertise $res;" \
         "falling back to its preferred mode" >&2
    want="$want $head"
done

# Nothing to switch AND nothing switched on an earlier boot: the file is already
# what it should be. The marker test is what makes the revert direction work -- with
# `want` empty but a marker present the rewrite pass below is exactly what drops the
# marker and puts `mode=<pinned>` back.
if [ -z "$want" ] && ! grep -q '^#mode-pinned=' "$INI"; then
    exit 0
fi

# Rewrite in place. The awk mirrors the pass above: same marker-beats-mode= precedence,
# same "is this a modeline" test, so a head skipped there is untouched here.
tmp="$INI.tmp.$$"
if ! awk -v want_list="$want" '
    BEGIN {
        n = split(want_list, a, /[ \t]+/)
        for (i = 1; i <= n; i++) if (a[i] != "") want[a[i]] = 1
    }
    /^\[/                { sect=$0; name=""; pin=""; print; next }
    sect != "[output]"   { print; next }
    /^name=/             { name=substr($0, 6); pin=""; print; next }
    # Swallowed unconditionally: it is re-emitted below only if the head still needs it.
    /^#mode-pinned=/     { pin=substr($0, 14); next }
    /^mode=/ {
        if (pin == "") pin = substr($0, 6)
        n2 = split(pin, f, /[ \t]+/)
        if (name == "" || n2 < 9 || f[1] !~ /^[0-9]/) { print; next }
        if (name in want) {
            print "#mode-pinned=" pin
            print "mode=preferred"
        } else {
            print "mode=" pin
        }
        next
    }
                         { print }
' "$INI" > "$tmp"; then
    echo "weston-select-drm-modes: could not write $tmp, leaving $INI as it is" >&2
    rm -f "$tmp"
    exit 0
fi

chmod 0644 "$tmp" 2>/dev/null
if ! mv "$tmp" "$INI"; then
    echo "weston-select-drm-modes: could not replace $INI (read-only rootfs?)," \
         "leaving it as it is" >&2
    rm -f "$tmp"
fi

exit 0
