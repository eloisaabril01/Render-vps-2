FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
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

# Setup directories and files
RUN mkdir -p /novnc /opt/qemu /cloud-init

# Download cloud image
RUN curl -L https://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img \
    -o /opt/qemu/ubuntu.img

# Create cloud-init config
RUN echo "instance-id: ubuntu-vm\nlocal-hostname: ubuntu-vm" > /cloud-init/meta-data
RUN printf "#cloud-config\nusers:\n  - name: user\n    passwd: \$6\$salt\$hash\n    shell: /bin/bash\n    sudo: ALL=(ALL) NOPASSWD:ALL\nssh_pwauth: true\n" > /cloud-init/user-data
RUN genisoimage -output /opt/qemu/seed.iso -volid cidata -joliet -rock \
    /cloud-init/user-data /cloud-init/meta-data

# Setup noVNC
RUN curl -L https://github.com/novnc/noVNC/archive/refs/tags/v1.3.0.zip -o /tmp/novnc.zip && \
    unzip /tmp/novnc.zip -d /tmp && \
    mv /tmp/noVNC-1.3.0/* /novnc && \
    rm -rf /tmp/novnc.zip /tmp/noVNC-1.3.0

# Create start script
RUN echo '#!/bin/bash\n\
websockify --web=/novnc 6080 localhost:5900 &\n\
qemu-system-x86_64 \\\n\
    -m 1G \\\n\
    -smp 1 \\\n\
    -drive file=/opt/qemu/ubuntu.img,format=raw,if=virtio \\\n\
    -drive file=/opt/qemu/seed.iso,format=raw,if=virtio \\\n\
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \\\n\
    -device virtio-net,netdev=net0 \\\n\
    -vnc :0 \\\n\
    -daemonize\n\
wait' > /start.sh && chmod +x /start.sh

EXPOSE 6080 2222
CMD ["/start.sh"]
