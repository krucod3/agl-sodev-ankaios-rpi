SUMMARY = "Container definition for the DomK Weston simple-EGL demo"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://domk-weston-simple-egl-load \
    file://domk-weston-simple-egl-load.service \
"
S = "${WORKDIR}"

inherit allarch systemd

SYSTEMD_SERVICE:${PN} = "domk-weston-simple-egl-load.service"
SYSTEMD_AUTO_ENABLE = "enable"

do_install[depends] += "domk-weston-simple-egl:do_image_complete"

do_install() {
    install -d ${D}${datadir}/ankaios/images
    install -m 0644 \
        ${DEPLOY_DIR_IMAGE}/domk-weston-simple-egl-1.0-oci.tar \
        ${D}${datadir}/ankaios/images/domk-weston-simple-egl.oci.tar

    install -d ${D}${libexecdir}
    install -m 0755 ${WORKDIR}/domk-weston-simple-egl-load \
        ${D}${libexecdir}/

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/domk-weston-simple-egl-load.service \
        ${D}${systemd_system_unitdir}/
}

FILES:${PN} = " \
    ${datadir}/ankaios/images/domk-weston-simple-egl.oci.tar \
    ${libexecdir}/domk-weston-simple-egl-load \
    ${systemd_system_unitdir}/domk-weston-simple-egl-load.service \
"