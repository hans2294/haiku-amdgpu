#!/bin/sh
# Writes the Haiku disk image to a USB stick, after checking that the target
# is a whole, unmounted USB disk big enough for it, and asking.
#   sudo vm/write-usb.sh /dev/sdX [image]
#   (image: generated.x86_64/haiku-navi-usb.img, from vm/usb-image.sh, which
#   fills the stick; or an anyboot image like haiku-navi-baremetal.iso)
set -e
cd "$(dirname "$0")/.." || exit 1
device=$1
image=${2:-generated.x86_64/haiku-navi-usb.img}

fail() { echo "write-usb: $*" >&2; exit 1; }
[ -n "$device" ] || fail "usage: sudo vm/write-usb.sh /dev/sdX [image]"
[ -b "$device" ] || fail "$device is no block device"
[ -r "$image" ] || fail "cannot read $image"
[ "$(lsblk -dno TYPE "$device")" = disk ] \
	|| fail "$device is not a whole disk (a partition?)"
[ "$(lsblk -dno TRAN "$device")" = usb ] || fail "$device is not on USB"
if lsblk -no MOUNTPOINTS "$device" | grep -q .; then
	fail "$device has mounted partitions; unmount them first"
fi
imageSize=$(stat -c %s "$image")
deviceSize=$(lsblk -bdno SIZE "$device")
[ "$deviceSize" -ge "$imageSize" ] \
	|| fail "$device holds $deviceSize bytes, the image needs $imageSize"

echo "Image:  $image ($((imageSize / 1048576)) MiB)"
echo "Target: $device, $(lsblk -dno VENDOR,MODEL,SIZE "$device" | tr -s ' ')"
echo "Everything on $device will be overwritten."
printf "Type the device name (%s) to go on: " "$device"
read answer
[ "$answer" = "$device" ] || fail "not confirmed; nothing written"

case "$image" in
	*.img) python3 -I "$PWD/vm/write-image.py" "$image" "$device" ;;
	*) dd if="$image" of="$device" bs=4M conv=fsync oflag=direct status=progress
		sync ;;
esac
echo "write-usb: done; boot the machine from it (UEFI USB in the boot menu)"
