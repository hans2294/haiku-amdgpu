#!/bin/sh
# Lets the driver run the integrated GPU (Raphael, 1002:164e) instead of the
# RX 7900 GRE on an installed Haiku disk, keeping everything else on it: puts this
# build's driver package on it, and the device list in the driver's settings file.
# Connect the monitor to the motherboard. Undo the list with "off".
#   sudo vm/try-igpu.sh <serial> [off]
# A disk image works, too, with START_OFFSET set to its BFS partition's offset.
set -e
cd "$(dirname "$0")/.." || exit 1
fail() { echo "try-igpu: $*" >&2; exit 1; }
target=$1
[ -n "$target" ] || fail "usage: sudo vm/try-igpu.sh <serial> [off]"
bfsShell=$PWD/generated.x86_64/objects/linux/x86_64/release/tools/bfs_shell/bfs_shell
[ -x "$bfsShell" ] || fail "no $bfsShell"
settings=/myfs/home/config/settings/kernel/drivers/amdgpu

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

if [ "$2" = off ]; then
	printf 'rm %s\nsync\nexit\n' "$settings" | shell
	sync
	echo "try-igpu: back to the RX 7900 GRE"
	exit 0
fi

package=$(ls generated.x86_64/packages/amdgpu_linux-*.hpkg)
list=$(mktemp)
trap 'rm -f "$list"' EXIT
echo "devices 164e" > "$list"
shell <<COMMANDS
rm /myfs/system/packages/$(basename "$package")
cp :$PWD/$package /myfs/system/packages/$(basename "$package")
mkdir -p $(dirname "$settings")
rm $settings
cp :$list $settings
ls /myfs/system/packages/$(basename "$package")
ls $settings
sync
exit
COMMANDS
sync
echo
echo "try-igpu: done"
