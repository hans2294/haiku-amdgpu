#!/bin/sh
# Fetches everything the build needs, each at the exact version this was made
# on, and puts the patches on top. A project that is already here stays as it
# is. Pushing is turned off in all of them: this is not a contribution.
#   ./setup.sh
set -e
cd "$(dirname "$0")"
top=$PWD

# name  url  commit or tag
projects='
haiku           https://review.haiku-os.org/haiku                                9e95f7b83398105242c6a8b82ea0bde23c9e4a14
buildtools      https://review.haiku-os.org/buildtools                           33d46bf5c300bd34cd07c596431e4545c754ac03
linux-6.12      https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git v6.12.115
mesa            https://gitlab.freedesktop.org/mesa/mesa.git                     mesa-26.2.6
libdrm          https://gitlab.freedesktop.org/mesa/drm.git                      libdrm-2.4.134
vulkan-loader   https://github.com/KhronosGroup/Vulkan-Loader.git                v1.4.367
vulkan-headers  https://github.com/KhronosGroup/Vulkan-Headers.git               v1.4.367
'
firmwareTag=20261019
firmwareURL=https://gitlab.com/kernel-firmware/linux-firmware/-/raw/$firmwareTag/amdgpu

echo "$projects" | while read -r name url version; do
	[ -n "$name" ] || continue
	if [ -e "$name" ]; then
		echo "$name: already here"
		continue
	fi
	echo "$name: fetching $version"
	case "$version" in
		# Haiku's and buildtools' build take their version from the history's tags
		[0-9a-f][0-9a-f][0-9a-f][0-9a-f]*[0-9a-f]) git clone -q "$url" "$name" ;;
		*) git -c advice.detachedHead=false clone -q --depth 1 --branch "$version" "$url" "$name" ;;
	esac
	git -C "$name" -c advice.detachedHead=false checkout -q "$version"
	git -C "$name" remote set-url --push origin DISABLED-this-is-not-a-contribution
	if [ -d "patches/$name" ]; then
		git -C "$name" switch -q -c haiku-amdgpu
		git -C "$name" -c user.name=haiku-amdgpu -c user.email=haiku-amdgpu@localhost \
			am -q --committer-date-is-author-date "$top/patches/$name"/*.patch
	fi
done

ln -sf ../../../config/UserBuildConfig haiku/build/jam/UserBuildConfig
port/gen-autoconf.sh

# Navi 31's firmware, as linux-firmware has it; checked against what ran here
mkdir -p vm/firmware
while read -r sum file; do
	[ -f "vm/firmware/$file" ] || curl -sS --fail -o "vm/firmware/$file" "$firmwareURL/$file"
done < port/firmware.sha256
(cd vm/firmware && sha256sum --quiet -c "$top/port/firmware.sha256")
echo "firmware: linux-firmware $firmwareTag"

# Only for vm/ssh.sh and friends: goes into the VM's images, not into packages
if [ ! -e vm/haiku_ed25519 ]; then
	ssh-keygen -q -t ed25519 -N '' -C haiku-navi-vm -f vm/haiku_ed25519
	cp vm/haiku_ed25519.pub vm/authorized_keys
fi

echo "setup: done. Next: ./build.sh"
