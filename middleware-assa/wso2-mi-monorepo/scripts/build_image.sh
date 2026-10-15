#!/usr/bin/env bash
# ==============================================================================
# Script Otomatis Build & Push Image Release ASSA Middleware (WSO2 MI Monorepo)
# Menyertakan:
#   --platform linux/amd64 (Kompatibilitas Server Linux dari macOS M-Series)
#   --provenance=false --sbom=false (Mencegah error 'Invalid tag' di GitLab Registry)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONO_DIR="$(dirname "$SCRIPT_DIR")"
cd "$MONO_DIR"

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <image-tag>" >&2
  exit 1
fi
TAG="$1"
IMAGE_NAME="registry.assa.id/nobi.sumariga/middleware-assa:${TAG}"

echo "=========================================================="
echo " [1/2] Packaging WSO2 CAR Artifacts..."
echo "=========================================================="
if command -v mvn &> /dev/null; then
  mvn -q clean package -DskipTests
fi
python3 scripts/package_cars.py

echo ""
echo "=========================================================="
echo " [2/2] Building Docker Image: ${IMAGE_NAME}"
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
echo " SUCCESS! Image berhasil dibuat:"
echo "   ${IMAGE_NAME}"
echo ""
echo " Untuk push ke GitLab Registry ASSA:"
echo "   docker push ${IMAGE_NAME}"
echo "=========================================================="
