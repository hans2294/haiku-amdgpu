#!/bin/sh
# Starts the haiku-navi VM, with its serial output going to logs/serial.log.
# vm/haiku-navi.xml has the GPU's PCI address and the machine type: change those
# for your machine, and NAVI_GPU to the same address. NAVI_BRIDGE is the host's
# network bridge (default virbr0, libvirt's own network).
cd "$(dirname "$0")/.." || exit 1
gpu=${NAVI_GPU:-03:00.0}

if [ "$(basename "$(readlink "/sys/bus/pci/devices/0000:$gpu/driver")")" != vfio-pci ]; then
	echo "$gpu is not bound to vfio-pci; run 'sudo vm/vfio-boot.sh install' and reboot" >&2
	exit 1
fi

if lspci -s "$gpu" -xxx | sed -n 2p | grep -q "00: ff ff ff ff"; then
	echo "the card does not answer on the bus; reboot the host" >&2
	exit 1
fi

mkdir -p logs
if ! ss -ltn | grep -q '127.0.0.1:4555'; then
	nohup vm/serial-listen.sh > /dev/null 2>&1 &
	sleep 0.5
fi

echo "--- boot $(date -Is) ---" >> logs/serial.log
xml=generated.x86_64/haiku-navi-run.xml
sed -e "s|@TOP@|$PWD|g" -e "s|@BRIDGE@|${NAVI_BRIDGE:-virbr0}|g" \
	"${NAVI_XML:-vm/haiku-navi.xml}" > "$xml"
virsh -c qemu:///system define "$xml" > /dev/null
exec virsh -c qemu:///system start haiku-navi
