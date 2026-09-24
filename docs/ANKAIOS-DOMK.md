# Ankaios DomK extension strategy

> **Status:** RPi4 PoC implementation present. Recipe parsing and package tasks
have been validated; full image and hardware validation remain pending.
>
> **First target:** a proof of concept on Raspberry Pi 4 with 4 GiB RAM. DomK
owns HDMI-A-1 and may run alone or alongside DomU on HDMI-A-2.

## Purpose

DomK is a proposed AGL-based Xen guest at the same architectural level as DomU
and DomA. Its purpose is to host Ankaios-managed container workloads without
putting the container runtime in the privileged driver domain.

The intended full guest stack is:

```text
DomK
|- AGL-derived Linux image
|- Ankaios server
|- Ankaios agent
|- Podman
|- crun (default OCI runtime)
|- Wayland compositor
`- virtio graphics, input, audio, network and storage devices
```

Podman and `crun` belong only in DomK. Keeping them out of DomD limits the
container runtime's access to physical devices and the Xen control plane.
The `ank` CLI should be installed in both places:

- DomD is the normal operator location and reaches the Ankaios server over the
  existing `192.168.10.0/24` guest network.
- DomK retains a local copy for recovery and diagnosis when guest networking is
  unavailable.

Podman 5.0.1 and `crun` 1.14.3 come from the Scarthgap
`meta-virtualization` layer. Ankaios uses the binary recipe from
`meta-ankaios` branch `update_scarthgap`, pinned to commit
`cfb5e3062aa745699c1cd28ae9fafa9fda35e6d8` (Ankaios 1.0.3).
DomD uses the Wrynose-compatible `update_wrynose` branch pinned to
`df407e3d19a5efc70271451a87341ee0ab835e85` and installs only its `ank-bin`
split package.

## Raspberry Pi 4 proof of concept

The PoC deliberately constrains the problem before adding multiple graphical
guests:

| Property | PoC decision |
|---|---|
| Board | Raspberry Pi 4 Model B |
| RAM | 4 GiB |
| Dom0 | Existing Zephyr default |
| DomD | Existing 1024 MiB allocation |
| Application guests | DomK alone or DomU + DomK; DomA disabled |
| DomK memory | Start with 1024 MiB |
| DomK vCPUs | One, pinned to pCPU 3 initially |
| Display | DomK on HDMI-A-1, the connector verified on this bench |
| Input | virtio keyboard and tablet |
| Graphics | `virtio-gpu-gl-pci` through QEMU in DomD |
| Audio | Expose `virtio-snd`; physical playback is a separate milestone |
| Network | Static DHCP lease proposed at `192.168.10.15` |
| Storage | PARTLABEL-based root disk, at least 8 GiB |

Graphical Ankaios workloads run as Wayland clients inside DomK. Their workload
definitions need access to DomK's Wayland socket and, where required, its render
and audio sockets. Containers do not receive the physical VC4 device; DomD
continues to own VC4/V3D and Weston, while QEMU presents DomK with a virtual GPU.

The 4 GiB configuration has approximately this fixed allocation before DomK:

```text
Dom0 (Zephyr placement)   128 MiB usable
DomD                     1024 MiB
Xen overhead              ~80 MiB
```

A 1024 MiB DomK and 1024 MiB DomU fit together with approximately 700 MiB left
for Xen headroom. Container memory limits should still be part of the PoC
because image unpacking and unbounded workloads can exhaust a 1 GiB guest
independently of Xen's remaining host memory.

## Display policy for the PoC

The PoC uses a build-time static assignment: DomK maps to HDMI-A-1 and DomU maps
to HDMI-A-2 when enabled. This assignment is reliable when both outputs exist
before the QEMU surfaces are created. It is not strict output reservation:
Weston 13 kiosk-shell falls back to the focused or default output when an
application's configured output does not exist. With only one display connected,
both guests can therefore land on that output, and the guest activated last can
replace the other fullscreen surface. Moving one cable between HDMI ports can
consequently show the DomU cluster on either port; this is fallback placement,
not DRM clone mode. For the initial single-display PoC, build DomK without DomU
so HDMI-A-1 consistently shows DomK.

**TODO:** Add strict kiosk-shell output reservation for configured app IDs. A
surface whose assigned connector is absent must remain hidden instead of falling
back to another output, and it must be assigned when its connector later appears.
Cover initial single-output startup and connector hotplug without disrupting a
surface already displayed on the other output.

The current RPi4 mechanism, `RPI4_PANEL_GUEST`, is also static: the image build
rewrites kiosk-shell's `app-ids` mapping so either DomU or DomA owns HDMI-A-1.
Weston kiosk-shell does not dynamically reload that mapping. Extending the
allowed value to DomK is the natural PoC implementation, while preserving the
invariant that each guest app-id appears on exactly one output.

Automatic fallback from DomA to DomK is not recommended for the first version:

- A slow DomA boot is difficult to distinguish reliably from a failed boot.
- Reassigning a running surface is not supported by the current static
  kiosk-shell configuration.
- Rewriting `weston.ini` requires restarting Weston, which disrupts every guest
  display and its input focus.
- A fallback tied to DomA health would couple display ownership to an unrelated
  guest lifecycle policy.

If a later system must recover a panel when DomA fails, use an explicit operator
or boot policy that stops the affected graphical QEMU frontend and starts a
known display profile. Do not silently switch on a timeout.

## Possible full extension

Both RPi4 and RPi5 can host three graphical QEMU surfaces, but both boards have
only two HDMI connectors. DomU, DomA and DomK may run concurrently where RAM
allows, while no more than two can have dedicated fullscreen physical outputs.
"Graphical-capable" therefore must not imply "permanently visible."

A later implementation can provide explicit display profiles:

| Profile | HDMI-A-1 | HDMI-A-2 |
|---|---|---|
| `cockpit` | DomU | DomA |
| `ankaios` | DomK | DomA |
| `development` | DomU | DomK |

The profile should be selected before Weston and graphical QEMU frontends start.
The unselected guest may continue headless. Runtime switching is a separate
feature requiring a compositor control mechanism or a controlled Weston/QEMU
restart sequence. Split-screen composition is also separate because the current
kiosk-shell policy makes each mapped surface fullscreen.

Indicative, unverified resource targets for the broader extension are:

| Platform | Guest combination | DomK target | Assessment |
|---|---|---:|---|
| RPi4 4 GiB | DomK only (PoC) | 1024 MiB | Initial supported target |
| RPi4 4 GiB | DomU + DomK | 1024 MiB | Included in the PoC; hardware validation pending |
| RPi4 8 GiB | DomU + DomA + DomK | 1024-1536 MiB | RAM fits; CPU/GPU/DomD load unverified |
| RPi5 8 GiB | DomU + DomA + DomK | 1024 MiB | Existing map has insufficient headroom |
| RPi5 16 GiB | DomU + DomA + DomK | 1536-2048 MiB | Best later triple-guest target |

Three guests on four physical cores require CPU sharing. A future resource plan
must protect enough DomD time for Weston and three QEMU device models, then tune
Credit2 weights from measurements rather than assuming pinning alone provides
isolation.

## Implementation plan

1. **Add the PoC build gate.** Add `ENABLE_ANKAIOS` and `-k/--ankaios`, restricted
   to `--board=rpi4 --ram=4g`. Allow DomU and reject combinations with DomA.
2. **Create the DomK guest image.** Add a small common DomK layer and an
   RPi4-compatible AGL image with systemd, cgroups v2 and the required virtio
   guest drivers.
3. **Integrate the container stack.** Supply pinned Yocto recipes for Podman and
   `crun`, configure `crun` as Podman's runtime, and prove a bounded test
   container can start and stop.
4. **Integrate Ankaios.** Add pinned server, agent and `ank` recipes. Run server
   and agent in DomK; install only `ank` and its endpoint configuration in DomD.
5. **Add DomK Xen lifecycle.** Add `domk.cfg` and `xl-create-domk.service`, with
   one vCPU, 1024 MiB RAM, virtual GPU, keyboard, tablet, sound, network and
   PARTLABEL-backed block storage.
6. **Assign the display statically.** Generalize `RPI4_PANEL_GUEST` to accept
   DomK and map DomK's unique QEMU WMCLASS to HDMI-A-1. Keep touch associated
   with the physical output, as the current RPi4 integration does.
7. **Add image storage and networking.** Add an 8 GiB DomK partition, a unique
   MAC and the proposed `.15` lease. Avoid fixed `/dev/mmcblk0pN` references.
8. **Validate in layers.** Prove boot and networking first, then Podman/`crun`,
   Ankaios control from DomD, software-rendered Wayland output, virgl graphics,
   keyboard/tablet input, and finally stress memory and GPU behavior.
9. **Defer audio completion.** Verify the virtual sound device independently;
   choose PipeWire, USB audio or HDMI audio routing only after the graphical PoC
   is stable.
10. **Revisit the wider matrix.** Add RPi4 8 GiB and RPi5 only from measured
    memory, QEMU and GPU results. Introduce explicit display profiles before
    enabling concurrent DomU, DomA and DomK builds.

## PoC acceptance criteria

The PoC is complete when all of the following are reproducible on the 4 GiB
RPi4:

- Xen, Zephyr Dom0, DomD and DomK boot, optionally with DomU and never with DomA.
- DomK receives its expected vCPU, 1024 MiB RAM, root disk and `.15` address.
- `podman info` reports `crun` as the selected OCI runtime.
- Ankaios server and agent become healthy after boot.
- `ank` in DomD can query and deploy a bounded workload to DomK.
- A containerized Wayland test application is visible fullscreen on HDMI-A-1.
- Applying the version-2 manifest replaces the running graphical workload, and
   applying version 1 rolls it back without restarting DomK.
- Keyboard and tablet events reach that application.
- Repeated workload start/stop cycles do not leak enough DomD or DomK memory to
  threaten the next deployment.

Physical audio output, runtime display switching, DomA coexistence and RPi5
support are explicitly not PoC acceptance requirements.

## Ankaios application update demonstration

DomK contains two prebuilt ARM64 OCI images. They deliberately use small Weston
examples so the first test isolates workload lifecycle and Wayland integration:

- `weston_demo_v1.yaml` runs `weston-simple-egl` with Mesa software EGL;
- `weston_shm.yaml` starts a separate `weston-simple-shm` workload; and
- `weston_demo_v2.yaml` updates `weston_demo` to `weston-simple-shm`.

Both images are loaded into Podman before the Ankaios agent starts. The
`weston_demo` EGL workload is the boot-time desired state. From DomD, inspect
it, start the independent SHM workload, and then remove that workload:

```sh
ank get workloads
ank apply -f /etc/ankaios/workloads/weston_shm.yaml
ank get workloads
ank delete workload weston_shm
ank get workloads
```

Applying `weston_shm.yaml` does not modify `weston_demo`, because the manifests
use different workload names. Update the original workload from EGL to SHM,
then roll it back through the same desired-state mechanism:

```sh
ank apply -f /etc/ankaios/workloads/weston_demo_v2.yaml
ank apply -f /etc/ankaios/workloads/weston_demo_v1.yaml
```

The workloads run as the DomK Weston UID (`200`), bind-mount
`/run/user/200`, and connect to `wayland-0`. `LIBGL_ALWAYS_SOFTWARE=1` keeps
the EGL version focused on container-to-Wayland plumbing. Container SELinux
label isolation is disabled for this PoC so the workloads can access the
compositor socket; this is not a production security policy. DomK's QEMU
surface is mapped to HDMI-A-1 by DomD Weston.

## Moving the DomU cluster into the workload

The same architecture can host the existing DomU Flutter instrument cluster,
but the current PoC does not yet package that application as an OCI image. That
image needs `flutter-auto`, `flutter-cluster-dashboard`, its configuration and
fonts, with `/usr/bin/flutter-auto` as the entry point. Its KUKSA.val and CAN
data endpoints must be reachable from DomK's network namespace; using
`--network=host` preserves the first PoC's simple network model.

Once that image is available, it can replace version 1 in
`weston_demo_v1.yaml`; the version-2 manifest and update procedure remain
unchanged. DomU is then unnecessary for the single-display Ankaios profile and
can be omitted, recovering its 1024 MiB allocation. Keep a DomU + DomK build
only while comparing the VM-hosted and container-hosted applications on the two
HDMI outputs.
