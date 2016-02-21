sed resources/rolinux.inithook \
    -e "s#{{ROOTIMAGE}}#$ROOTNAME#" \
    -e "s#{{DISKLABEL}}#$DISKLABEL#" \
    -e "s#{{STORAGE_PATH}}#$LIVE_SYSTEM#" \
    -e "s#{{STORAGE}}#rootfs.$ROOT_TYPE#" | sudo dd "of=$R/lib/initcpio/hooks/rolinux"

echo '
build() {
    add_binary findmnt
    add_runscript
}
help() {
    cat <<HELPEOF
Detects the filesystem(s) and mount proper devices or files
HELPEOF
}
' | sudo dd "of=$R/lib/initcpio/install/rolinux"

