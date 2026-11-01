#!/bin/sh
# Starts Luanti and Firefox in the VM and keeps its mouse moving, the way a
# user would have it, while vm/hangwatch.sh waits for a freeze.
#   vm/stress.sh [seconds] [WxH of the VM's screen]
cd "$(dirname "$0")/.." || exit 1
seconds=${1:-3600}
export DRAG_SCREEN=${2:-1920x1080}
vm/ssh.sh 'nohup /boot/system/apps/Luanti/Luanti > /var/log/luanti.log 2>&1 < /dev/null &
	sleep 5
	nohup /boot/system/bin/firefox https://www.haiku-os.org/ > /var/log/firefox.log 2>&1 < /dev/null &
	true'
end=$(( $(date +%s) + seconds ))
width=${DRAG_SCREEN%x*}
height=${DRAG_SCREEN#*x}
while [ "$(date +%s)" -lt "$end" ]; do
	vm/drag.py $((width / 4)) $((height / 4)) $((width * 3 / 4)) $((height * 3 / 4)) 30 1 \
		> /dev/null 2>&1 || exit 1
done
