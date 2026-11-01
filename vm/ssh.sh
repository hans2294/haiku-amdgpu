#!/bin/sh
# Runs a command in the haiku-navi VM:  vm/ssh.sh listdev
# Host keys change with every rebuilt image, so they are not checked.
cd "$(dirname "$0")/.." || exit 1
ip=$(vm/vm-ip.sh) || exit 1
exec ssh -i vm/haiku_ed25519 -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
	-o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes \
	"user@$ip" "$@"
