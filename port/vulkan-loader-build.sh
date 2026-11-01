#!/bin/sh
# Cross-builds Khronos' Vulkan headers (into the sysroot) and loader for
# Haiku from ../vulkan-headers and ../vulkan-loader (branch haiku).
#   port/vulkan-loader-build.sh
set -e
top=$(cd "$(dirname "$0")/.." && pwd)
sysroot=$top/generated.x86_64/cross-tools-x86_64/sysroot
develop=$sysroot/boot/system/non-packaged/develop
build=$top/generated.x86_64/vulkan-build

cmake -S "$top/vulkan-headers" -B "$build/headers" -G Ninja \
	-DCMAKE_TOOLCHAIN_FILE="$top/port/haiku-toolchain.cmake" \
	-DCMAKE_INSTALL_PREFIX="$develop" -DCMAKE_INSTALL_INCLUDEDIR=headers \
	-DCMAKE_INSTALL_DATADIR=lib > /dev/null
cmake --install "$build/headers" > /dev/null

cmake -S "$top/vulkan-loader" -B "$build/loader" -G Ninja \
	-DCMAKE_TOOLCHAIN_FILE="$top/port/haiku-toolchain.cmake" \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_PREFIX_PATH=/boot/system/non-packaged/develop \
	-DBUILD_TESTS=OFF -DUPDATE_DEPS=OFF \
	-DBUILD_WSI_XCB_SUPPORT=OFF -DBUILD_WSI_XLIB_SUPPORT=OFF \
	-DBUILD_WSI_WAYLAND_SUPPORT=OFF -DBUILD_WSI_DIRECTFB_SUPPORT=OFF \
	-DFALLBACK_DATA_DIRS=/boot/system/non-packaged/data:/boot/system/data \
	-DFALLBACK_CONFIG_DIRS=/boot/system/non-packaged/settings:/boot/system/settings \
	-DSYSCONFDIR=/boot/system/settings
cmake --build "$build/loader"
