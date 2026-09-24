do_install:append() {
    sed -i 's/^driver = "overlay"$/driver = "vfs"/' \
        ${D}${sysconfdir}/containers/storage.conf
}