#!/bin/sh
# Types a command into the VM's keyboard (e.g. at the KDL prompt) and prints
# the serial output it produces.   vm/kdl.sh "threads"
cd "$(dirname "$0")/.." || exit 1
before=$(wc -l < logs/serial.log)

key() {
	virsh -c qemu:///system send-key haiku-navi "$@" > /dev/null
	sleep 0.05
}

printf '%s\n' "$1" | fold -w1 | while IFS= read -r c; do
	case "$c" in
		[a-z]) key "KEY_$(echo "$c" | tr a-z A-Z)" ;;
		[A-Z]) key KEY_LEFTSHIFT "KEY_$c" ;;
		[0-9]) key "KEY_$c" ;;
		" ") key KEY_SPACE ;;
		-) key KEY_MINUS ;;
		.) key KEY_DOT ;;
		/) key KEY_SLASH ;;
		_) key KEY_LEFTSHIFT KEY_MINUS ;;
		*) echo "kdl.sh: cannot type '$c'" >&2 ;;
	esac
done
key KEY_ENTER

sleep "${2:-2}"
tail -n +$((before + 1)) logs/serial.log | tr -d '\r'
