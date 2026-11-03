#!/bin/sh
# Builds amdgpu_firmware, for trying other cards than the two amdgpu_linux has the
# firmware of: all of linux-firmware's amdgpu folder but those files, and the ISP
# firmware, which is under another licence. It isn't part of build.sh, as only people
# trying a card need it. Leaves it in generated.x86_64/firmware-package.
#   port/build-firmware-package.sh
set -e
top=$(cd "$(dirname "$0")/.." && pwd)
tag=20261019
commit=a2dcb924f0897368b0b4f305cbf9808cdda90ce0
url=https://gitlab.com/kernel-firmware/linux-firmware.git
source=$top/generated.x86_64/linux-firmware
out=$top/generated.x86_64/firmware-package
package=$top/generated.x86_64/objects/linux/x86_64/release/tools/package/package

if [ ! -d "$source" ]; then
	git clone -q --depth 1 --branch "$tag" --filter=blob:none --no-checkout "$url" "$source" 2> /dev/null
	git -C "$source" sparse-checkout set --no-cone '/amdgpu/*'
	git -C "$source" checkout -q 2> /dev/null
fi
[ "$(git -C "$source" rev-parse HEAD)" = "$commit" ] \
	|| { echo "build-firmware-package: $source isn't $tag" >&2; exit 1; }

rm -rf "$out"
d=$out/amdgpu_firmware
mkdir -p "$d/data/firmware/amdgpu" "$d/data/licenses"
cp "$top/port/packages/amdgpu_firmware.PackageInfo" "$d/.PackageInfo"
cp "$top/licenses/LICENSE.amdgpu" "$d/data/licenses/AMD firmware"
for file in "$source"/amdgpu/*.bin; do
	name=$(basename "$file")
	case $name in isp_*) continue ;; esac
	[ -f "$top/vm/firmware/$name" ] || cp "$file" "$d/data/firmware/amdgpu/"
done
version=$(sed -n 's/^version[[:space:]]*//p' "$d/.PackageInfo")
(cd "$d" && "$package" create -q "$out/amdgpu_firmware-$version-x86_64.hpkg")
echo "$out/amdgpu_firmware-$version-x86_64.hpkg"
