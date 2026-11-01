#!/bin/sh
# (Re)creates linuxkpi/linux-include: relative symlinks to the Linux headers
# used as they are (drm/, uapi/ and passthrough-headers.txt).
here=$(cd "$(dirname "$0")" && pwd)
dest=$here/../haiku/src/libs/compat/linuxkpi/linux-include
rm -rf "$dest"
mkdir -p "$dest"
link() {	# path under linux-6.12/include
	mkdir -p "$dest/$(dirname "$1")"
	target=$(realpath --relative-to="$dest/$(dirname "$1")" "$here/../linux-6.12/include/$1")
	ln -s "$target" "$dest/$1"
}
link drm
link uapi
grep -v '^#' "$here/passthrough-headers.txt" | while read -r h; do
	[ -n "$h" ] && link "$h"
done
