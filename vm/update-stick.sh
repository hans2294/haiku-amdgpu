#!/bin/sh
# Puts single files on a Haiku USB stick, keeping what is installed on it: its
# BFS partition stays as it is, and a file in non-packaged shadows the one
# from the packages. Delete it on the stick to go back.
#   sudo vm/update-stick.sh /dev/sdX <file> <directory on the stick> ...
#   e.g. sudo vm/update-stick.sh /dev/sdX mouse add-ons/input_server/devices
# A partition image works, too; with START_OFFSET set for one inside a disk.
set -e
cd "$(dirname "$0")/.." || exit 1
target=$1
shift
fail() { echo "update-stick: $*" >&2; exit 1; }
bfsShell=$PWD/generated.x86_64/objects/linux/x86_64/release/tools/bfs_shell/bfs_shell
[ -x "$bfsShell" ] || fail "no $bfsShell"
if [ -b "$target" ]; then
	[ "$(lsblk -dno TRAN "$target")" = usb ] || fail "$target is not on USB"
	if lsblk -no MOUNTPOINTS "$target" | grep -q .; then
		fail "$target has mounted partitions; unmount them first"
	fi
	partition=$(lsblk -lnpo NAME,FSTYPE "$target" | awk '$2 == "befs" {print $1; exit}')
	[ -n "$partition" ] || fail "no BFS partition on $target"
else
	partition=$target
fi

commands=$(mktemp)
: > "$commands"
while [ $# -ge 2 ]; do
	file=$1
	directory=/myfs/system/non-packaged/$2
	[ -f "$file" ] || fail "no file $file"
	echo "mkdir -p $directory" >> "$commands"
	echo "cp :$file $directory/$(basename "$file")" >> "$commands"
	echo "ls $directory" >> "$commands"
	shift 2
done
printf 'sync\nexit\n' >> "$commands"
"$bfsShell" --start-offset "${START_OFFSET:-0}" "$partition" < "$commands"
rm -f "$commands"
sync
echo
echo "update-stick: done"
