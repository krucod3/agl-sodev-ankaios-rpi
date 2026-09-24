SUMMARY = "Xen runtime configuration for the DomK Ankaios guest"
DESCRIPTION = "Installs domk.cfg and the DomD-side service that launches the graphical DomK PoC."

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://domk.cfg \
    file://xl-create-domk.service \
    file://weston_demo_v1.yaml \
    file://weston_shm.yaml \
    file://weston_demo_v2.yaml \
"

XT_DOMK_UNPACKDIR = "${@d.getVar('UNPACKDIR') or d.getVar('WORKDIR')}"

inherit systemd

do_configure[noexec] = "1"
do_compile[noexec] = "1"

SYSTEMD_SERVICE:${PN} = "xl-create-domk.service"
SYSTEMD_AUTO_ENABLE = "enable"

RDEPENDS:${PN} += "ank-bin"

do_install() {
    install -d ${D}${sysconfdir}/xen
    install -m 0644 ${XT_DOMK_UNPACKDIR}/domk.cfg ${D}${sysconfdir}/xen/domk.cfg

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${XT_DOMK_UNPACKDIR}/xl-create-domk.service ${D}${systemd_system_unitdir}/

    install -d ${D}${sysconfdir}/ankaios/workloads
    install -m 0644 ${XT_DOMK_UNPACKDIR}/weston_demo_v1.yaml \
        ${D}${sysconfdir}/ankaios/workloads/
    install -m 0644 ${XT_DOMK_UNPACKDIR}/weston_shm.yaml \
        ${D}${sysconfdir}/ankaios/workloads/
    install -m 0644 ${XT_DOMK_UNPACKDIR}/weston_demo_v2.yaml \
        ${D}${sysconfdir}/ankaios/workloads/
}

FILES:${PN} = " \
    ${sysconfdir}/xen/domk.cfg \
    ${sysconfdir}/ankaios/workloads/weston_demo_v1.yaml \
    ${sysconfdir}/ankaios/workloads/weston_shm.yaml \
    ${sysconfdir}/ankaios/workloads/weston_demo_v2.yaml \
    ${systemd_system_unitdir}/xl-create-domk.service \
"
