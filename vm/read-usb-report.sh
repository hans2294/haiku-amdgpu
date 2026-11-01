#!/bin/sh
# Copies what Haiku left on its disk or USB stick to logs/baremetal/: the syslog
# of the last boots and a test report. Linux's befs refuses a volume that wasn't
# shut down cleanly, so this uses Haiku's bfs_shell: like booting Haiku, it replays
# the journal and leaves the volume clean. It only touches a disk's BFS partition.
#   sudo vm/read-usb-report.sh /dev/sdX
# A disk image works, too, with START_OFFSET set to where BFS starts in it.
set -e
cd "$(dirname "$0")/.." || exit 1
target=$1
fail() { echo "read-usb-report: $*" >&2; exit 1; }
bfsShell=$PWD/generated.x86_64/objects/linux/x86_64/release/tools/bfs_shell/bfs_shell
[ -x "$bfsShell" ] || fail "no $bfsShell"
if [ -b "$target" ]; then
	if lsblk -no MOUNTPOINTS "$target" | grep -q .; then
		fail "$target has mounted partitions; unmount them first"
	fi
	partition=$(lsblk -lnpo NAME,FSTYPE "$target" | awk '$2 == "befs" {print $1; exit}')
	[ -n "$partition" ] || fail "no BFS partition on $target"
elif [ -f "$target" ]; then
	partition=$target
else
	fail "usage: sudo vm/read-usb-report.sh /dev/sdX"
fi

out=$PWD/logs/baremetal/$(date +%Y%m%d-%H%M%S)
mkdir -p "$out"
commands=$(mktemp)
for file in system/var/log/syslog system/var/log/syslog.old \
		system/var/log/previous_syslog home/navi-report.txt; do
	echo "cp /myfs/$file :$out/$(basename "$file")" >> "$commands"
done
cat >> "$commands" <<COMMANDS
ls /myfs/system/var/log
ls /myfs/system/packages
sync
exit
COMMANDS
"$bfsShell" --start-offset "${START_OFFSET:-0}" "$partition" < "$commands" \
	> "$out/listing.txt" 2>&1 || true
rm -f "$commands"
sync
[ -n "$SUDO_UID" ] && chown -R "$SUDO_UID:$SUDO_GID" logs/baremetal
echo "read-usb-report: copied to $out:"
ls -l "$out"
