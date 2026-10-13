#!/bin/bash
set -e

# Keep the application-facing database address stable across environments.
TARGET_HOST="${DB_HOST:-host.docker.internal}"
TARGET_PORT="${DB_PORT:-3307}"

echo "[ENTRYPOINT] Starting DB forwarder: 127.0.0.1:3307 -> ${TARGET_HOST}:${TARGET_PORT}..."
python3 - << 'PYTHON' &
import os
import socket
import threading

source_port = 3307
target_host = os.environ.get("DB_HOST", "host.docker.internal")
target_port = int(os.environ.get("DB_PORT", "3307"))

def forward(source, target):
    try:
        while True:
            data = source.recv(4096)
            if not data:
                break
            target.sendall(data)
    except Exception:
        pass
    finally:
        source.close()
        target.close()

def handle(client):
    try:
        server = socket.create_connection((target_host, target_port), timeout=10)
        threading.Thread(target=forward, args=(client, server), daemon=True).start()
        threading.Thread(target=forward, args=(server, client), daemon=True).start()
    except Exception:
        client.close()

listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
listener.bind(("127.0.0.1", source_port))
listener.listen(100)

while True:
    client, _ = listener.accept()
    threading.Thread(target=handle, args=(client,), daemon=True).start()
PYTHON

exec /home/wso2carbon/docker-entrypoint.sh "$@"
