#!/bin/sh
# Stops the haiku-navi VM. Afterwards the card must still answer on the bus.
#   vm/stop.sh
cd "$(dirname "$0")/.." || exit 1
virsh -c qemu:///system destroy haiku-navi > /dev/null 2>&1
sleep 2
if lspci -s "${NAVI_GPU:-03:00.0}" -xxx | sed -n 2p | grep -q "00: ff ff ff ff"; then
	echo "the card dropped off the bus; only a host reboot brings it back" >&2
	exit 1
fi
echo "VM stopped, card answers"
