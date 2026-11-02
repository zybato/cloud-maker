from flask import Flask, jsonify, render_template, request
import subprocess

app = Flask(__name__)

# Настройки квот
MAX_RAM = 4096
MAX_CPU = 1  # Для TCG оставляем 1 ядро, иначе будет паника
current_ram = 0
current_cpu = 0

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/create', methods=['POST'])
def create_vm():
    global current_ram, current_cpu
    
    # 1. Проверка на повторный запуск
    if current_ram > 0:
        return jsonify({"status": "error", "message": "VM is already running! Please stop it first."}), 400

    # Получаем параметры
    req_ram = int(request.args.get('ram', 2048))
    req_cpu = int(request.args.get('cpu', 1))

    # 2. Проверка квот
    if req_ram > MAX_RAM or req_cpu > MAX_CPU:
        return jsonify({
            "status": "error", 
            "message": f"Quota exceeded! Max RAM: {MAX_RAM}MB, Max CPU: {MAX_CPU}"
        }), 403

    # 3. Обновляем счетчики и запускаем
    current_ram = req_ram
    current_cpu = req_cpu
    subprocess.Popen(["./run.sh", str(req_ram), str(req_cpu)])
    
    return jsonify({"status": "success", "message": f"VM started with {req_ram}MB RAM and {req_cpu} CPU"}), 202

@app.route('/stop', methods=['POST'])
def stop_vm():
    global current_ram, current_cpu
    subprocess.run(["pkill", "-f", "qemu-system-x86_64"])
    current_ram = 0
    current_cpu = 0
    return jsonify({"status": "success", "message": "VM stopped, quotas reset"}), 200

@app.route('/delete', methods=['POST'])
def delete_vm():
    global current_ram, current_cpu
    subprocess.run(["pkill", "-f", "qemu-system-x86_64"])
    subprocess.run(["./cleanup.sh"])
    current_ram = 0
    current_cpu = 0
    return jsonify({"status": "success", "message": "VM deleted and cleaned up"}), 200

@app.route('/status', methods=['GET'])
def status():
    # Статус теперь смотрим по внутренним переменным, а не по pgrep
    if current_ram > 0:
        return jsonify({"status": "running", "allocated_ram": current_ram, "allocated_cpu": current_cpu}), 200
    else:
        return jsonify({"status": "stopped", "allocated_ram": 0, "allocated_cpu": 0}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
