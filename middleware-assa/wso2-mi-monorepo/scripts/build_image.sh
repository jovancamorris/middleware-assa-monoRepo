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

TAG="${1:-1.0.7}"
IMAGE_NAME="registry.assa.id/nobi.sumariga/middleware-assa:${TAG}"

echo "=========================================================="
echo " [1/2] Packaging WSO2 CAR Artifacts..."
echo "=========================================================="
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
FROM registry.assa.id/nobi.sumariga/middleware-assa:1.0.6
USER root
COPY dist-cars/shared-artifacts_1.0.0.car /home/wso2carbon/wso2mi/repository/deployment/server/carbonapps/
COPY dist-cars/service-request-service_1.0.0.car /home/wso2carbon/wso2mi/repository/deployment/server/carbonapps/
COPY docs /app/docs
USER wso2carbon
EOF

echo ""
echo "=========================================================="
echo " SUCCESS! Image berhasil dibuat:"
echo "   ${IMAGE_NAME}"
echo ""
echo " Untuk push ke GitLab Registry ASSA:"
echo "   docker push ${IMAGE_NAME}"
echo "=========================================================="
