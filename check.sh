#!/bin/bash
echo "=== Запуск тестирования ==="

# 1. Запускаем ВМ в фоне
nohup ./run.sh > vm.log 2>&1 &
QEMU_PID=$!

echo "Ожидание загрузки ВМ и готовности SSH (максимум 8 минут)..."
SSH_READY=0

for i in {1..96}; do
    # Пытаемся реально подключиться по SSH
    if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR -p 2222 student@127.0.0.1 "exit" >/dev/null 2>&1; then
        SSH_READY=1
        break
    fi
    sleep 5
done

# 2. Выводим результат
if [ $SSH_READY -eq 1 ]; then
    echo "✅ УСПЕХ: ВМ запущена, cloud-init сработал, SSH доступен!"
    RESULT=0
else
    echo "❌ ОШИБКА: Не удалось подключиться по SSH за 8 минут. Проверьте vm.log."
    RESULT=1
fi

# 3. Останавливаем ВМ
echo "Остановка ВМ..."
kill $QEMU_PID
sleep 2
pkill -f qemu-system-x86_64 || true

exit $RESULT
