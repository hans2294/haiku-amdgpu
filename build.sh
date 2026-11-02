#!/bin/sh
# Builds the cross tools, the driver, libdrm, Mesa, the Vulkan loader and the
# packages in generated.x86_64/packages. Run ./setup.sh first. Takes a good while
# the first time; running it again only builds what changed. Logs go to logs/.
#   ./build.sh
set -e
cd "$(dirname "$0")"
top=$PWD
jobs=$(nproc)
mkdir -p logs tools/bin generated.x86_64

step() { echo "== $1"; }
PATH=$top/tools/bin:$top/tools/venv/bin:$PATH
export PATH

if [ ! -x tools/bin/jam ]; then
	step "jam"
	make -C buildtools/jam > logs/build-jam.log 2>&1
	cp buildtools/jam/bin.*/jam tools/bin/
fi

if [ ! -x tools/venv/bin/meson ]; then
	step "meson and friends (tools/venv)"
	python3 -m venv tools/venv
	tools/venv/bin/pip install -q -r port/requirements.txt
fi

cd generated.x86_64
if [ ! -f build/BuildConfig ]; then
	step "Haiku's cross tools (the longest step)"
	../haiku/configure -j"$jobs" --cross-tools-source ../buildtools \
		--build-cross-tools x86_64 > ../logs/build-configure.log 2>&1
fi

step "the driver, libdrm, the test programs and the sysroot"
jam -q -j"$jobs" amdgpu amdgpu_kms.accelerant libdrm.so libdrm_amdgpu.so \
	libposix_error_mapper.a libgame.so haiku_cross_devel_sysroot_x86_64.hpkg \
	amdgputest evicttest gltest kmstest libdrmtest vkheadless tearingtest vkwindow \
	vsynctest hda \
	'<build>bfs_shell' \
	> ../logs/build-jam-targets.log 2>&1
cd ..

step "the sysroot for Mesa"
port/sysroot.sh
port/libdrm-sysroot.sh
port/libelf-mini/build.sh

step "the Vulkan loader"
port/vulkan-loader-build.sh > logs/build-vulkan-loader.log 2>&1

step "Mesa"
port/mesa-build.sh > logs/build-mesa.log 2>&1

step "the packages"
port/build-packages.sh
