#!/bin/bash
echo "Очистка следов тестирования..."
pkill -f qemu-system-x86_64 || true
rm -f seed.img
rm -f vm.log
rm -f vm-console.log
rm -f user-data.yaml meta-data.yaml vm_key vm_key.pub noble-server-cloudimg-amd64.img.part

# Базовый образ noble-server-cloudimg-amd64.img не удаляем
echo "Готово."
