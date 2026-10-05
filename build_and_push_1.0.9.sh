#!/usr/bin/env bash
# ==============================================================================
# Script Otomatis: Build & Push Container Registry ASSA Middleware Versi 1.0.9
# Menyertakan:
#   - Build & Package CAR Artifacts WSO2 MI terbaru (clean packaging)
#   - Build clean & optimal langsung dari base image wso2/wso2mi:4.6.0 (tanpa layer bloat)
#   - Flag --platform linux/amd64 (kompatibilitas server Linux)
#   - Flag --provenance=false --sbom=false (mencegah error 'invalid tag' GitLab)
# ==============================================================================
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WSO2_DIR="$ROOT_DIR/middleware-assa/wso2-mi-monorepo"
TAG="${1:-1.0.9}"
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
echo " [2/3] Building Optimized Docker Image: ${IMAGE_NAME}"
echo "       Base: wso2/wso2mi:4.6.0 (Clean build, zero layer duplication)"
echo "       Flag: --platform linux/amd64 --provenance=false --sbom=false"
echo "=========================================================="
docker buildx build \
  --platform linux/amd64 \
  --provenance=false \
  --sbom=false \
  -t "${IMAGE_NAME}" \
  -f - --load . <<EOF
FROM wso2/wso2mi:4.6.0
USER root
COPY --chown=wso2carbon:wso2 platform/docker/resources/*.jks /home/wso2carbon/wso2mi-4.6.0/repository/resources/security/
COPY --chown=wso2carbon:wso2 integrations/branch-service/deployment/docker/libs/mariadb-java-client-*.jar /home/wso2carbon/wso2mi-4.6.0/lib/
COPY --chown=wso2carbon:wso2 --chmod=755 platform/docker/entrypoint.sh /home/wso2carbon/entrypoint.sh
COPY --chown=wso2carbon:wso2 scripts/db/init_mariadb_schema.sql /docker-entrypoint-initdb.d/01_init.sql
COPY --chown=wso2carbon:wso2 docs /app/docs
COPY --chown=wso2carbon:wso2 dist-cars/*.car /home/wso2carbon/wso2mi-4.6.0/repository/deployment/server/carbonapps/
USER wso2carbon
EXPOSE 8290 8253 9164
ENTRYPOINT ["/home/wso2carbon/entrypoint.sh"]
EOF

echo ""
echo "=========================================================="
echo " SUCCESS! Image ${TAG} berhasil dibuild:"
echo "   ${IMAGE_NAME}"
echo "=========================================================="
echo ""
echo "Untuk push ke GitLab Container Registry ASSA, jalankan:"
echo "   docker push ${IMAGE_NAME}"
echo ""
echo "Langkah Deploy di Server (/var/www/devmiddleware):"
echo " 1. Pastikan .env di server menggunakan tag ${TAG}:"
echo "      MI_IMAGE=${IMAGE_NAME}"
echo " 2. Restart container dengan image baru:"
echo "      docker compose down"
echo "      docker compose pull"
echo "      docker compose up -d"
echo "=========================================================="
