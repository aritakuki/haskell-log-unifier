import os
import random
from datetime import datetime, timedelta

# Output directory
base_dir = "/Users/yamaguchi/Haskell/haskell-log-unifier/examples/flat_real_logs"
os.makedirs(base_dir, exist_ok=True)

start_time = datetime(2026, 6, 7, 13, 0, 0)

# Dummy parameters
nginx_ips = ["192.168.1.10", "192.168.1.11", "10.0.0.5", "172.16.0.2"]
nginx_paths = ["/index.html", "/api/users", "/api/products", "/images/logo.png", "/css/style.css"]

curr_time = start_time
nginx_lines = []
apache_lines = []
myapp_lines = []

# Generate 1000 lines of logs for each service
for i in range(1000):
    # Increment time randomly by 1 to 5 seconds
    curr_time += timedelta(seconds=random.randint(1, 5))
    
    # 1. Nginx log (Apache style timestamp)
    ts_nginx = curr_time.strftime("%d/%b/%Y:%H:%M:%S")
    ip = random.choice(nginx_ips)
    path = random.choice(nginx_paths)
    status = 200 if random.random() > 0.05 else random.choice([404, 302])
    
    # Nginx 502 only at i == 450 (cascade failure trigger)
    if i == 450:
        nginx_lines.append(f"{ip} - - [{ts_nginx}] GET /api/checkout 502\n")
    else:
        nginx_lines.append(f"{ip} - - [{ts_nginx}] GET {path} {status}\n")
 
    # Apache Connection Refused at i == 300 (isolated) and i == 448 (part of cascade failure)
    ts_apache = curr_time.strftime("%d/%b/%Y:%H:%M:%S")
    if i in [300, 448]:
        apache_lines.append(f"[{ts_apache}] ERROR: Apache Connection Refused\n")
    else:
        apache_lines.append(f"[{ts_apache}] 127.0.0.1 GET /internal/status 200\n")
 
    # MyApp DB failure at i == 150 (isolated) and i == 452 (part of cascade failure)
    ts_myapp = curr_time.strftime("%Y/%m/%d %H:%M")
    if i in [150, 452]:
        myapp_lines.append(f"{ts_myapp} ERROR: myapp1 Database connection failed\n")
    else:
        latency = random.randint(10, 150)
        myapp_lines.append(f"{ts_myapp} INFO: request processed in {latency}ms\n")

# Save
with open(os.path.join(base_dir, "apache_access.log"), "w") as f:
    f.writelines(apache_lines)
with open(os.path.join(base_dir, "nginx_access.log"), "w") as f:
    f.writelines(nginx_lines)
with open(os.path.join(base_dir, "myapp1_app.log"), "w") as f:
    f.writelines(myapp_lines)

print("Flat test log files generated successfully in examples/flat_real_logs/")
