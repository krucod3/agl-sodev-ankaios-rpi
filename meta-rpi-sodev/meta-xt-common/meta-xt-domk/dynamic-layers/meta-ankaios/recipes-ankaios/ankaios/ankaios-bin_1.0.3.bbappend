FILESEXTRAPATHS:prepend:virtio-aarch64 := "${THISDIR}/files/virtio-aarch64:"
FILESEXTRAPATHS:prepend:raspberrypi4-64 := "${THISDIR}/files/raspberrypi4-64:"

# The official recipe keys the arm64 release on physical Raspberry Pi MACHINE
# names. DomK is the same aarch64 ISA but its AGL rootfs uses virtio-aarch64.
SRC_URI:append:virtio-aarch64 = " https://github.com/${ANKAIOS_GITHUB_REPO}/releases/download/${ANKAIOS_RELEASE_TAG}/ankaios-linux-arm64.tar.gz;name=bin-arm64"

# DomK uses Podman and crun; containerd and nerdctl are optional alternatives
# without providers in the AGL Scarthgap layer set.
RRECOMMENDS:ank-agent-bin:remove = "containerd nerdctl"

# The release binaries are already stripped.
INSANE_SKIP:ank-server-bin += "already-stripped"
INSANE_SKIP:ank-agent-bin += "already-stripped"
INSANE_SKIP:ank-bin += "already-stripped"
