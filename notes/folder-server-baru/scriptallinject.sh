#!/bin/bash
# ==============================================================================
# scriptallinject.sh - All-in-One APIM Importer & Reusable Policy Injector
# ==============================================================================
# 1. Mendaftarkan Reusable Operation Policies ASSA ke WSO2 APIM Publisher
#    (Muncul di Palette Publisher UI siap untuk di-DRAG & DROP).
# 2. Mengimpor 7 Domain Services dari OpenAPI Specification.
# 3. Menginjeksi Policy (Correlation ID, Auth, Log, Fault Error Handler) & Scope.
# 4. Mendeploy Revision ke Gateway (VHost) dan mempublish API.
# ==============================================================================
set -euo pipefail
cd "$(dirname "$0")"
[ -f .env ] && { set -a; . ./.env; set +a; }

RESET_MODE="${RESET_APIS:-false}"
for arg in "${@:-}"; do
  if [ "$arg" = "--reset" ] || [ "$arg" = "-r" ]; then
    RESET_MODE="true"
  fi
done

APIM_HOST="${APIM_HOST:-https://localhost:9443}"
ADMIN_U="${APIM_ADMIN_USERNAME:-admindev}"
ADMIN_P="${APIM_ADMIN_PASSWORD:-4554r3nt*2023}"
BACKEND_URL="${BACKEND_URL:-http://middleware-wso2-api:8290}"
VHOST="${APIM_VHOST:-devmiddleware.assa.id}"
DOCS_DIR="${DOCS_DIR:-/tmp/assa-openapi-docs}"
NGINX_DOCS_URL="${NGINX_DOCS_URL:-http://localhost:6030/docs/openapi}"
POLICIES_DIR="${POLICIES_DIR:-./policies}"

# Default token sent to WSO2 MI AuthGuardSeq
BACKEND_TOKEN="${BACKEND_TOKEN:-${AUTH_APP_QA_TOKEN:-ik4lcTGsZx1hARMWOoy613tAkI7Mcj7q1g7PRq3d}}"

# Service definitions: Name | Context | OpenAPI Spec | Scope
SERVICES=(
  "BranchService|/api/branches|branch-service.yaml|branches"
  "CustomerService|/api/customers|customer-service.yaml|customers"
  "VehicleService|/api/vehicles|vehicle-service.yaml|vehicles"
  "VendorService|/api/vendors|vendor-service.yaml|vendors"
  "SpkService|/api/spk|spk-service.yaml|spk"
  "PaymentsService|/api/payments|payments-service.yaml|payments"
  "ServiceRequestService|/api/service-requests|service-request-service.yaml|service_requests"
  "AuthService|/api/auth|auth-service.yaml|auth"
)

# ------------------------------------------------------------------------------
# 1. OpenAPI Specs Discovery (Prioritaskan file lokal docs/openapi jika ada)
# ------------------------------------------------------------------------------
mkdir -p "$DOCS_DIR"
for s in "${SERVICES[@]}"; do
  IFS='|' read -r _ _ f _ <<< "$s"
  if [ -f "./docs/openapi/$f" ]; then
    cp -f "./docs/openapi/$f" "$DOCS_DIR/$f"
  else
    curl -s -f "$NGINX_DOCS_URL/$f" -o "$DOCS_DIR/$f" || true
  fi
done

# ------------------------------------------------------------------------------
# 2. Self-Bootstrap Policy Templates jika folder lokal belum lengkap
# ------------------------------------------------------------------------------
if [ ! -d "$POLICIES_DIR/assaBackendAuth" ]; then
  POLICIES_DIR="/tmp/assa-policies"
  mkdir -p "$POLICIES_DIR/assaBackendAuth" "$POLICIES_DIR/assaCorrelationId" "$POLICIES_DIR/assaErrorResponse" "$POLICIES_DIR/assaLogRequest"

  cat << 'EOF' > "$POLICIES_DIR/assaBackendAuth/policy.json"
{"category":"Security","name":"assaBackendAuth","displayName":"ASSA Backend Auth Injection","version":"v1","description":"Injects Authorization (Bearer) and X-API-Key backend credentials into request flow for WSO2 MI AuthGuardSeq","applicableFlows":["request"],"supportedGateways":["Synapse"],"supportedApiTypes":["HTTP"],"policyAttributes":[{"name":"backendToken","displayName":"Backend Access Token","description":"Token sent to Micro Integrator AuthGuardSeq","type":"String","required":true}]}
EOF
  cat << 'EOF' > "$POLICIES_DIR/assaBackendAuth/policy.j2"
