#!/bin/bash
# Значения по умолчанию, если аргументы не переданы
RAM=${1:-2048}
CPU=${2:-2}

if [ ! -f noble-server-cloudimg-amd64.img ]; then
    echo "Скачиваем образ Ubuntu..."
    wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
fi
cloud-localds seed.img user-data.yaml meta-data.yaml
qemu-system-x86_64 \
  -accel tcg \
  -m $RAM \
  -smp $CPU \
  -drive file=noble-server-cloudimg-amd64.img,format=qcow2,if=virtio \
  -drive file=seed.img,format=raw,if=virtio \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  -nographic
