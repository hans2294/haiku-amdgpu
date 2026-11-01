#!/bin/sh
# Waits until the VM stops answering or goes into KDL, and says so; for a run
# in the background while something tries to freeze it. Exits with the time and
# the last serial lines.
#   vm/hangwatch.sh [seconds to watch]
cd "$(dirname "$0")/.." || exit 1
end=$(( $(date +%s) + ${1:-3600} ))
missed=0
while [ "$(date +%s)" -lt "$end" ]; do
	if timeout 15 vm/ssh.sh true > /dev/null 2>&1; then
		missed=0
	else
		missed=$((missed + 1))
	fi
	if [ $missed -ge 3 ] || tail -n 30 logs/serial.log | grep -aqE "PANIC|kdebug>"; then
		echo "stopped answering at $(date -Is) (uptime of the host: $(uptime -p))"
		tail -n 25 logs/serial.log | tr -d '\r'
		exit 1
	fi
	sleep 10
done
echo "still answering after ${1:-3600} s"
