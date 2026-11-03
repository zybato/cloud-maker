#!/bin/bash
set -e
cd "$(dirname "$0")"

RAM=${1:-2048}
CPU=${2:-2}
IMAGE=noble-server-cloudimg-amd64.img
KEY=vm_key

# 1. Проверка зависимостей
MISSING=""
for cmd in qemu-system-x86_64 cloud-localds wget ssh-keygen; do
    command -v "$cmd" >/dev/null 2>&1 || MISSING="$MISSING $cmd"
done
if [ -n "$MISSING" ]; then
    echo "❌ Не найдены команды:$MISSING" >&2
    echo "Установите: sudo apt install -y qemu-system-x86 qemu-utils cloud-image-utils wget openssh-client" >&2
    exit 1
fi

# 2. Образ Ubuntu (качаем во временный файл, чтобы не остался битый образ при обрыве)
if [ ! -f "$IMAGE" ]; then
    echo "Скачиваем образ Ubuntu..."
    wget -O "$IMAGE.part" "https://cloud-images.ubuntu.com/noble/current/$IMAGE"
    mv "$IMAGE.part" "$IMAGE"
fi

# 3. SSH-ключ для доступа в ВМ (генерируется у каждого проверяющего свой)
if [ ! -f "$KEY" ]; then
    echo "Генерируем SSH-ключ $KEY..."
    ssh-keygen -t ed25519 -N "" -f "$KEY" -C cloud-maker -q
fi

# 4. cloud-init: подставляем ключ в шаблон, instance-id зависит от ключа,
#    чтобы при новом ключе cloud-init отработал заново
PUBKEY=$(cat "$KEY.pub")
IID="iid-$(sha256sum "$KEY.pub" | cut -c1-12)"
sed "s|SSH_KEY|$PUBKEY|" user-data.tpl.yaml > user-data.yaml
cat > meta-data.yaml <<META
instance-id: $IID
local-hostname: cloud-maker-vm
META
cloud-localds seed.img user-data.yaml meta-data.yaml

# 5. Ускоритель: KVM, если доступен, иначе программная эмуляция TCG
if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    echo "KVM доступен — используется аппаратная виртуализация"
    ACCEL="-accel kvm -cpu host"
else
    echo "⚠️  /dev/kvm недоступен — используется эмуляция TCG (загрузка будет медленной)"
    ACCEL="-accel tcg"
fi

# 6. Консоль ВМ:
#    запуск из терминала — интерактивная консоль (-nographic), как раньше;
#    запуск в фоне (check.sh) — QEMU не трогает stdin/stdout терминала,
#    консоль ВМ пишется в файл vm-console.log
if [ -t 0 ]; then
    CONSOLE="-nographic"
else
    CONSOLE="-display none -monitor none -serial file:vm-console.log"
fi

# exec: PID этого скрипта становится PID процесса QEMU
exec qemu-system-x86_64 \
  $ACCEL \
  -m "$RAM" \
  -smp "$CPU" \
  -drive file="$IMAGE",format=qcow2,if=virtio \
  -drive file=seed.img,format=raw,if=virtio \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  $CONSOLE
