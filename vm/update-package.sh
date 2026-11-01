#!/bin/sh
# Replaces packages on an installed Haiku disk, keeping everything else on it.
# The disk is named by its serial number, as for vm/write-disk.sh. A package
# keeps its file name, so Haiku activates the new one at the next boot.
#   sudo vm/update-package.sh <serial> <hpkg>...
#   e.g. sudo vm/update-package.sh <serial> generated.x86_64/packages/amdgpu_linux-*.hpkg
# A disk image works, too, with START_OFFSET set to its BFS partition's offset:
#   START_OFFSET=4194304 vm/update-package.sh <image> <hpkg>...
set -e
cd "$(dirname "$0")/.." || exit 1
fail() { echo "update-package: $*" >&2; exit 1; }
[ $# -ge 2 ] || fail "usage: sudo vm/update-package.sh <serial> <hpkg>..."
target=$1
shift
bfsShell=$PWD/generated.x86_64/objects/linux/x86_64/release/tools/bfs_shell/bfs_shell
[ -x "$bfsShell" ] || fail "no $bfsShell"

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

commands=$(mktemp)
trap 'rm -f "$commands"' EXIT
for package in "$@"; do
	[ -f "$package" ] || fail "no file $package"
	name=$(basename "$package")
	echo "rm /myfs/system/packages/$name"
	echo "cp :$package /myfs/system/packages/$name"
	echo "ls /myfs/system/packages/$name"
done > "$commands"
printf 'sync\nexit\n' >> "$commands"
"$bfsShell" --start-offset "${START_OFFSET:-0}" "$partition" < "$commands"
sync
echo
echo "update-package: done"
