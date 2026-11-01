#!/bin/sh
# Prints the VM's address: NAVI_VM_IP if set, what libvirt knows from its
# network, or what the host has seen of the VM's MAC address.
[ -n "$NAVI_VM_IP" ] && { echo "$NAVI_VM_IP"; exit 0; }
ip=$(virsh -c qemu:///system domifaddr haiku-navi 2>/dev/null \
	| awk '/ipv4/ {split($4, a, "/"); print a[1]; exit}')
[ -n "$ip" ] || ip=$(ip neigh | awk '/52:54:00:4a:1b:7e/ {print $1; exit}')
[ -n "$ip" ] || { echo "vm-ip: can't find the VM; set NAVI_VM_IP" >&2; exit 1; }
echo "$ip"
