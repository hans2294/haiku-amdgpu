#!/bin/sh
# Builds libelf-mini for Haiku into the cross sysroot's
# /boot/system/non-packaged/develop (static, for Mesa).
#   port/libelf-mini/build.sh
set -e
here=$(cd "$(dirname "$0")" && pwd)
top=$here/../..
cross=$top/generated.x86_64/cross-tools-x86_64/bin/x86_64-unknown-haiku
dest=$top/generated.x86_64/cross-tools-x86_64/sysroot/boot/system/non-packaged/develop
work=$top/generated.x86_64/libelf-mini

mkdir -p "$work" "$dest/headers" "$dest/lib/pkgconfig"
"$cross-gcc" -O2 -fPIC -Wall -Werror -c "$here/libelf.c" -I"$here" \
	-o "$work/libelf.o"
rm -f "$work/libelf.a"
"$cross-ar" rcs "$work/libelf.a" "$work/libelf.o"
cp "$work/libelf.a" "$dest/lib/"
cp "$here/libelf.h" "$here/gelf.h" "$dest/headers/"
cat > "$dest/lib/pkgconfig/libelf.pc" <<PC
prefix=/boot/system/non-packaged
includedir=\${prefix}/develop/headers
libdir=\${prefix}/develop/lib

Name: libelf
Description: Read-only libelf for Mesa on Haiku (libelf-mini)
Version: 0.8.13
Libs: -L\${libdir} -lelf
Cflags: -I\${includedir}
PC
echo "libelf-mini installed into $dest"
