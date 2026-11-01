#!/bin/sh
# Cross-builds Mesa's RADV and radeonsi (with EGL, GLES, OpenGL) for Haiku
# from ../mesa (branch haiku) into generated.x86_64/mesa-build. Needs
# libdrm and libelf-mini in the sysroot (port/libdrm-sysroot.sh,
# port/libelf-mini/build.sh).   port/mesa-build.sh [--reconfigure]
set -e
top=$(cd "$(dirname "$0")/.." && pwd)
build=$top/generated.x86_64/mesa-build
PATH=$top/tools/venv/bin:$PATH
sed "s|@TOP@|$top|g" "$top/port/mesa-cross.ini.in" > "$top/generated.x86_64/mesa-cross.ini"

if [ ! -d "$build" ] || [ "$1" = --reconfigure ]; then
	meson setup ${1:+--reconfigure} "$build" "$top/mesa" \
		--cross-file "$top/generated.x86_64/mesa-cross.ini" \
		--buildtype=release -Db_ndebug=true \
		-Dplatforms= -Dvulkan-drivers=amd -Dgallium-drivers=radeonsi,softpipe \
		-Dopengl=true -Dgles1=disabled -Dgles2=enabled -Degl=enabled \
		-Dglx=disabled -Dgbm=disabled -Dllvm=disabled -Damd-use-llvm=false \
		-Dvideo-codecs= -Dzlib=disabled -Dzstd=disabled -Dexpat=disabled \
		-Dxmlconfig=disabled -Dvalgrind=disabled -Dlibunwind=disabled \
		-Dlmsensors=disabled -Dbuild-tests=false -Dshader-cache=disabled \
		-Dvulkan-layers= -Dtools=
fi
ninja -C "$build" "$@"
