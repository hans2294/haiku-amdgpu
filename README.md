# haiku-amdgpu

Linux 6.12's `amdgpu` driver running unchanged on [Haiku](https://www.haiku-os.org/)
on a Linux compatibility layer, with libdrm, Mesa's radeonsi (OpenGL 4.6) and RADV
(Vulkan), and the Haiku desktop on the card through KMS.

**This is an experiment, not a product.** It was written almost entirely by an AI
(Claude, from Anthropic), directed by one developer who doesn't work in C, in a
couple of days, for fun. It has run on two GPUs. Nobody has reviewed the
code. It runs in the kernel, so a bug can crash the machine or damage data.

**This is not a contribution to Haiku**, and please don't submit any of it there:
Haiku doesn't accept AI-generated code. Any problem here is this project's, not
Haiku's.

![The Haiku desktop with GLTeapot on the card](docs/images/gl-direct.jpg)

## What works

On an RX 7900 GRE (Navi 31: GC 11.0.0, DCN 3.2), and most of it on an integrated
Raphael GPU:

- The desktop on the card, up to 5120x1440 at 240 Hz, with a hardware cursor
- OpenGL 4.6 in ordinary `BGLView` programs: GLTeapot, SuperTuxKart and Luanti run
- Vulkan through RADV, in windows through `vulkan_haiku.h`
- Drawing straight into the frame buffer for `BDirectWindow` programs, without
  the CPU copying pixels
