#!/bin/bash
set -euo pipefail

APIM_HOST="https://localhost:9443"
BACKEND_URL="http://middleware-wso2-api:8290"
DOCS_DIR="/Users/jovan-eksad/assa/middleware-assa-monoRepo/middleware-assa/wso2-mi-monorepo/docs/openapi"

echo "=== 1. Register Client via DCR ==="
DCR_RESP=$(curl -k -s -X POST "$APIM_HOST/client-registration/v0.17/register" \
  -u admin:admin \
  -H 'Content-Type: application/json' \
  -d '{
    "clientName": "auto_api_importer",
    "owner": "admin",
    "grantType": "password refresh_token",
    "saasApp": true
  }')

CLIENT_ID=$(echo "$DCR_RESP" | grep -o '"clientId":"[^"]*' | cut -d'"' -f4)
CLIENT_SECRET=$(echo "$DCR_RESP" | grep -o '"clientSecret":"[^"]*' | cut -d'"' -f4)

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
  echo "Error registering client: $DCR_RESP"
  exit 1
fi
echo "Client registered: $CLIENT_ID"

echo "=== 2. Generate Access Token ==="
TOKEN_RESP=$(curl -k -s -X POST "$APIM_HOST/oauth2/token" \
  -u "$CLIENT_ID:$CLIENT_SECRET" \
  -d "grant_type=password&username=admin&password=admin&scope=apim:api_create apim:api_publish apim:api_view apim:api_manage")

TOKEN=$(echo "$TOKEN_RESP" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)
if [ -z "$TOKEN" ]; then
  echo "Error getting token: $TOKEN_RESP"
  exit 1
fi
echo "Access token obtained successfully."

import_api() {
  local name="$1"
  local context="$2"
  local file="$3"

  echo "----------------------------------------"
  echo "Importing $name (Context: $context)..."

  # Check if already exists
  EXISTING_ID=$(curl -k -s -X GET "$APIM_HOST/api/am/publisher/v4/apis?query=name:$name" \
    -H "Authorization: Bearer $TOKEN" | grep -o '"id":"[^"]*' | head -n 1 | cut -d'"' -f4 || true)

  if [ -n "$EXISTING_ID" ]; then
    echo "API $name already exists with ID: $EXISTING_ID. Skipping creation."
    API_ID="$EXISTING_ID"
  else
    ADDITIONAL_PROPS=$(cat <<EOF
{
  "name": "$name",
  "context": "$context",
  "version": "1.0.0",
  "endpointConfig": {
    "endpoint_type": "http",
    "sandbox_endpoints": {"url": "$BACKEND_URL"},
    "production_endpoints": {"url": "$BACKEND_URL"}
  },
  "policies": ["Unlimited"]
}
EOF
)

    RESP=$(curl -k -s -X POST "$APIM_HOST/api/am/publisher/v4/apis/import-openapi" \
      -H "Authorization: Bearer $TOKEN" \
      -F "file=@$file" \
      -F "additionalProperties=$ADDITIONAL_PROPS")

    API_ID=$(echo "$RESP" | grep -o '"id":"[^"]*' | head -n 1 | cut -d'"' -f4 || true)
    if [ -z "$API_ID" ]; then
      echo "Failed to create API $name. Response: $RESP"
      return 1
    fi
    echo "Created API $name with ID: $API_ID"
  fi

  # Deploy revision
  REV=$(curl -k -s -X POST "$APIM_HOST/api/am/publisher/v4/apis/$API_ID/revisions" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"description":"Initial Auto Revision"}' | grep -o '"id":"[^"]*' | head -n 1 | cut -d'"' -f4 || true)

  if [ -n "$REV" ]; then
    curl -k -s -X POST "$APIM_HOST/api/am/publisher/v4/apis/$API_ID/deploy-revision?revisionId=$REV" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d '[{"name":"Default","vhost":"localhost","displayOnDevportal":true}]' > /dev/null
    echo "Deployed revision $REV to Gateway"
  fi

  # Publish API
  PUB_RESP=$(curl -k -s -X POST "$APIM_HOST/api/am/publisher/v4/apis/change-lifecycle?action=Publish&apiId=$API_ID" \
    -H "Authorization: Bearer $TOKEN")
  echo "Lifecycle published: $name"
}

import_api "BranchService" "/api/branches" "$DOCS_DIR/branch-service.yaml"
import_api "CustomerService" "/api/customers" "$DOCS_DIR/customer-service.yaml"
import_api "VehicleService" "/api/vehicles" "$DOCS_DIR/vehicle-service.yaml"
import_api "VendorService" "/api/vendors" "$DOCS_DIR/vendor-service.yaml"
import_api "SpkService" "/api/spk" "$DOCS_DIR/spk-service.yaml"
import_api "PaymentsService" "/api/payments" "$DOCS_DIR/payments-service.yaml"
import_api "ServiceRequestService" "/api/service-requests" "$DOCS_DIR/service-request-service.yaml"

echo "========================================"
echo "All APIs imported and published successfully!"
