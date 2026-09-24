SUMMARY = "OCI image for the updated DomK Weston simple-SHM workload"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

IMAGE_FSTYPES = "container oci"

inherit image image-oci

IMAGE_FEATURES = ""
IMAGE_LINGUAS = ""
NO_RECOMMENDATIONS = "1"
IMAGE_CONTAINER_NO_DUMMY = "1"

IMAGE_INSTALL = " \
    base-files \
    base-passwd \
    weston-examples \
"

OCI_IMAGE_TAG = "2.0"
OCI_IMAGE_ENTRYPOINT = "/usr/bin/weston-simple-shm"
OCI_IMAGE_RUNTIME_UID = "200:200"
OCI_IMAGE_STOPSIGNAL = "SIGINT"

ROOTFS_POSTPROCESS_COMMAND += "fix_container_volatile_dirs;"

fix_container_volatile_dirs() {
    install -d -m 1777 ${IMAGE_ROOTFS}${localstatedir}/volatile/tmp
    install -d -m 0755 ${IMAGE_ROOTFS}${localstatedir}/volatile/log
}