<header name="Authorization" value="Bearer {{ backendToken }}" scope="transport"/>
<header name="X-API-Key" value="{{ backendToken }}" scope="transport"/>
EOF

  cat << 'EOF' > "$POLICIES_DIR/assaCorrelationId/policy.json"
{"category":"Mediation","name":"assaCorrelationId","displayName":"ASSA Correlation ID Tracker","version":"v1","description":"Checks or generates X-Correlation-Id header in request flow and echoes in response flow","applicableFlows":["request","response"],"supportedGateways":["Synapse"],"supportedApiTypes":["HTTP"],"policyAttributes":[]}
EOF
  cat << 'EOF' > "$POLICIES_DIR/assaCorrelationId/policy.j2"
<property name="assa_corr_id" expression="$trp:X-Correlation-Id" scope="default" type="STRING"/>
<filter xpath="string-length($ctx:assa_corr_id) = 0">
    <then>
        <property name="assa_corr_id" expression="fn:concat('corr-', get-property('SYSTEM_DATE', 'yyyyMMddHHmmssSSS'))" scope="default" type="STRING"/>
    </then>
</filter>
<header name="X-Correlation-Id" expression="$ctx:assa_corr_id" scope="transport"/>
EOF

  cat << 'EOF' > "$POLICIES_DIR/assaErrorResponse/policy.json"
{"category":"Mediation","name":"assaErrorResponse","displayName":"ASSA Standard Error Response","version":"v1","description":"Standardizes APIM Gateway error responses into ASSA JSON error format matching ErrorResponseSeq","applicableFlows":["fault"],"supportedGateways":["Synapse"],"supportedApiTypes":["HTTP"],"policyAttributes":[]}
EOF
  cat << 'EOF' > "$POLICIES_DIR/assaErrorResponse/policy.j2"
<property name="messageType" value="application/json" scope="axis2"/>
<property name="ContentType" value="application/json" scope="axis2"/>
<payloadFactory media-type="json">
    <format>{"error": true, "message": "$1", "detail": "$2"}</format>
    <args>
        <arg evaluator="xml" expression="get-property('ERROR_MESSAGE')"/>
        <arg evaluator="xml" expression="get-property('ERROR_DETAIL')"/>
    </args>
</payloadFactory>
<property name="assa_corr_id" expression="$trp:X-Correlation-Id" scope="default" type="STRING"/>
<filter xpath="string-length($ctx:assa_corr_id) &gt; 0">
    <then><header name="X-Correlation-Id" expression="$ctx:assa_corr_id" scope="transport"/></then>
</filter>
<respond/>
EOF

  cat << 'EOF' > "$POLICIES_DIR/assaLogRequest/policy.json"
{"category":"Mediation","name":"assaLogRequest","displayName":"ASSA Request Access Log","version":"v1","description":"Structured JSON logging for incoming API requests in Gateway matching LogRequestSeq","applicableFlows":["request"],"supportedGateways":["Synapse"],"supportedApiTypes":["HTTP"],"policyAttributes":[]}
EOF
  cat << 'EOF' > "$POLICIES_DIR/assaLogRequest/policy.j2"
<property name="logTimestamp" expression="fn:concat(get-property('SYSTEM_DATE', 'yyyy-MM-dd'), 'T', get-property('SYSTEM_DATE', 'HH:mm:ss'))" scope="default" type="STRING"/>
<log level="custom">
    <property name="structured_log" expression="fn:concat('{ &quot;timestamp&quot;: &quot;', get-property('logTimestamp'), '&quot;, &quot;correlationId&quot;: &quot;', get-property('default', 'assa_corr_id'), '&quot;, &quot;endpoint&quot;: &quot;', get-property('To'), '&quot;, &quot;method&quot;: &quot;', get-property('axis2', 'HTTP_METHOD'), '&quot; }')"/>
</log>
EOF
fi

