import os
import random
from datetime import datetime, timedelta

# 出力先ディレクトリ
base_dir = "/Users/yamaguchi/Haskell/haskell-log-unifier/examples/real_logs"
os.makedirs(os.path.join(base_dir, "nginx"), exist_ok=True)
os.makedirs(os.path.join(base_dir, "apache"), exist_ok=True)
os.makedirs(os.path.join(base_dir, "myapp"), exist_ok=True)

start_time = datetime(2026, 6, 7, 13, 0, 0)

# Nginx ログのダミーパラメータ
nginx_ips = ["192.168.1.10", "192.168.1.11", "10.0.0.5", "172.16.0.2"]
nginx_paths = ["/index.html", "/api/users", "/api/products", "/images/logo.png", "/css/style.css"]

curr_time = start_time
nginx_lines = []
apache_lines = []
myapp_lines = []

# 1000回ループしてログを生成（各サービス約1000行）
for i in range(1000):
    # タイムスタンプを進める（ランダムに1〜5秒）
    curr_time += timedelta(seconds=random.randint(1, 5))
    
    # 1. Nginx ログ (Apache風タイムスタンプ)
    ts_nginx = curr_time.strftime("%d/%b/%Y:%H:%M:%S")
    ip = random.choice(nginx_ips)
    path = random.choice(nginx_paths)
    status = 200 if random.random() > 0.05 else random.choice([404, 302])
    
    # 連鎖障害のタイミング (i == 450 付近でNginx 502)
    if i == 450:
        nginx_lines.append(f"{ip} - - [{ts_nginx}] GET /api/checkout 502\n")
    else:
        nginx_lines.append(f"{ip} - - [{ts_nginx}] GET {path} {status}\n")

    # 2. Apache ログ (Apache風タイムスタンプ、i == 448 付近で Connection Refused)
    ts_apache = curr_time.strftime("%d/%b/%Y:%H:%M:%S")
    if i == 448:
        apache_lines.append(f"[{ts_apache}] ERROR: Apache Connection Refused\n")
    else:
        apache_lines.append(f"[{ts_apache}] 127.0.0.1 GET /internal/status 200\n")

    # 3. MyApp ログ (ISO形式 YYYY/MM/DD HH:MM、i == 452 付近で DBエラー)
    ts_myapp = curr_time.strftime("%Y/%m/%d %H:%M")
    if i == 452:
        myapp_lines.append(f"{ts_myapp} ERROR: myapp1 Database connection failed\n")
    else:
        latency = random.randint(10, 150)
        myapp_lines.append(f"{ts_myapp} INFO: request processed in {latency}ms\n")

# 保存
with open(os.path.join(base_dir, "nginx/access.log"), "w") as f:
    f.writelines(nginx_lines)
with open(os.path.join(base_dir, "apache/access.log"), "w") as f:
    f.writelines(apache_lines)
with open(os.path.join(base_dir, "myapp/app.log"), "w") as f:
    f.writelines(myapp_lines)

print("Real log files generated successfully!")
