FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install minimal packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    cloud-image-utils \
    genisoimage \
    novnc \
    websockify \
    curl \
    unzip \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Use Alpine-based smaller image instead (uncomment if needed)
# FROM alpine:latest
# RUN apk add --no-cache qemu-system-x86_64 qemu-img novnc websockify python3

# Create directories
RUN mkdir -p /novnc /opt/qemu /cloud-init

# Download minimal cloud image (smaller footprint)
RUN curl -L https://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img \
    -o /opt/qemu/ubuntu.img

# Minimal cloud-init config
RUN echo "instance-id: ubuntu-vm\nlocal-hostname: ubuntu-vm" > /cloud-init/meta-data
RUN printf "#cloud-config\n\
users:\n\
  - name: user\n\
    passwd: \$6\$salt\$hash\n\
    shell: /bin/bash\n\
    sudo: ALL=(ALL) NOPASSWD:ALL\n\
ssh_pwauth: true\n" > /cloud-init/user-data

# Create cloud-init ISO
RUN genisoimage -output /opt/qemu/seed.iso -volid cidata -joliet -rock \
    /cloud-init/user-data /cloud-init/meta-data

# Setup noVNC
RUN curl -L https://github.com/novnc/noVNC/archive/refs/tags/v1.3.0.zip -o /tmp/novnc.zip && \
    unzip /tmp/novnc.zip -d /tmp && \
    mv /tmp/noVNC-1.3.0/* /novnc && \
    rm -rf /tmp/novnc.zip /tmp/noVNC-1.3.0

# Lightweight start script
RUN echo '#!/bin/sh
qemu-system-x86_64 \
    -m 1G \
    -smp 1 \
    -drive file=/opt/qemu/ubuntu.img,format=raw,if=virtio \
    -drive file=/opt/qemu/seed.iso,format=raw,if=virtio \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device virtio-net,netdev=net0 \
    -vnc :0 \
    -daemonize

websockify --web=/novnc ${PORT:-6080} localhost:5900 &
sleep 3
python3 -m http.server 8000 &
wait' > /start.sh && chmod +x /start.sh

EXPOSE 6080 2222 8000
CMD ["/start.sh"]
