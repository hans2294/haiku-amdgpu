#!/bin/sh
# Builds the image and keeps a pristine copy for a real machine, before the
# VM boots (and changes) the original: generated.x86_64/haiku-navi-baremetal.iso.
# Then: sudo vm/write-usb.sh /dev/sdX
cd "$(dirname "$0")/.." || exit 1
vm/stop.sh 2>/dev/null
(cd generated.x86_64 && PATH=$PWD/../tools/bin:$PATH \
	jam -q -j12 @nightly-anyboot > ../logs/jam-image.log 2>&1) \
	|| { echo "baremetal-image: jam failed, see logs/jam-image.log" >&2; exit 1; }
cp generated.x86_64/haiku-nightly-anyboot.iso \
	generated.x86_64/haiku-navi-baremetal.iso
echo "baremetal-image: generated.x86_64/haiku-navi-baremetal.iso"
