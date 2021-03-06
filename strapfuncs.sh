export LC_ALL=C
set -e

source ./configuration.sh
[ -e my_conf.sh ] && source ./my_conf.sh # my_conf can configure distrib options (ex: DETECT_LOCALE)

if [ -z "$CHROOT" ]; then
    R="$WORKDIR/ROOT"
    ARCHCHROOT="$SUDO arch-chroot -u user '$R'"
    SU_ARCHCHROOT="$SUDO arch-chroot '$R'"
    SUDO="sudo"
else
    SUDO=""
    ARCHCHROOT=""
    R="."
fi

D="$WORKDIR/$DISKLABEL.img"
SQ="$WORKDIR/$ROOTNAME"

# DETECT LANGUAGE
if [ -z "$COUNTRY" ]; then
    IPADDR=$(curl -4 -s icanhazip.com)
    COUNTRY=$(geoiplookup $IPADDR)
    COUNTRY=${COUNTRY#*: }
    COUNTRY=${COUNTRY%%,*}
fi

if [ -e "resources/locales/country_codes/$COUNTRY" ] ; then
    echo "** Adding i18n-$COUNTRY support"
    source resources/locales/country_codes/$COUNTRY
else
    echo "** No i18n support found for $COUNTRY"
fi

HOOK_BUILD_FOLDER=".installed_hooks"

# LOAD OVERRIDES

if [ -e /${DISTRIB}.sh ]; then
    source /${DISTRIB}.sh
else
    source ./distrib/${DISTRIB}.sh
fi

[ -e my_conf.sh ] && source ./my_conf.sh # my_conf have absolute priority (dup)

_net_mgr=./hooks/alternatives/install/network_manager/50_network_$NETMGR.sh

# i18n @ install time
_gettext_dir=$(realpath ./resources/locales/gettext)

function text() {
    TEXTDOMAIN=messages TEXTDOMAINDIR="$_gettext_dir" gettext "$*"
}

# AUTO ADD FLASHDISK IF LIVESYSTEM

if [ -n "$USE_LIVE_SYSTEM" ] && [[ "$PROFILES" != *flashdisk ]] ; then
    PROFILES="${PROFILES} flashdisk"
fi

# FONCTION DEFINITION

function have_xorg() {
    if [[ "$PROFILES" = *xorg* ]]; then
        return 0
    else
        return 1
    fi
}

function step() {
    W=$(( $(tput cols) - 5 ))
    printf "\\033[44m\\033[1m    %-${W}s>\\033[0m\\033[49m" "$1"
}

function step2() {
    W=$(( $(tput cols) - 5 ))
    printf "\\033[44m    %-${W}s>\\033[0m" "$1"
}

function __contains() {
    grep "$1" "$2" > /dev/null
}

function write_text() {
    $SUDO dd "of=$R/$1" 2>/dev/null
}
function write_bin() {
    write_text $1
    $SUDO chmod 755 "$R/$1"
}

function append_text() {
    pat="# GENERATED AT INSTALL:"

    I="$R/$1"

    if __contains "$pat" "$I"; then
        __strip_end "$pat" "$I"
    fi

    _FILE=$(cat "$I")
    _DATA=$(cat /dev/stdin)
    echo "$_FILE

$pat

$_DATA
" | $SUDO dd "of=$I" 2>/dev/null
}

function __strip_end() {
    PATTERN="$1"
    FILE="$2"
    $SUDO sed -i "/^${PATTERN}/,$ d" "${FILE}"
}

function replace_with() {
    PATTERN="$1"
    SUB="$2"
    FILE="$3"
    HEADER=$(sed "/^$PATTERN$/,$ d" "$I")
    FOOTER=$(sed "0,/^$PATTERN END/ d" "$I")
    echo "$HEADER
$SUB
$FOOTER" | $SUDO dd of="$I" 2>/dev/null
}

function have_package() {
    _set_pkgmgr
    $PKGMGR $PKGMGR_OPTS --root "$R" -Qqq $* >/dev/null 2>&1
}

function make_symlink() {
    $SUDO ln -fs $1 "$R/$2"
}

function raw_install_pkg() {
    _set_pkgmgr
    # if chroot:
    if [ -z "$CHROOT" ]; then
        pkg_cmd="$SUDO arch-chroot -u user "$R" su -- user $PKGMGR $PKGMGR_OPTS --noconfirm $* 2>&1 | ./onelinelog.py"
        $SUDO arch-chroot -u user "$R" su -- user $PKGMGR $PKGMGR_OPTS --noconfirm $* 2>&1 | ./onelinelog.py
    else
        if [ "$PKGMGR" = "pacman" ]; then
            pkg_cmd="$PKGMGR $PKGMGR_OPTS --noconfirm $* 2>&1 | ./onelinelog.py"
            $PKGMGR $PKGMGR_OPTS --noconfirm $* 2>&1 | ./onelinelog.py
        else
            pkg_cmd="su -- user $PKGMGR $PKGMGR_OPTS --noconfirm $* 2>&1 | ./onelinelog.py"
            su -- user $PKGMGR $PKGMGR_OPTS --noedit --noconfirm $* 2>&1 | ./onelinelog.py
        fi
    fi
   if [ ${PIPESTATUS[0]} -ne 0 ] ; then
       cat >> /tmp/failedpkgs.log <<EOF
   >>>>>>>>>>>>>>>> FAILED to execute (chroot=$CHROOT)
$pkg_cmd ::
$(cat stdout.log)

- end -
EOF
   fi
}

function install_pkg() {
    step2 "Installing $*"
    raw_install_pkg --needed -S $*
}
function install_aur_pkg() {
    step2 "Installing (AUR) $*"
    raw_install_pkg --needed -S $*
}

function remove_pkg() {
    _set_pkgmgr
    $PKGMGR --root "$R" --noconfirm -R $*
}

function network_manager() {
    ln -fs "../../hooks/alternatives/install/network_manager/50_network_$1.sh" "$_net_mgr"
}

function enable_service() {
    $SUDO systemctl --root "$R" --force enable $1
}

function disable_service() {
    $SUDO systemctl --root "$R" disable $1 || echo "Service $1 is already disabled"
}

function install_bin() {
    $SUDO install -m 755 -o root -g root "$1" "$R$2"
}
function install_file() {
    $SUDO install -m 644 -o root -g root "$1" "$R$2"
}
function autostart_app() {
    ASDIR="resources/HOME/.config/autostart"
    if [ ! -d "$ASDIR" ]; then
        mkdir "$ASDIR"
    fi
    if [ -e "$R/usr/share/applications/$1.desktop" ] ; then
        $SUDO install -m 644 "$R/usr/share/applications/$1.desktop" "$ASDIR"
    else
        echo "Can't find autostart file for $1 !"
    fi
}
function no_autostart_app() {
    ASDIR="resources/HOME/.config/autostart"
    if [ ! -d "$ASDIR" ]; then
        mkdir "$ASDIR"
    fi
    $SUDO install -m 644 "$R/usr/share/applications/$1.desktop" "$ASDIR"

    $SUDO dd "of=$ASDIR/$1.desktop" 2>/dev/null <<EOF
$(cat $ASDIR/$1.desktop)
X-MATE-Autostart-enabled=false
EOF
}
function install_menu () {
    ASDIR="resources/HOME/.config/menus"
    if [ ! -d "$ASDIR" ]; then
        mkdir "$ASDIR"
    fi
    $SUDO install -m 644 "resources/menus/$1.menu" "$ASDIR"
}
function install_application() {
    ASDIR="resources/HOME/.local/share/applications"
    if [ ! -d "$ASDIR" ]; then
        mkdir "$ASDIR"
    fi
    $SUDO install -m 644 resources/applications/$1.desktop "$ASDIR"
}
function install_resource() {
    $SUDO install -m 644 resources/$1 "$R$2"
}

function _set_pkgmgr() {
    if [ -e "$R/bin/$PACMAN_BIN" ]; then
        PKGMGR="$PACMAN_BIN"
    else
        PKGMGR="$SUDO pacman"
    fi
    PKGMGR="${PKGMGR# *}"
}

function set_user_ownership() {
    $SUDO chown -R $USERID.$USERGID $*
}

function upx_comp() {
    if [ -n "$ENABLE_UPX" ]; then
        $SUDO chmod +x "$R/$1/"*.so
        $SUDO upx --best "$R/$1/"*.so || true
    fi
}

HOOK_BUILD_FLAG=0
function run_hooks() {
    if [ $HOOK_BUILD_FLAG -eq 0 ]; then
        # BUILD CURRENT HOOKS COLLECTION
        if [ -e "$HOOK_BUILD_DIR" ]; then
            sudo rm -fr "$HOOK_BUILD_DIR"
        fi
        sudo mkdir "$HOOK_BUILD_DIR"
        sudo chmod 1777 "$HOOK_BUILD_DIR"
        for hooktype in pre-mkinitcpio pre-install install post-install ; do
            mkdir "$HOOK_BUILD_DIR/$hooktype"
        done
        for PROFILE in $PROFILES; do
            step2 " ===> profile $PROFILE"
            for stage in "hooks/$PROFILE/"* 
            do
                sstage=${stage#*/}
                sstage=${sstage#*/}
                for hook in $stage/*;
                do
                    cp "./$stage/$(basename $hook)" "$HOOK_BUILD_DIR/$sstage/"
                done
            done
        done
        cp "$_net_mgr" "$HOOK_BUILD_DIR/install/"
        HOOK_BUILD_FLAG=1
    fi

    sudo arch-chroot "$R" /resources/chroot_installer "$1"
}
