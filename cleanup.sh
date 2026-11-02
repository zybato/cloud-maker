#!/bin/bash
echo "Очистка следов тестирования..."
pkill -f qemu-system-x86_64 || true
rm -f seed.img
rm -f vm.log
# Базовый образ noble-server-cloudimg-amd64.img не удаляем
echo "Готово."
