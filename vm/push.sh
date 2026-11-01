#!/bin/sh
# Copies files into the haiku-navi VM:  vm/push.sh <guest dir> <file>...
cd "$(dirname "$0")/.." || exit 1
dir=$1
shift
ip=$(vm/vm-ip.sh) || exit 1
exec scp -q -i vm/haiku_ed25519 -o UserKnownHostsFile=/dev/null \
	-o LogLevel=ERROR -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
	-o BatchMode=yes "$@" "user@$ip:$dir/"
