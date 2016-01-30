DISKLABEL="ARCHX"

PROFILE="default" # minimal, multi-env or default

PREFERRED_TOOLKIT="gtk" # or "qt" , keep LOWERCASE !

PASSWORD="plop"

PACMAN_BIN=yaourt

WORKDIR="$PWD"

# Advanced users only:

COMPRESSION_TYPE="xz" # xz or gzip (faster, uses less memory, but bigger files)
DISK_MARGIN=1 # in megabytes
DEFAULT_GROUPS="lp,disk,network,audio,storage,input,power,users,wheel"
ADMIN_GROUPS="lp,disk,network,audio,storage,input,power,users,wheel,adm,tty,log,sys,daemon"

# Customize names
ROOTNAME="rootfs.s"
R="$WORKDIR/ROOT"
D="$WORKDIR/diskimage.raw"
SQ="$WORKDIR/$ROOTNAME"
