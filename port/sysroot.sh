#!/bin/sh
# Fills the cross tools' sysroot with what programs for Haiku link against:
# Haiku's headers and libraries, gcc's, and libgame for BGLView's direct mode.
#   port/sysroot.sh   (after: jam haiku_cross_devel_sysroot_x86_64.hpkg libgame.so)
set -e
cd "$(dirname "$0")/../generated.x86_64"
system=cross-tools-x86_64/sysroot/boot/system
mkdir -p "$system/lib"
LD_LIBRARY_PATH=objects/linux/lib objects/linux/x86_64/release/tools/package/package \
	extract -C "$system" \
	objects/haiku/x86_64/packaging/packages/haiku_cross_devel_sysroot_x86_64.hpkg
cp -a build_packages/gcc_syslibs-*/lib/. "$system/lib/"
cp -a build_packages/gcc_syslibs_devel-*/develop/lib/. "$system/develop/lib/" 2>/dev/null || true
for lib in libstdc++ libgcc_s libsupc++ libatomic; do
	ls "$system/develop/lib/$lib"* > /dev/null 2>&1 \
		|| ln -sf "../../lib/$lib.so" "$system/develop/lib/$lib.so"
done
cp objects/haiku/x86_64/release/kits/game/libgame.so "$system/develop/lib/" 2>/dev/null \
	|| cp "$(find objects/haiku/x86_64 -name libgame.so -type f | head -1)" "$system/develop/lib/"
