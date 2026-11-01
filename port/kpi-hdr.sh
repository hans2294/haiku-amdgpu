#!/bin/sh
# Writes a linuxkpi header from stdin, adding the licence and include guard.
#   port/kpi-hdr.sh linux/foo.h <<'END' ... END
here=$(cd "$(dirname "$0")" && pwd)
f=$here/../haiku/src/libs/compat/linuxkpi/include/$1
g=_LINUXKPI_$(echo "$1" | tr 'a-z/.-' 'A-Z___')
mkdir -p "$(dirname "$f")"
{
	printf '/*\n * Copyright 2026, hans2294.\n * Distributed under the terms of the MIT License.\n */\n'
	printf '#ifndef %s\n#define %s\n\n' "$g" "$g"
	cat
	printf '\n#endif\n'
} > "$f"