# ------------------------------------------------------------------------------
# 3. Dynamic Client Registration & OAuth Token
# ------------------------------------------------------------------------------
echo "==> Autentikasi ke WSO2 APIM Publisher..."
DCR=$(curl -k -s -X POST "$APIM_HOST/client-registration/v0.17/register" \
  -u "$ADMIN_U:$ADMIN_P" -H 'Content-Type: application/json' \
  -d '{"clientName":"auto_api_importer","owner":"'"$ADMIN_U"'","grantType":"password refresh_token","saasApp":true}')
CID=$(echo "$DCR" | grep -o '"clientId":"[^"]*' | cut -d'"' -f4 || true)
CSECRET=$(echo "$DCR" | grep -o '"clientSecret":"[^"]*' | cut -d'"' -f4 || true)
[ -n "${CID:-}" ] && [ -n "${CSECRET:-}" ] || { echo "DCR failed: $DCR"; exit 1; }

TOKEN=$(curl -k -s -X POST "$APIM_HOST/oauth2/token" \
  -u "$CID:$CSECRET" \
  -d "grant_type=password&username=$ADMIN_U&password=$ADMIN_P&scope=apim:api_create apim:api_publish apim:api_view apim:api_manage apim:common_operation_policy_manage apim:common_operation_policy_view apim:api_import_export" \
  | grep -o '"access_token":"[^"]*' | cut -d'"' -f4 || true)
[ -n "${TOKEN:-}" ] || { echo "Token generation failed"; exit 1; }
echo "[OK] Token diperoleh."

# ------------------------------------------------------------------------------
# 4. Registrasi Custom Common Operation Policies ke APIM (Palette Drag & Drop)
# ------------------------------------------------------------------------------
echo "==> Mendaftarkan Reusable Policies ke Palette APIM Publisher..."
EXISTING_POLICIES=$(curl -k -s "$APIM_HOST/api/am/publisher/v4/operation-policies?limit=100" -H "Authorization: Bearer $TOKEN")

get_policy_id() {
  local pname="$1"
  echo "$EXISTING_POLICIES" | python3 -c "import json,sys; print(next((p['id'] for p in json.load(sys.stdin).get('list',[]) if p.get('name')=='$pname'),''))" 2>/dev/null || true
}

register_policy() {
  local pname="$1"
  local pid
  pid=$(get_policy_id "$pname")
  if [ -n "$pid" ]; then
    echo "  [FOUND]      $pname ($pid)" >&2
    echo "$pid"
    return 0
  fi
  local pdir="$POLICIES_DIR/$pname"
  if [ -f "$pdir/policy.json" ] && [ -f "$pdir/policy.j2" ]; then
    local resp
    resp=$(curl -k -s -X POST "$APIM_HOST/api/am/publisher/v4/operation-policies" \
      -H "Authorization: Bearer $TOKEN" \
      -F "policySpecFile=@$pdir/policy.json;type=application/json" \
      -F "synapsePolicyDefinitionFile=@$pdir/policy.j2")
    pid=$(echo "$resp" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || true)
    if [ -n "$pid" ]; then
      echo "  [REGISTERED] $pname ($pid)" >&2
      echo "$pid"
      return 0
    else
      echo "  [WARN] Gagal mendaftarkan $pname: $resp" >&2
    fi
  fi
  echo ""
}

PID_AUTH=$(register_policy "assaBackendAuth")
PID_CORR=$(register_policy "assaCorrelationId")
PID_ERR=$(register_policy "assaErrorResponse")
PID_LOG=$(register_policy "assaLogRequest")
PID_ADDHEADER=$(get_policy_id "addHeader")

