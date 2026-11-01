#!/bin/sh
# Runs an official Haiku nightly in the VM, to try the packages on a Haiku
# that is not this build: a copy of the anyboot image with room for programs,
# plus sshd for vm/ssh.sh. Delete the copy for a fresh one.
#   vm/nightly-vm.sh <anyboot image>
set -e
cd "$(dirname "$0")/.." || exit 1
out=generated.x86_64
anyboot=$1
[ -r "$anyboot" ] || { echo "usage: vm/nightly-vm.sh <anyboot image>" >&2; exit 1; }
img=$PWD/$out/haiku-navi-nightly.img
bfsStart=$(sfdisk -d "$anyboot" | awk -F'[=,]' '/type=eb/ {print $2 + 0}')
if [ ! -e "$img" ]; then
	cp --reflink=auto --sparse=always "$anyboot" "$img"
	printf '%s\n' \
		"mkdir -p /myfs/system/non-packaged/bin" \
		"mkdir -p /myfs/system/non-packaged/data/user_launch" \
		"mkdir -p /myfs/home/config/settings/ssh" \
		"cp :vm/authorized_keys /myfs/home/config/settings/ssh/authorized_keys" \
		"cp :vm/big-vm-sshd.sh /myfs/system/non-packaged/bin/big-vm-sshd.sh" \
		"cp :vm/big-vm-sshd.launch /myfs/system/non-packaged/data/user_launch/big-vm-sshd.launch" \
		sync exit \
		| $out/objects/linux/x86_64/release/tools/bfs_shell/bfs_shell \
			--start-offset $((bfsStart * 512)) "$img" | tail -3
fi
sed -e "s|<memory unit='GiB'>4<|<memory unit='GiB'>16<|" \
	-e "s|<vcpu placement='static'>4<|<vcpu placement='static'>8<|" \
	-e "s|<source file='[^']*'/>|<source file='$img'/>|" \
	vm/haiku-navi.xml > $out/haiku-navi-nightly.xml
NAVI_XML=$out/haiku-navi-nightly.xml exec vm/start.sh
