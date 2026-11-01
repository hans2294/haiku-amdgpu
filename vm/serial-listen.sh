#!/bin/sh
# Receives the VM's serial port (kernel syslog) and appends it to logs/serial.log.
# Start before the VM; QEMU connects to it.
cd "$(dirname "$0")/.." || exit 1
exec socat -u TCP-LISTEN:4555,bind=127.0.0.1,reuseaddr,fork OPEN:logs/serial.log,creat,append
