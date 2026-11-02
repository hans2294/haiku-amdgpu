#!/bin/sh
# Puts this build's hda driver, with audio over the 7900 GRE's HDMI/DP, on an
# installed Haiku disk, keeping everything else on it. Named by serial number, as
# for vm/write-disk.sh. To undo it, delete /boot/system/settings/packages and
# non-packaged/add-ons/kernel/drivers/{bin,dev/audio/hmulti}/hda on the disk.
#   sudo vm/install-hda-fix.sh <serial>
# A disk image works, too, with START_OFFSET set to its BFS partition's offset:
#   START_OFFSET=4194304 vm/install-hda-fix.sh <image>
set -e
cd "$(dirname "$0")/.." || exit 1
fail() { echo "install-hda-fix: $*" >&2; exit 1; }
target=$1
[ -n "$target" ] || fail "usage: sudo vm/install-hda-fix.sh <serial>"
bfsShell=$PWD/generated.x86_64/objects/linux/x86_64/release/tools/bfs_shell/bfs_shell
hda=$PWD/generated.x86_64/objects/haiku/x86_64/release/add-ons/kernel/drivers/audio/hda/hda
[ -x "$bfsShell" ] || fail "no $bfsShell"
[ -f "$hda" ] || fail "no $hda"

if [ -f "$target" ]; then
	partition=$target
else
	device=$(lsblk -dnpo NAME,SERIAL | awk -v s="$target" '$2 == s {print $1}')
	[ -n "$device" ] || fail "no disk with serial $target"
	if lsblk -no MOUNTPOINTS "$device" | grep -q .; then
		fail "$device has mounted partitions; unmount them first"
	fi
	partition=$(lsblk -lnpo NAME,FSTYPE "$device" | awk '$2 == "befs" {print $1; exit}')
	[ -n "$partition" ] || fail "no BFS partition on $device"
fi

shell() { "$bfsShell" --start-offset "${START_OFFSET:-0}" "$partition"; }

# Keep whatever settings file is there already
if printf 'ls /myfs/system/settings/packages\nexit\n' | shell 2>&1 \
		| grep -q ' /myfs/system/settings/packages$'; then
	fail "the disk already has system/settings/packages; add vm/hda-fix.packages to it by hand"
fi

drivers=/myfs/system/non-packaged/add-ons/kernel/drivers
shell <<COMMANDS
mkdir -p $drivers/bin
mkdir -p $drivers/dev/audio/hmulti
cp :$hda $drivers/bin/hda
ln -s ../../../bin/hda $drivers/dev/audio/hmulti/hda
cp :$PWD/vm/hda-fix.packages /myfs/system/settings/packages
ls $drivers/bin/hda
ls $drivers/dev/audio/hmulti/hda
ls /myfs/system/settings/packages
sync
exit
COMMANDS
sync
echo
echo "install-hda-fix: done"
