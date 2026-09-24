SUMMARY = "AGL graphical guest for the DomK Ankaios proof of concept"
LICENSE = "MIT"

require recipes-platform/images/agl-image-weston.bb

IMAGE_FEATURES += "package-management ssh-server-openssh"
IMAGE_FEATURES:append = " empty-root-password allow-empty-password allow-root-login"

# Podman consumes this virtual runtime in its runtime dependencies. Keep crun
# explicit in IMAGE_INSTALL as well so the selected runtime is auditable.
VIRTUAL-RUNTIME_container_runtime = "crun"

IMAGE_INSTALL += " \
    ankaios-bin \
    podman \
    crun \
    domk-network \
    domk-weston-simple-egl-demo \
    domk-weston-simple-shm-demo \
"

IMAGE_ROOTFS_SIZE = "7340032"
IMAGE_ROOTFS_EXTRA_SPACE = "524288"

set_domk_hostname() {
    echo "domk" > ${IMAGE_ROOTFS}${sysconfdir}/hostname
}

ROOTFS_POSTPROCESS_COMMAND += "set_domk_hostname;"
