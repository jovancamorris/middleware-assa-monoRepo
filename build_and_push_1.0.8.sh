#!/usr/bin/env bash
# ==============================================================================
# Script Otomatis: Build & Push Container Registry ASSA Middleware Versi 1.0.8
# Menyertakan:
#   - Build & Package CAR Artifacts WSO2 MI terbaru
#   - Flag --platform linux/amd64 (kompatibilitas server Linux)
#   - Flag --provenance=false --sbom=false (mencegah error 'invalid tag' GitLab)
#   - Push otomatis ke registry.assa.id
# ==============================================================================
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WSO2_DIR="$ROOT_DIR/middleware-assa/wso2-mi-monorepo"
TAG="1.0.8"
IMAGE_NAME="registry.assa.id/nobi.sumariga/middleware-assa:${TAG}"

echo "=========================================================="
echo " [1/3] Packaging WSO2 CAR Artifacts & Building Docs (TS)..."
echo "=========================================================="
cd "$WSO2_DIR"
python3 scripts/package_cars.py

if [ -d "$WSO2_DIR/docs-src" ]; then
  echo " --> Compiling Swagger UI from TypeScript (docs-src)..."
  (cd "$WSO2_DIR/docs-src" && npm run build)
fi

echo ""
echo "=========================================================="
echo " [2/3] Building Docker Image: ${IMAGE_NAME}"
echo "       Flag: --platform linux/amd64 --provenance=false --sbom=false"
echo "=========================================================="
docker buildx build \
  --platform linux/amd64 \
  --provenance=false \
  --sbom=false \
  -t "${IMAGE_NAME}" \
  -f - --load . <<EOF
FROM registry.assa.id/nobi.sumariga/middleware-assa:1.0.8
USER root
COPY dist-cars/*.car /home/wso2carbon/wso2mi-4.6.0/repository/deployment/server/carbonapps/
COPY docs /app/docs
COPY scripts/db/init_mariadb_schema.sql /docker-entrypoint-initdb.d/01_init.sql
RUN chown -R wso2carbon:wso2 /home/wso2carbon/wso2mi-4.6.0/repository/deployment/server/carbonapps/ /app/docs
USER wso2carbon
EOF

echo ""
echo "=========================================================="
echo " [3/3] Pushing Image ke GitLab Container Registry ASSA..."
echo "       Target: ${IMAGE_NAME}"
echo "=========================================================="
docker push "${IMAGE_NAME}"

echo ""
echo "=========================================================="
echo " SUCCESS! Image 1.0.8 berhasil dibuild & dipush ke registry:"
echo "   ${IMAGE_NAME}"
echo "=========================================================="
echo ""
echo "Langkah Deploy di Server (/var/www/devmiddleware):"
echo " 1. Pastikan .env di server menggunakan tag 1.0.8:"
echo "      MI_IMAGE=${IMAGE_NAME}"
echo " 2. Restart container dengan image baru:"
echo "      docker compose down"
echo "      docker compose pull"
echo "      docker compose up -d"
echo "=========================================================="
