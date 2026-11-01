#!/bin/sh
# Installs libdrm (headers, libdrm.so, libdrm_amdgpu.so, pkg-config files)
# and libposix_error_mapper.a into the cross sysroot's
# /boot/system/non-packaged/develop, for building Mesa.
#   port/libdrm-sysroot.sh       (after: jam libdrm.so libdrm_amdgpu.so)
set -e
top=$(cd "$(dirname "$0")/.." && pwd)
src=$top/libdrm
objects=$top/generated.x86_64/objects/haiku/x86_64/release
dest=$top/generated.x86_64/cross-tools-x86_64/sysroot/boot/system/non-packaged/develop
version=$(sed -n "s/^ *version *: *'\([0-9.]*\)'.*/\1/p" "$src/meson.build" | head -1)

mkdir -p "$dest/headers/libdrm" "$dest/headers/sys" "$dest/lib/pkgconfig"
cp "$src/xf86drm.h" "$src/xf86drmMode.h" "$dest/headers/"
cp "$src"/include/drm/*.h "$src/amdgpu/amdgpu.h" "$src/libsync.h" \
	"$dest/headers/libdrm/"
cp "$src/haiku/sys/ioccom.h" "$dest/headers/sys/"
# linuxkpi's ioctls next to Linux's (the size of a dma-buf, ...)
mkdir -p "$dest/headers/linuxkpi"
cp "$top/haiku/src/libs/compat/linuxkpi/include/linuxkpi/uapi.h" \
	"$dest/headers/linuxkpi/"
cp "$objects/libs/libdrm/libdrm.so" "$objects/libs/libdrm/libdrm_amdgpu.so" \
	"$objects/libs/posix_error_mapper/libposix_error_mapper.a" "$dest/lib/"

for lib in libdrm libdrm_amdgpu; do
	cat > "$dest/lib/pkgconfig/$lib.pc" <<PC
prefix=/boot/system/non-packaged
includedir=\${prefix}/develop/headers
libdir=\${prefix}/develop/lib

Name: $lib
Description: Userspace interface to kernel DRM services (Haiku, linuxkpi)
Version: $version
Libs: -L\${libdir} -l${lib#lib}
Cflags: -I\${includedir} -I\${includedir}/libdrm
$( [ $lib = libdrm_amdgpu ] && echo "Requires.private: libdrm" )
PC
done
echo "libdrm $version installed into $dest"
