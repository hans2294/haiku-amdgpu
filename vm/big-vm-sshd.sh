# Starts sshd in the big VM (vm/big-vm.sh); the image for a real machine has no
# job for it. Same steps as navi-dev.sh.
for i in $(seq 180); do
	grep -q '^sshd:' /etc/passwd 2> /dev/null && break
	sleep 1
done
for key in /boot/system/settings/ssh/ssh_host_*_key; do
	[ -e "$key" ] || continue
	ssh-keygen -y -f "$key" > /dev/null 2>&1 || rm -f "$key" "$key.pub"
done
ssh-keygen -A > /dev/dprintf 2>&1
sync
exec /bin/sshd -e -E /dev/dprintf
