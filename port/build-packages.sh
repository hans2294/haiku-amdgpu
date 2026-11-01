#!/bin/sh
# Builds the hpkg packages of the amdgpu port from what jam, port/mesa-build.sh
# and port/vulkan-loader-build.sh built, into generated.x86_64/packages:
#   amdgpu_linux    driver, accelerant, Navi 31 firmware
#   libdrm          libdrm, libdrm_amdgpu, amdgpu.ids
#   mesa_radeon     radeonsi (GL, EGL, GLES), RADV, libGL with BGLView
#   vulkan_loader   libvulkan.so.1
#   port/build-packages.sh
set -e
top=$(cd "$(dirname "$0")/.." && pwd)
out=$top/generated.x86_64/packages
objects=$top/generated.x86_64/objects/haiku/x86_64/release
mesa=$top/generated.x86_64/mesa-build/src
loader=$top/generated.x86_64/vulkan-build/loader/loader
package=$top/generated.x86_64/objects/linux/x86_64/release/tools/package/package

# stage <package>: an empty tree for it, with its .PackageInfo
stage() {
	dir=$out/$1
	rm -rf "$dir"
	mkdir -p "$dir"
	cp "$top/port/packages/$1.PackageInfo" "$dir/.PackageInfo"
}

# build <package>: the hpkg from its tree
build() {
	version=$(sed -n 's/^version[[:space:]]*//p' "$out/$1/.PackageInfo")
	rm -f "$out/$1"-*.hpkg
	(cd "$out/$1" && "$package" create -q "$out/$1-$version-x86_64.hpkg")
	echo "$out/$1-$version-x86_64.hpkg"
}

stage amdgpu_linux
d=$out/amdgpu_linux
mkdir -p "$d/add-ons/kernel/drivers/bin" "$d/add-ons/kernel/drivers/dev/graphics" \
	"$d/add-ons/accelerants" "$d/data/firmware/amdgpu"
cp "$objects/add-ons/kernel/drivers/graphics/amdgpu/amdgpu" \
	"$d/add-ons/kernel/drivers/bin/"
ln -s ../../bin/amdgpu "$d/add-ons/kernel/drivers/dev/graphics/amdgpu"
cp "$objects/add-ons/accelerants/amdgpu_kms/amdgpu_kms.accelerant" \
	"$d/add-ons/accelerants/"
cp "$top"/vm/firmware/*.bin "$top/licenses/LICENSE.amdgpu" "$d/data/firmware/amdgpu/"
build amdgpu_linux

stage libdrm
d=$out/libdrm
mkdir -p "$d/lib" "$d/data/libdrm"
cp "$objects/libs/libdrm/libdrm.so" "$objects/libs/libdrm/libdrm_amdgpu.so" \
	"$d/lib/"
cp "$top/libdrm/data/amdgpu.ids" "$d/data/libdrm/"
build libdrm

stage mesa_radeon
d=$out/mesa_radeon
mkdir -p "$d/lib" "$d/data/vulkan/icd.d"
cp "$mesa/gallium/targets/dri/libgallium-26.2.6.so" \
	"$mesa/amd/vulkan/libvulkan_radeon.so" "$d/lib/"
cp "$mesa/egl/libEGL.so.1.0.0" "$mesa/mesa/glapi/es2api/libGLESv2.so.2.0.0" \
	"$mesa/haiku-gl/libGL.so.1.0.0" "$d/lib/"
for lib in libEGL.so.1.0.0 libGLESv2.so.2.0.0 libGL.so.1.0.0; do
	soname=${lib%.*.*}		# libEGL.so.1
	ln -s "$lib" "$d/lib/$soname"
	ln -s "$soname" "$d/lib/${soname%.*}"
done
cp "$top/port/vulkan/radeon_icd.x86_64.json" "$d/data/vulkan/icd.d/"
build mesa_radeon

stage vulkan_loader
d=$out/vulkan_loader
mkdir -p "$d/lib"
cp "$loader/libvulkan.so.1.4.367" "$d/lib/"
ln -s libvulkan.so.1.4.367 "$d/lib/libvulkan.so.1"
ln -s libvulkan.so.1 "$d/lib/libvulkan.so"
build vulkan_loader
