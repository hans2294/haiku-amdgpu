#!/bin/sh
# Runs the image for a real machine in the VM, to chase what only shows up with
# real programs: a copy with room for them, more RAM and CPUs, and sshd. The copy
# stays between runs; delete generated.x86_64/haiku-navi-big.img for a fresh one.
#   vm/big-vm.sh
set -e
cd "$(dirname "$0")/.." || exit 1
out=generated.x86_64
img=$PWD/$out/haiku-navi-big.img
if [ ! -e "$img" ]; then
	cp --reflink=auto --sparse=always $out/haiku-navi-usb.img "$img"
	printf '%s\n' \
		"cp :vm/big-vm-sshd.sh /myfs/system/non-packaged/bin/big-vm-sshd.sh" \
		"cp :vm/big-vm-sshd.launch /myfs/system/non-packaged/data/user_launch/big-vm-sshd.launch" \
		sync exit \
		| $out/objects/linux/x86_64/release/tools/bfs_shell/bfs_shell \
			--start-offset 4194304 "$img" > /dev/null
fi
sed -e "s|<memory unit='GiB'>4<|<memory unit='GiB'>16<|" \
	-e "s|<vcpu placement='static'>4<|<vcpu placement='static'>8<|" \
	-e "s|<source file='[^']*'/>|<source file='$img'/>|" \
	vm/haiku-navi.xml > $out/haiku-navi-big.xml
NAVI_XML=$out/haiku-navi-big.xml exec vm/start.sh
