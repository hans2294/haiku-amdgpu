#!/bin/sh
# Writes the Haiku disk image to an internal disk, named by its serial number
# (device letters move about, and the machine's other disks hold real data).
# Refuses a disk with anything mounted or in use, one too small, and asks.
#   sudo vm/write-disk.sh <serial> [image]
#   (image: generated.x86_64/haiku-navi-usb.img, from vm/usb-image.sh)
set -e
cd "$(dirname "$0")/.." || exit 1
serial=$1
image=${2:-generated.x86_64/haiku-navi-usb.img}

fail() { echo "write-disk: $*" >&2; exit 1; }
[ -n "$serial" ] || fail "usage: sudo vm/write-disk.sh <serial> [image]"
[ -r "$image" ] || fail "cannot read $image"
device=$(lsblk -dnpo NAME,SERIAL | awk -v s="$serial" '$2 == s {print $1}')
[ -n "$device" ] || fail "no disk with serial $serial"
[ "$(echo "$device" | wc -l)" = 1 ] || fail "more than one disk with that serial"
[ "$(lsblk -dno TYPE "$device")" = disk ] || fail "$device is not a disk"
if lsblk -no MOUNTPOINTS "$device" | grep -q .; then
	fail "$device has mounted partitions; unmount them first"
fi
if holders=$(ls /sys/block/"$(basename "$device")"/*/holders 2>/dev/null) \
		&& echo "$holders" | grep -q -E '^(dm|md)'; then
	fail "$device is in use by the device mapper or RAID"
fi
imageSize=$(stat -c %s "$image")
deviceSize=$(lsblk -bdno SIZE "$device")
[ "$deviceSize" -ge "$imageSize" ] \
	|| fail "$device holds $deviceSize bytes, the image needs $imageSize"

echo "Image:  $image ($((imageSize / 1000000000)) GB partitioned)"
echo "Target: $device, $(lsblk -dno VENDOR,MODEL,SIZE,TRAN "$device" | tr -s ' '), serial $serial"
lsblk -o NAME,SIZE,FSTYPE,LABEL "$device"
echo "Everything on this disk will be erased."
printf "Type the serial number again to go on: "
read answer
[ "$answer" = "$serial" ] || fail "not confirmed; nothing written"

python3 -I "$PWD/vm/write-image.py" "$image" "$device"
sync
partprobe "$device" 2>/dev/null || true
echo "write-disk: done; boot from it in the firmware's boot menu"
