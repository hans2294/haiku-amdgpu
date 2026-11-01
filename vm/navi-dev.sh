# Run at login by the launch job of the dev image: runs the tests on the card,
# starts sshd for the host's vm/haiku_ed25519 key, and puts what happened into
# the serial log (in the VM) and the syslog, and into /boot/home/navi-report.txt,
# which stays on the disk: on a real machine, read it from Linux afterwards.
REPORT=/boot/home/navi-report.txt
report() { tee -a $REPORT > /dev/dprintf; }
log() { echo "navi-dev: $*" | report; }

echo "=== navi-dev $(date) on $(uname -a)" >> $REPORT
listdev 2>/dev/null | grep -i -B1 -A2 "display" | report

# Before sshd: the network may not come up, and the serial log is
# enough to see what amdgpu did.
# app_server loads the driver at boot (for the desktop); wait for it
log "amdgpu: loading"
for i in $(seq 60); do
	[ -e /dev/misc/amdgpu/0 ] && break
	ls /dev/graphics > /dev/null
	sleep 1
done
log "amdgpu: $(cat /dev/misc/amdgpu/0 2>&1)"
log "amdgpu: nodes: $(ls /dev/dri 2>&1 | tr '\n' ' ')"
# card0 belongs to app_server (DRM master) now; the render node is free
amdgputest /dev/dri/renderD128 2>&1 | sed 's/^/amdgputest: /' | report
libdrmtest 2>&1 | sed 's/^/libdrmtest: /' | report
vkheadless libvulkan.so.1 2>&1 | sed 's/^/vkheadless: /' | report
gltest 2>&1 | sed 's/^/gltest: /' | report
# Needs app_server, which comes up a little after the login job runs
for i in $(seq 60); do
	[ -n "$(roster 2>/dev/null | grep -i tracker)" ] && break
	sleep 1
done
vkwindow 4 immediate 2>&1 | sed 's/^/vkwindow: /' | report
vkwindow 4 2>&1 | sed 's/^/vkwindow: /' | report
vkwindow 4 immediate plain 2>&1 | sed 's/^/vkwindow: /' | report
vsynctest 2>&1 | sed 's/^/vsynctest: /' | report
# An ordinary BGLView program; left running on the desktop
/boot/system/demos/GLTeapot > /var/log/glteapot.log 2>&1 &
sleep 3
listimage $! | grep -o '/boot/system/[^ ]*libGL[^ ]*' \
	| sed 's/^/glteapot: /' | report
sed 's/^/glteapot: /' /var/log/glteapot.log | report
log "amdgpu: done"
sync

# First boot processing of the openssh package creates the sshd user.
for i in $(seq 180); do
	grep -q '^sshd:' /etc/passwd 2> /dev/null && break
	sleep 1
done
# A VM stopped while ssh-keygen ran leaves broken host keys behind, which
# ssh-keygen -A keeps and sshd refuses; throw those away first.
for key in /boot/system/settings/ssh/ssh_host_*_key; do
	[ -e "$key" ] || continue
	ssh-keygen -y -f "$key" > /dev/null 2>&1 || rm -f "$key" "$key.pub"
done
ssh-keygen -A > /dev/dprintf 2>&1
sync
/bin/sshd -e -E /dev/dprintf
log "sshd exited with $?"
