#!/bin/sh
# Prints the Linux source files (relative to the tree) that Kbuild would
# compile with config.mk, one per line.   port/kbuild-files.sh [linux tree]
here=$(cd "$(dirname "$0")" && pwd)
linux=${1:-$here/../linux-6.12}

print() {	# dir vars...
	dir=$1; shift
	make -s -f "$here/kbuild-print.mk" LINUX="$linux" DIR="$dir" VARS="$*" print
}

objects() {	# dir vars...
	dir=$1
	print "$@" | sed 's/^[^=]*=//' | tr ' ' '\n' | grep '\.o$' \
		| sed "s|^|$dir/|; s|\.o$|.c|"
}

# Single-file modules listed straight in obj-y (drm_exec.o, drm_buddy.o, ...),
# leaving out composite ones that have their own <name>-y list.
singles() {	# dir
	print "$1" obj-y | sed 's/^[^=]*=//' | tr ' ' '\n' | grep '\.o$' | while read -r o; do
		[ -n "$(print "$1" "${o%.o}-y" | sed 's/^[^=]*=//')" ] && continue
		echo "$1/${o%.o}.c"
	done
}

{
	singles drivers/gpu/drm
	grep -v '^#' "$here/files-extra.txt"
	objects drivers/dma-buf obj-y
	objects drivers/gpu/drm drm-y drm_kms_helper-y drm_exec-y drm_buddy-y \
		drm_suballoc_helper-y drm_ttm_helper-y
	objects drivers/gpu/drm/ttm ttm-y
	objects drivers/gpu/drm/scheduler gpu-sched-y
	objects drivers/gpu/drm/display drm_display_helper-y
	objects drivers/gpu/drm/amd/amdgpu amdgpu-y
	objects drivers/gpu/drm/amd/amdxcp amdxcp-y
} | sed 's|/[^/]*/\.\./|/|g; s|/[^/]*/\.\./|/|g' | sort -u
