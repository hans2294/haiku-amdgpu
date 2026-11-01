#!/usr/bin/env python3
# Writes a disk image from vm/usb-image.sh to a device: the area before the BFS
# partition (partition table, ESP) and BFS's blocks in use, by its block bitmap;
# free blocks may hold anything. Reads everything back afterwards. Run by
# vm/write-usb.sh, which checks the device first.
#   write-image.py <image> <device>
import fcntl
import os
import stat
import struct
import sys

kSector = 512
kChunk = 4 << 20
kBLKFLSBUF = 0x1261


def bfs_partition(image):
    table = os.pread(image, kSector, 0)
    if table[510:512] != b"\x55\xaa":
        sys.exit("write-image: no partition table in the image")
    for entry in range(4):
        fields = table[446 + entry * 16:462 + entry * 16]
        if fields[4] == 0xeb:
            return struct.unpack("<I", fields[8:12])[0] * kSector
    sys.exit("write-image: no BFS partition in the image")


def ranges_in_use(image, start):
    """Runs of (offset, length) on the disk: what is before BFS, and its blocks
    in use. The bitmap starts in BFS's block 1, a bit per block, in 32 bit
    little endian words."""
    block = os.pread(image, kSector, start + kSector)
    magic, _, blockSize, _, blockCount = struct.unpack("<IIIIq", block[32:56])
    if magic != 0x42465331:
        sys.exit("write-image: no BFS super block in the image")
    bitmap = os.pread(image, (blockCount + 7) // 8, start + blockSize)
    runs = [(0, start)]
    runStart = None
    # A whole-zero byte or all-ones byte is common; bytes keep this fast.
    for index, byte in enumerate(bitmap):
        if byte == 0xff and runStart is not None:
            continue
        if byte == 0 and runStart is None:
            continue
        for bit in range(8):
            current = index * 8 + bit
            if current >= blockCount:
                break
            if byte & (1 << bit):
                if runStart is None:
                    runStart = current
            elif runStart is not None:
                runs.append((start + runStart * blockSize,
                    (current - runStart) * blockSize))
                runStart = None
    if runStart is not None:
        runs.append((start + runStart * blockSize,
            (blockCount - runStart) * blockSize))
    return runs


def chunks(runs):
    for offset, length in runs:
        end = offset + length
        while offset < end:
            size = min(kChunk, end - offset)
            yield offset, size
            offset += size


def progress(verb, done, total):
    print(f"\r{verb}: {done >> 20} / {total >> 20} MiB", end="", flush=True)


imagePath, devicePath = sys.argv[1:3]
image = os.open(imagePath, os.O_RDONLY)
device = os.open(devicePath, os.O_RDWR)
runs = ranges_in_use(image, bfs_partition(image))
total = sum(length for _, length in runs)

done = 0
for offset, size in chunks(runs):
    data = os.pread(image, size, offset)
    if len(data) != size or os.pwrite(device, data, offset) != size:
        sys.exit(f"\nwrite-image: short transfer at {offset}")
    done += size
    if done % (64 << 20) < size:
        progress("Writing", done, total)
progress("Writing", done, total)

# A GPT disk keeps a copy of its old partition table at the very end, which
# would still look valid when the image is smaller than the disk.
deviceSize = os.lseek(device, 0, os.SEEK_END)
imageSize = os.lseek(image, 0, os.SEEK_END)
if deviceSize > imageSize:
    tail = min(1 << 20, deviceSize - imageSize)
    os.pwrite(device, bytes(tail), deviceSize - tail)

print("\nFlushing to the disk ...", flush=True)
os.fsync(device)
# so that the check below reads the disk, not the cache
if stat.S_ISBLK(os.fstat(device).st_mode):
    fcntl.ioctl(device, kBLKFLSBUF)

done = 0
for offset, size in chunks(runs):
    if os.pread(device, size, offset) != os.pread(image, size, offset):
        sys.exit(f"\nwrite-image: the disk differs at {offset}")
    done += size
    if done % (64 << 20) < size:
        progress("Checking", done, total)
progress("Checking", done, total)
print("\nwrite-image: written and checked")
