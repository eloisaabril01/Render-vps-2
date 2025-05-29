#!/bin/bash

# Convert and prepare the disk image
qemu-img convert -f qcow2 -O raw /opt/qemu/ubuntu.img /opt/qemu/ubuntu.raw
qemu-img resize /opt/qemu/ubuntu.raw 10G

# Start QEMU with proper boot order
qemu-system-x86_64 \
    -m 1G \
    -smp 1 \
    -drive file=/opt/qemu/ubuntu.raw,format=raw,if=virtio \
    -drive file=/opt/qemu/seed.iso,format=raw,media=cdrom \
    -boot order=c \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device virtio-net,netdev=net0 \
    -vnc :0 \
    -daemonize

websockify --web=/novnc 6080 localhost:5900 &
wait
