#!/bin/bash
cd "$(dirname "$0")"

KEY=vm_key
IMAGE=noble-server-cloudimg-amd64.img
EXPECTED_HOSTNAME=cloud-maker-vm
MAX_ATTEMPTS=3
SSH_OPTS="-i $KEY -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o BatchMode=yes -o LogLevel=ERROR"

if ! command -v ssh >/dev/null 2>&1; then
    echo "❌ Не найден ssh. Установите: sudo apt install -y openssh-client"
    exit 1
fi

VM_PID=""
# При любом выходе из скрипта (ошибка, Ctrl+C) останавливаем ВМ
trap '[ -n "$VM_PID" ] && kill $VM_PID 2>/dev/null' EXIT

stop_vm() {
    kill $VM_PID 2>/dev/null
    wait $VM_PID 2>/dev/null
}

# Запускает ВМ и ждёт SSH.
# Возвращает: 0 — SSH доступен, 1 — ошибка, 2 — kernel panic (можно повторить)
boot_vm() {
    rm -f vm-console.log
    nohup ./run.sh > vm.log 2>&1 < /dev/null &
    VM_PID=$!

    # Скачивание образа не считаем во время загрузки ВМ
    if [ ! -f "$IMAGE" ]; then
        echo "Ожидание скачивания образа Ubuntu..."
        while [ ! -f "$IMAGE" ] && kill -0 $VM_PID 2>/dev/null; do sleep 2; done
    fi

    echo "Ожидание загрузки ВМ и готовности SSH (максимум ~10 минут)..."
    for i in {1..120}; do
        if grep -q "Kernel panic" vm-console.log 2>/dev/null; then
            return 2
        fi
        if ! kill -0 $VM_PID 2>/dev/null; then
            echo "❌ ОШИБКА: ВМ завершилась раньше времени. Последние строки vm.log:"
            tail -n 20 vm.log
            tail -n 10 vm-console.log 2>/dev/null
            return 1
        fi
        if [ -f "$KEY" ] && timeout 20 ssh $SSH_OPTS student@127.0.0.1 "exit" >/dev/null 2>&1; then
            return 0
        fi
        sleep 5
    done
    echo "❌ ОШИБКА: ВМ не стала доступна по SSH за отведённое время. Консоль ВМ: vm-console.log."
    return 1
}

echo "=== Запуск тестирования ==="
BOOT=1
for attempt in $(seq 1 $MAX_ATTEMPTS); do
    echo "--- Попытка запуска ВМ $attempt из $MAX_ATTEMPTS ---"
    boot_vm
    BOOT=$?
    [ $BOOT -ne 2 ] && break
    echo "⚠️  Kernel panic при загрузке (типично для эмуляции TCG без KVM), перезапуск..."
    stop_vm
done

RESULT=1
if [ $BOOT -eq 0 ]; then
    VM_HOSTNAME=$(timeout 20 ssh $SSH_OPTS student@127.0.0.1 hostname 2>/dev/null)
    if [ "$VM_HOSTNAME" = "$EXPECTED_HOSTNAME" ]; then
        echo "✅ УСПЕХ: ВМ запущена, SSH доступен по ключу, cloud-init задал hostname: $VM_HOSTNAME"
        RESULT=0
    else
        echo "❌ ОШИБКА: SSH доступен, но hostname = '$VM_HOSTNAME' (ожидался $EXPECTED_HOSTNAME)"
    fi
elif [ $BOOT -eq 2 ]; then
    echo "❌ ОШИБКА: Kernel panic во всех $MAX_ATTEMPTS попытках. Последние строки vm-console.log:"
    tail -n 5 vm-console.log
fi

echo "Остановка ВМ..."
stop_vm

exit $RESULT
