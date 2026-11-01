#!/bin/sh
# Binds the RX 7900 GRE (and its HDMI audio) to vfio-pci at boot, so the
# Haiku VM can use it without unbinding amdgpu at runtime.
#
#   sudo vm/vfio-boot.sh install   then reboot
#   sudo vm/vfio-boot.sh remove    then reboot, and the host gets the card back
#
# Why at boot: KWin 6.8 segfaults when a DRM device disappears, which is
# what "virsh nodedev-detach" does to amdgpu's card.
# Why disable_idle_d3: vfio-pci's runtime-PM resume oopses on this kernel
# (7.3.0-cachyos, vfio_pci_core_runtime_resume) when QEMU opens the card.

CONF=/etc/modprobe.d/vfio-7900gre.conf

case "$1" in
	install)
		cat > "$CONF" <<'EOF'
# RX 7900 GRE (Navi 31) and its HDMI audio go to vfio-pci for the Haiku VM.
# Written by vm/vfio-boot.sh; remove with "vfio-boot.sh remove".
options vfio-pci ids=1002:744c,1002:ab30 disable_idle_d3=1
softdep amdgpu pre: vfio-pci
softdep snd_hda_intel pre: vfio-pci
EOF
		echo "wrote $CONF; reboot to apply"
		;;
	remove)
		rm -f "$CONF"
		echo "removed $CONF; reboot to give the card back to amdgpu"
		;;
	*)
		echo "usage: $0 install|remove" >&2
		exit 1
		;;
esac
