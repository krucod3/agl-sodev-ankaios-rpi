SUMMARY = "Static management network for the DomK PoC"
DESCRIPTION = "Configures DomK on the DomD xenbr0 management segment."
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/Apache-2.0;md5=89aea4e17d99a7cacdbeed46a0096b10"

SRC_URI = "file://20-eth0.network"
S = "${WORKDIR}"

inherit allarch

RDEPENDS:${PN} = "systemd"

do_install() {
    install -d ${D}${sysconfdir}/systemd/network
    install -m 0644 ${WORKDIR}/20-eth0.network ${D}${sysconfdir}/systemd/network/
}

FILES:${PN} = "${sysconfdir}/systemd/network/20-eth0.network"