- A desktop with little or no tearing. A full image has this repository's `app_server`,
  which flips by itself. On an ordinary Haiku, the accelerant flips from a shadow copy of
  the screen; see [Tearing](#tearing)
- Sound through the card to the monitor, over DP: stereo only, and heard in a VM,
  not yet on a real machine. See [Sound over HDMI/DP](#sound-over-hdmidp)

There is no video decoding, and only the first connected monitor is used. With
`app_server`'s page flipping, a screenshot can show a frame that is one frame old.

## Known problems

**Don't use this on another card without reading this:**

- **Buffers that move have only been tested on a card pretending to be small.**
  Mappings now fault their pages in as on Linux, so buffers can move. That has passed
  long tests on the RX 7900 GRE limited to 512 MiB of VRAM and a 256 MiB BAR
  (`vramlimit` and `vis_vramlimit` in the driver's settings file, and `evicttest`),
  but no card that is really small has run this.
- **Only two GPUs have run.** The RX 7900 GRE, and Raphael, the integrated GPU of a
  Ryzen 7600X (see [Which GPU](#which-gpu)). Code for GFX8 to GFX12 is built in, but only
  the firmware of these two is included, and the driver only touches these two by itself.
  See [Trying another card](#trying-another-card). Laptops and hybrid graphics are not
  expected to work. Only one GPU can be used at a time.
- **It depends on Haiku's kernel internals.** The driver uses private kernel
  interfaces, and a future nightly can break it with a kernel panic at boot. See
  [Haiku versions](#haiku-versions).
- **A panic looks like a freeze.** The kernel debugger doesn't draw on the card's
  screen, so everything just stops, including the mouse and Caps Lock.
- **There are unexplained failures.** In about 80 boots in the VM, one panicked with a
  page fault in the kernel's `remove_images`, which suggests corrupted kernel memory, and
  it may well be this driver. Three more stopped at `package_daemon` early in the boot,
  with all CPUs idle and before the driver had loaded, all soon after packages had changed.
  None of them came back in repeated runs, and the causes are unknown.
- `pkgman full-sync` removes `mesa_radeon` and puts Mesa 22 back.

If Haiku doesn't boot with this installed, hold Shift during boot and either pick
an earlier state under *Select package state*, or use *Select safe mode options* →
*Disable system components* and block `add-ons/kernel/drivers/bin/amdgpu`.

## Haiku versions

Tested in a VM with the card passed through, with official nightlies and
a monitor on the card at 1280x720, limited to 512 MiB of VRAM:

| Nightly | Date | Result |
|---|---|---|
| hrev60317 | 2026-11-01 | Works |
| hrev60102 | 2026-09-14 | Works |
| hrev59998 | 2026-08-20 | Too old: the driver refuses to load, and the desktop stays on the frame buffer |

The driver refuses any kernel older than hrev60102, as those panic. `pkgman` can't
stop you from installing on one, as the `haiku` package counts as compatible back
to R1~alpha, and GL then doesn't work. Stable releases have not been tried: r1beta6
should be refused too, and would need its own build, as its kernel has a different
debug level.

## Tearing

Haiku's own `app_server` draws straight into the frame buffer. So the accelerant gives it a
shadow in RAM instead, and a thread copies the pages written to, which the driver finds from
the page tables' dirty bits, into a hidden buffer that it flips to at the next vblank. As
`app_server` doesn't say when it is done drawing, the thread waits for the writes to pause.
`TEAR_FREE=0` in the environment turns it off.

Torn frames out of 451, seen through a capture dongle, on a window of 800x600 going black and
white at 1920x1080 and 60 Hz, on official hrev60317 (and with the shadow on hrev60102, too):

| Fills per second | Without the shadow | With it |
|---|---|---|
| As fast as it can | 451 | 26 to 92 |
| 120 | not measured | 2 |
| 60 | 165 | 1 |
| 30 | 76 | 0 |
| 10 | 32 | 0 |

On hrev60102, one run at 30 per second had 7 torn frames, where hrev60317 had none. So a program
that draws without pause can still tear, and the numbers vary between runs. With the shadow, GL and Vulkan don't draw
straight into the frame buffer but go through a bitmap, which is slower. Higher resolutions and
refresh rates have not been measured, and copying takes longer there.

## Which GPU

The driver takes the GPU the firmware showed the boot screen on, if that is an RX 7900 GRE
or Raphael. So move the monitor and reboot. This has picked the right one both ways on one
real machine, going by what was on the screen; the firmware decides, so a BIOS setting for the
first display can matter more than the cable. If the boot screen is on anything else, the
driver takes an RX 7900 GRE and leaves an integrated GPU alone, as it may have no monitor. That
case has not been tried.

`/boot/home/config/settings/kernel/drivers/amdgpu` decides instead, if it says anything:
`devices 164e`, `devices 744c 164e` or `devices all`. The IDs are PCI device IDs of AMD GPUs.

Raphael (1002:164e, GC 10.3.6, DCN 3.1.5, 512 MiB of VRAM) has run on a real machine, for
a short time: the desktop without tearing, GLTeapot, Luanti and Firefox, with nothing going
wrong.

## Trying another card

No other card has run this, so nobody knows what happens on yours. RX 6000 and RX 7000 are
the closest to the two that have, but that is a guess. Only try it on a machine that can
stand a freeze, with its data backed up. A report is useful whether it works or not.

1. Install the packages, with `amdgpu_firmware`, which has the firmware of the other cards
   (from the release, or `port/build-firmware-package.sh`):

   ```bash
   pkgman install ./amdgpu_linux-*.hpkg ./libdrm-*.hpkg ./mesa_radeon-*.hpkg ./vulkan_loader-*.hpkg ./amdgpu_firmware-*.hpkg
   ```

2. Run `amdgpu-report` and find your card under *Graphics cards* in `~/amdgpu-report.txt`:
   vendor 1002, and a device ID like `73bf`. Then put that ID in the driver's settings:

   ```bash
   mkdir -p ~/config/settings/kernel/drivers
   ```

   ```bash
   echo "devices 73bf" > ~/config/settings/kernel/drivers/amdgpu
   ```

3. Reboot, with the monitor on that card. Leave it running for more than a minute.
4. Run `amdgpu-report` again, read the file, and
   [open an issue](https://github.com/hans2294/haiku-amdgpu/issues/new?template=another-card.md).

What can happen:

- **It works.** Screen names `amdgpu_kms` as the driver. Try GLTeapot.
- **The driver gives up.** The desktop comes up on Haiku's frame buffer, and the report says
  why, like a firmware file that is missing.
- **It freezes or the screen stays dark.** Turn the machine off, within the first minute for
  a dark screen. The next boot should come up on the frame buffer, because of the boot guard.

**The boot guard** is a file, `amdgpu_boot_guard`, next to the settings file. The driver
writes it before it starts the card, and removes it a minute later if the card came up. If a
boot finds it, the driver leaves the card alone. To try again:

```bash
rm ~/config/settings/kernel/drivers/amdgpu_boot_guard
```

It only works with `devices` in the settings file, so it isn't there for the two cards above
unless you name them. It doesn't help with a freeze after that minute: then hold Shift during
boot, as under [Known problems](#known-problems). Rebooting within the minute also sets it off,
which does no harm. It can't say why a machine froze. The report has the log of this boot and the one
before, but turning the machine off, or a panic, loses what hadn't reached the disk, so a report
after a freeze may say little. With a second GPU and Linux, [a VM](#in-a-vm) shows everything on its
serial log.

It has been tried on the RX 7900 GRE in a VM: stopping the VM hard, on hrev60317 and hrev60102, and
hiding firmware files, on hrev60317. A real freeze, and a dark screen after a failed start, have
not been tried. In the VM, the frame buffer is on a separate virtual card, so it stays up whatever
happens to the real one.

To stop trying, remove the settings and the firmware:

```bash
rm -f ~/config/settings/kernel/drivers/amdgpu ~/config/settings/kernel/drivers/amdgpu_boot_guard
```

```bash
pkgman uninstall amdgpu_firmware
```

## Sound over HDMI/DP

Haiku's `hda` driver skips digital outputs, so the card's audio device isn't used. A
patch turns them on, for Navi 31's audio device (1002:ab30) only: when Haiku turned
them on for everyone, analog sound cards lost their settings (Haiku's #20171). A full
image has the patch. An installed Haiku needs it next to its own `hda`, which is
blocked in `system/settings/packages`, as it would win otherwise:

```bash
sudo vm/install-hda-fix.sh <serial number of the disk>
```

The audio device may then have to be chosen under *Audio output* in Media. On official
nightlies this has only been seen to start a stream, not been listened to.

## Building

You need a Linux machine and about 20 GB of disk, plus: `git`, `curl`, `gcc`, `g++`,
`make`, `cmake`, `pkg-config`, `python3` with `venv`, `nasm`, `bison`, `flex`,
`autoconf`, `automake`, `gawk`, `texinfo`, `glslangValidator`, `zlib`, `zstd` and
`mtools`. The list comes from one machine and may not be complete; Haiku's own
[build pre-requisites](https://www.haiku-os.org/guides/building/pre-reqs) cover the
Haiku part.

```bash
./setup.sh
```

```bash
./build.sh
```

`setup.sh` fetches Haiku, buildtools, Linux, Mesa, libdrm and the Vulkan loader and
headers at the exact versions used here, puts `patches/` on top, and fetches the
firmware. `build.sh` builds it all, which takes a while the first time, and leaves
four packages in `generated.x86_64/packages`.

## Installing on a Haiku nightly

Copy the four packages to the machine, in a Terminal in that folder, then reboot:

```bash
pkgman install ./amdgpu_linux-*.hpkg ./libdrm-*.hpkg ./mesa_radeon-*.hpkg ./vulkan_loader-*.hpkg
```

This replaces the system's `mesa`, `mesa_devel` and `mesa_swpipe`. To go back, use
`pkgman uninstall` on the four packages and install those again.

## A full image

An image includes this build's `app_server` with the tear-free desktop, and the sound
patch. `vm/baremetal-image.sh` makes one with the test programs (`amdgputest`, `evicttest`,
`gltest`, `kmstest`, `libdrmtest`, `tearingtest`, `vkheadless`, `vkwindow`, `vsynctest`),
which it runs at boot, for a VM. `vm/usb-image.sh` needs that one, too, and makes the one
for a real machine, without them:

```bash
vm/baremetal-image.sh
```

```bash
vm/usb-image.sh <size of the disk in bytes>
```

Then `sudo vm/write-usb.sh /dev/sdX` for a USB stick or `sudo vm/write-disk.sh <serial>`
for an internal disk. **These erase the whole disk.** See
[docs/baremetal.md](docs/baremetal.md).

## In a VM

`vm/` runs Haiku in libvirt/QEMU with the card passed through, which is much nicer
for debugging: a freeze stays in the VM, and the serial log gets everything. The card
goes to `vfio-pci` at boot with `sudo vm/vfio-boot.sh install` and a reboot. Adjust the
PCI addresses in `vm/haiku-navi.xml` and `vm/vfio-boot.sh`, then:

```bash
NAVI_GPU=03:00.0 NAVI_BRIDGE=virbr0 vm/start.sh
```

`vm/nightly-vm.sh` does the same with an official nightly, and `vm/ssh.sh`,
`vm/push.sh`, `vm/stress.sh` and `vm/hangwatch.sh` drive and watch it. A connected
monitor on the card is needed for the desktop, page flipping and vsync; without one,
the desktop goes to the VM's virtual screen.

## What's where

| Path | What |
|---|---|
| `patches/haiku` | linuxkpi, the driver, the accelerant, `app_server`'s page flipping, test programs |
| `patches/mesa` | Haiku support in RADV and radeonsi, `BGLView`'s libGL, the Vulkan WSI |
| `patches/libdrm`, `patches/vulkan-*` | Haiku support |
| `port` | Build scripts, the list of Linux files, package definitions |
| `vm` | The VM, images and disks |
| `docs` | Work notes, in Danish: [the port](docs/amdgpu-port.md), [a real machine](docs/baremetal.md) |

## Licences

This repository's own scripts and notes are under the [MIT licence](LICENSE). The
patches are under the licences of what they change: MIT for Haiku and Mesa's parts,
and the others as in those projects. The driver is built from Linux's sources, so
a built `amdgpu_linux` package is covered by the GPL v2 as well. The firmware is
AMD's, under [its own licence](licenses/LICENSE.amdgpu), and isn't in this repository;
`setup.sh` and `port/build-firmware-package.sh` fetch it from linux-firmware. The latter leaves out
`isp_4_1_1.bin`, which is under another licence.
