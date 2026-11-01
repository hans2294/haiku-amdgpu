#!/bin/sh
# Builds generated.x86_64/haiku-navi-usb.img: a disk for a real machine, without
# the boot tests, whose BFS partition fills a USB stick of the given size:
# MBR, EFI system partition (from the anyboot image), BFS with Haiku. Sparse
# on the host; vm/write-usb.sh writes only the blocks in use.
#   vm/usb-image.sh <stick size in bytes>
set -e
cd "$(dirname "$0")/.." || exit 1
stickSize=$1
[ -n "$stickSize" ] || { echo "usage: vm/usb-image.sh <bytes>" >&2; exit 1; }
out=generated.x86_64
anyboot=$out/haiku-navi-baremetal.iso
sector=512
espStart=2048
espSectors=$(sfdisk -d "$anyboot" | awk -F'[=,]' '/type=ef/ {print $4 + 0}')
espOffset=$(sfdisk -d "$anyboot" | awk -F'[=,]' '/type=ef/ {print $2 + 0}')
[ "$espSectors" -gt 0 ] || { echo "usb-image: no ESP in $anyboot" >&2; exit 1; }
bfsStart=8192
# whole MiB, as HAIKU_IMAGE_SIZE counts them
bfsMiB=$(( (stickSize / sector - bfsStart) / 2048 ))

vm/stop.sh 2>/dev/null || true
(cd $out && PATH=$PWD/../tools/bin:$PATH NAVI_USB_IMAGE=1 HAIKU_IMAGE_SIZE=$bfsMiB \
	jam -q -j12 @nightly-raw > ../logs/jam-usb-image.log 2>&1) \
	|| { echo "usb-image: jam failed, see logs/jam-usb-image.log" >&2; exit 1; }
raw=$(ls -t $out/*.image | head -1)
echo "usb-image: raw image $raw, $(du -h "$raw" | cut -f1) used of ${bfsMiB} MiB"

img=$out/haiku-navi-usb.img
rm -f "$img"
truncate -s "$stickSize" "$img"
sfdisk --quiet "$img" <<LAYOUT
label: dos
start=$espStart, size=$espSectors, type=ef
start=$bfsStart, size=$((bfsMiB * 2048)), type=eb, bootable
LAYOUT
dd if="$anyboot" of="$img" bs=$sector skip="$espOffset" seek=$espStart \
	count="$espSectors" conv=notrunc,sparse status=none
dd if="$raw" of="$img" bs=1M seek=$((bfsStart / 2048)) conv=notrunc,sparse \
	status=none
sfdisk -l "$img" | tail -3
echo "usb-image: $img, $(du -h "$img" | cut -f1) used"