# Ekspor JSON peta Policy ID untuk Python
POLICY_IDS_JSON=$(PID_AUTH="$PID_AUTH" PID_CORR="$PID_CORR" PID_ERR="$PID_ERR" PID_LOG="$PID_LOG" PID_ADDHEADER="$PID_ADDHEADER" python3 -c '
import json, os
m = {}
for k, env in [("assaBackendAuth", "PID_AUTH"), ("assaCorrelationId", "PID_CORR"), ("assaErrorResponse", "PID_ERR"), ("assaLogRequest", "PID_LOG"), ("addHeader", "PID_ADDHEADER")]:
    v = os.environ.get(env, "").strip()
    if v:
        m[k] = v
print(json.dumps(m))
')

# ------------------------------------------------------------------------------
# 5. Helper Patch Operations (Policy Injection + Scopes)
# ------------------------------------------------------------------------------
patch_ops() {
  local target_scope="$1"
  POLICY_IDS_JSON="$POLICY_IDS_JSON" BACKEND_TOKEN="$BACKEND_TOKEN" TARGET_SCOPE="$target_scope" python3 -c '
import json, sys, os

pids = json.loads(os.environ.get("POLICY_IDS_JSON", "{}"))
tok = os.environ.get("BACKEND_TOKEN", "")
scope = os.environ.get("TARGET_SCOPE", "")
d = json.load(sys.stdin)

# Siapkan list policy untuk masing-masing flow
req_policies = []
resp_policies = []
fault_policies = []

# 1. Request Flow: Correlation ID
if "assaCorrelationId" in pids:
    req_policies.append({
        "policyName": "assaCorrelationId",
        "policyVersion": "v1",
        "policyId": pids["assaCorrelationId"],
        "parameters": {}
    })
    resp_policies.append({
        "policyName": "assaCorrelationId",
        "policyVersion": "v1",
        "policyId": pids["assaCorrelationId"],
        "parameters": {}
    })

# 2. Request Flow: Structured Request Log
if "assaLogRequest" in pids:
    req_policies.append({
        "policyName": "assaLogRequest",
        "policyVersion": "v1",
        "policyId": pids["assaLogRequest"],
        "parameters": {}
    })

# 3. Request Flow: Backend Auth Injection (Custom policy atau fallback addHeader)
if "assaBackendAuth" in pids:
    req_policies.append({
        "policyName": "assaBackendAuth",
        "policyVersion": "v1",
        "policyId": pids["assaBackendAuth"],
        "parameters": {"backendToken": tok}
    })
elif "addHeader" in pids:
    for h in ("Authorization", "X-API-Key"):
        val = f"Bearer {tok}" if h == "Authorization" else tok
        req_policies.append({
            "policyName": "addHeader",
            "policyVersion": "v2",
            "policyId": pids["addHeader"],
            "parameters": {"headerName": h, "headerValue": val}
        })

# 4. Fault Flow: Standard Error Response
if "assaErrorResponse" in pids:
    fault_policies.append({
        "policyName": "assaErrorResponse",
        "policyVersion": "v1",
        "policyId": pids["assaErrorResponse"],
        "parameters": {}
    })

# Terapkan ke semua operations
for op in d.get("operations", []):
    if scope:
        op["scopes"] = [scope]
    op["operationPolicies"] = {
        "request": req_policies,
        "response": resp_policies,
        "fault": fault_policies
    }

print(json.dumps(d))
'
}

# ------------------------------------------------------------------------------
# 6. Import API, Pasang Policy, Buat Revisi & Publish
# ------------------------------------------------------------------------------
import_api() {
  local name="$1" ctx="$2" file="$3" scope="$4" id="" rev=""
  echo "------------------------------------------------------------"
  echo "--> Service: $name (Context: $ctx, Scope: $scope)"

  local apis_resp
  apis_resp=$(curl -k -s "$APIM_HOST/api/am/publisher/v4/apis?query=name:$name" -H "Authorization: Bearer $TOKEN" || echo "{}")
  id=$(echo "$apis_resp" | python3 -c "import json,sys; l=json.load(sys.stdin).get('list',[]); print(l[0].get('id','') if l else '')" 2>/dev/null || true)

  if [ "${RESET_MODE:-false}" = "true" ] && [ -n "$id" ]; then
    echo "  [RESET]   Menghapus API lama ($id)..."
    curl -k -s -X DELETE "$APIM_HOST/api/am/publisher/v4/apis/$id" -H "Authorization: Bearer $TOKEN" > /dev/null || true
    id=""
  fi

  if [ -z "$id" ]; then
    local create_resp
    create_resp=$(curl -k -s -X POST "$APIM_HOST/api/am/publisher/v4/apis/import-openapi" \
      -H "Authorization: Bearer $TOKEN" \
      -F "file=@$file" \
      -F "additionalProperties={\"name\":\"$name\",\"context\":\"$ctx\",\"version\":\"1.0.0\",\"endpointConfig\":{\"endpoint_type\":\"http\",\"sandbox_endpoints\":{\"url\":\"$BACKEND_URL\"},\"production_endpoints\":{\"url\":\"$BACKEND_URL\"}},\"policies\":[\"Unlimited\"]}" || echo "{}")
    id=$(echo "$create_resp" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || true)
    [ -n "$id" ] || { echo "FAIL create $name: $create_resp"; return 1; }
    echo "  [CREATED] API ID: $id"
  else
    echo "  [EXISTS]  API ID: $id"
    # Update Swagger / OpenAPI definition agar endpoint baru (seperti /getByCreateDate) tersinkronisasi
    curl -k -s -X PUT "$APIM_HOST/api/am/publisher/v4/apis/$id/swagger" \
      -H "Authorization: Bearer $TOKEN" \
      -F "apiDefinition=@$file" > /dev/null || true
    echo "  [SYNC]    OpenAPI definition synced dari $(basename "$file")"
  fi

  # Injeksi policy ke API definition
  curl -k -s "$APIM_HOST/api/am/publisher/v4/apis/$id" -H "Authorization: Bearer $TOKEN" \
    | patch_ops "$scope" \
    | curl -k -s -X PUT "$APIM_HOST/api/am/publisher/v4/apis/$id" \
        -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d @- > /dev/null
  echo "  [POLICY]  Operation policies injected (Request, Response, Fault)"

  # Hapus revisi terlama jika mencapai batas kuota (5 revisi)
  local rev_list
  rev_list=$(curl -k -s "$APIM_HOST/api/am/publisher/v4/apis/$id/revisions" -H "Authorization: Bearer $TOKEN" || echo "{}")
  local n
  n=$(echo "$rev_list" | python3 -c "import json,sys; print(json.load(sys.stdin).get('count', 0))" 2>/dev/null || echo "0")
  if [ "${n:-0}" -ge 5 ]; then
    local old
    old=$(echo "$rev_list" | python3 -c "import json,sys; print(json.load(sys.stdin).get('list',[{}])[0].get('id',''))" 2>/dev/null || true)
    if [ -n "$old" ]; then
      curl -k -s -X DELETE "$APIM_HOST/api/am/publisher/v4/apis/$id/revisions/$old" -H "Authorization: Bearer $TOKEN" > /dev/null || true
    fi
  fi

  # Buat revisi baru & deploy ke gateway
  local rev_resp
  rev_resp=$(curl -k -s -X POST "$APIM_HOST/api/am/publisher/v4/apis/$id/revisions" \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
    -d '{"description":"ASSA Reusable Policies Auto-Injected"}' || echo "{}")
  rev=$(echo "$rev_resp" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || true)
  if [ -n "$rev" ]; then
    curl -k -s -X POST "$APIM_HOST/api/am/publisher/v4/apis/$id/deploy-revision?revisionId=$rev" \
      -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
      -d "[{\"name\":\"Default\",\"vhost\":\"$VHOST\",\"displayOnDevportal\":true}]" > /dev/null || true
    echo "  [DEPLOY]  Revision $rev active on $VHOST"
  fi

  # Publish API
  curl -k -s -X POST "$APIM_HOST/api/am/publisher/v4/apis/change-lifecycle?action=Publish&apiId=$id" \
    -H "Authorization: Bearer $TOKEN" > /dev/null || true
  echo "  [PUBLISH] $name published to DevPortal"
}

# Jalankan loop import untuk semua service
for s in "${SERVICES[@]}"; do
  IFS='|' read -r n c f sc <<< "$s"
  import_api "$n" "$c" "$DOCS_DIR/$f" "$sc"
done

echo "============================================================"
echo "SUCCESS: Seluruh ${#SERVICES[@]} Service berhasil dipublish ke APIM!"
echo "Policies yang terdaftar di Palette Publisher (Drag & Drop):"
echo "  1. assaBackendAuth    : ${PID_AUTH:-fallback to addHeader}"
echo "  2. assaCorrelationId  : ${PID_CORR:-none}"
echo "  3. assaErrorResponse  : ${PID_ERR:-none}"
echo "  4. assaLogRequest     : ${PID_LOG:-none}"
echo "Backend Token: ${BACKEND_TOKEN:0:6}...${BACKEND_TOKEN: -6}"
echo "Portal Publisher: $APIM_HOST/publisher"
echo "============================================================"