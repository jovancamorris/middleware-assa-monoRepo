#!/bin/bash
set -e

# Target DB (defaults to host.docker.internal:3307 for host MariaDB, or mariadb:3306 for compose MariaDB)
TARGET_HOST="${DB_HOST:-host.docker.internal}"
TARGET_PORT="${DB_PORT:-3307}"

echo "[ENTRYPOINT] Starting DB forwarder: 127.0.0.1:3307 -> ${TARGET_HOST}:${TARGET_PORT}..."
python3 - << 'EOF' &
import socket, threading, os

src_port = 3307
dst_host = os.environ.get("DB_HOST", "host.docker.internal")
dst_port = int(os.environ.get("DB_PORT", "3307"))

def forward(src, dst):
    try:
        while True:
            data = src.recv(4096)
            if not data: break
            dst.sendall(data)
    except Exception:
        pass
    finally:
        try: src.close()
        except: pass
        try: dst.close()
        except: pass

def handle(client):
    try:
        remote = socket.create_connection((dst_host, dst_port), timeout=10)
        t1 = threading.Thread(target=forward, args=(client, remote), daemon=True)
        t2 = threading.Thread(target=forward, args=(remote, client), daemon=True)
        t1.start()
        t2.start()
    except Exception as e:
        try: client.close()
        except: pass

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(("127.0.0.1", src_port))
server.listen(100)

while True:
    try:
        client, _ = server.accept()
        threading.Thread(target=handle, args=(client,), daemon=True).start()
    except Exception:
        break
EOF

# Delegate to original WSO2 entrypoint
exec /home/wso2carbon/docker-entrypoint.sh "$@"
