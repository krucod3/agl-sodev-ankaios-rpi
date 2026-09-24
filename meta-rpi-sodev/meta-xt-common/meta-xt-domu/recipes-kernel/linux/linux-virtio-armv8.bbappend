FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Follow the DomU kernel configuration V4H AGL SoDeV historically used from
# xen-troops meta-xt-common: use the base recipe as-is
# (meta-xt-common/meta-xt-domu/.../linux-virtio-armv8.bb = torvalds linux 6.8.0-rc1
# @ 6613476e + the single Xen backend-domid patch + its 6.8.0-rc1 defconfig; the
# upstream recipe's DEBUG patch is intentionally excluded). Note the current V4H
# submodule has since moved its DomU kernel to the 6.12 series. We add only the
# single RPi5-mandatory delta below; everything else (kernel source, SRCREV,
# version, patches, defconfig) is inherited unchanged from the base recipe.
#
# RPi5 (BCM2712) has NO IOMMU, so virtio guests must use Xen grant-based DMA
# (the foreign-mapping path used on R-Car, which has an IOMMU, does not apply).
# The base 6.8.0-rc1 defconfig has `# CONFIG_XEN_VIRTIO_FORCE_GRANT is not set`;
# this fragment flips it on. The base recipe inherits kernel-yocto, so a
# file://*.cfg in SRC_URI is auto-merged on top of the defconfig.
SRC_URI += "file://xen-force-grant.cfg"

# crun implements the cgroup-v2 device controller with eBPF. DomK runs Podman
# workloads, so its guest kernel needs the BPF syscall and cgroup BPF hooks.
# Keep this out of DomU, which uses the same kernel recipe but runs no containers.
SRC_URI:append = "${@' file://container-bpf.cfg' if d.getVar('XT_DOM_NAME') == 'domk' else ''}"
