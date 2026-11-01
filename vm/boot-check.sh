#!/bin/sh
# Starts the VM and waits until navi-dev.sh has brought up the PSP and SMU
# (native driver) or loaded Linux's amdgpu; prints what happened.
#   vm/boot-check.sh
cd "$(dirname "$0")/.." || exit 1
: > logs/serial.log
vm/start.sh > /dev/null || exit 1
t=0
until grep -qaE "navi-dev: amdgpu: done|PANIC" logs/serial.log \
		|| [ $t -ge 300 ]; do
	sleep 3
	t=$((t + 3))
done
tr -d '\r' < logs/serial.log \
	| grep -aE "navi-dev: amdgpu|PANIC|amdgpu[: ]|amdgputest|libdrmtest|vkheadless|vkwindow|wsi:|gltest|glteapot|vsynctest|amdgpu_kms|kmstest|\[drm|linuxkpi" \
	| sed 's/^package_daemon: \[[^]]*\] //'
