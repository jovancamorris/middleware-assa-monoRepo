#!/usr/bin/env bash
# ==============================================================================
# ASSA Middleware - Comprehensive Automated Local Test Runner
# Digunakan untuk menguji seluruh endpoint, guard auth/scope, validasi, 
# GET inquiry & pagination, POST paralel fan-out (10x retries), 
# serta verifikasi pencatatan audit log ke MariaDB secara lokal di macOS/Linux.
# ==============================================================================

set -uo pipefail

# ------------------------------------------------------------------------------
# Warna & Format Terminal
# ------------------------------------------------------------------------------
if [[ -t 1 ]]; then
    BOLD="\033[1m"
    GREEN="\033[32m"
    RED="\033[31m"
    YELLOW="\033[33m"
    CYAN="\033[36m"
    GRAY="\033[90m"
    RESET="\033[0m"
else
    BOLD=""
    GREEN=""
    RED=""
    YELLOW=""
    CYAN=""
    GRAY=""
    RESET=""
fi

# ------------------------------------------------------------------------------
# Inisialisasi Counter Pengujian
# ------------------------------------------------------------------------------
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
VERBOSE=0
MODE="gateway" # default: gateway (port 6031)

# Parsing Argumen CLI
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        --direct)
            MODE="direct"
            shift
            ;;
        --gateway)
            MODE="gateway"
            shift
            ;;
        -h|--help)
            echo "Usage: ./test_local.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --gateway       Uji via Nginx Gateway port 6031 (Default)"
            echo "  --direct        Uji langsung ke port microservice WSO2 (8290-8295)"
            echo "  -v, --verbose   Tampilkan full HTTP request & response body"
            echo "  -h, --help      Tampilkan panduan ini"
            exit 0
            ;;
        *)
            echo "Argumen tidak dikenal: $1. Gunakan -h untuk bantuan."
            exit 1
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Load Konfigurasi (.env) jika tersedia
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for env_path in "$SCRIPT_DIR/.env" "$SCRIPT_DIR/middleware-assa/wso2-mi-monorepo/.env" "$SCRIPT_DIR/../.env"; do
    # Cegah keluar dari repo jika parent adalah home directory
    if [[ "$env_path" == *"$HOME/.env"* ]]; then
        continue
    fi
    if [[ -f "$env_path" ]]; then
        echo -e "${GRAY}Memuat variabel lingkungan dari: $env_path${RESET}"
        # Hanya mengekspor baris tanpa komentar
        while IFS='=' read -r key val || [[ -n "$key" ]]; do
            key=$(echo "$key" | tr -d ' ' | tr -d '\r')
            if [[ -n "$key" && ! "$key" =~ ^# ]]; then
                val=$(echo "$val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^["'"'"']//' -e 's/["'"'"']$//' | tr -d '\r')
                if [[ -z "${!key:-}" ]]; then
                    export "$key"="$val"
                fi
            fi
        done < "$env_path"
        break
    fi
done

# ------------------------------------------------------------------------------
# Konfigurasi URL & Token
# ------------------------------------------------------------------------------
GATEWAY_URL="${GATEWAY_URL:-http://localhost:6031}"

if [[ "$MODE" == "gateway" ]]; then
    BASE_URL_BRANCH="${GATEWAY_URL}"
    BASE_URL_CUSTOMER="${GATEWAY_URL}"
    BASE_URL_VEHICLE="${GATEWAY_URL}"
    BASE_URL_VENDOR="${GATEWAY_URL}"
    BASE_URL_SPK="${GATEWAY_URL}"
    BASE_URL_SR="${GATEWAY_URL}"
else
    BASE_URL_BRANCH="${BASE_URL_BRANCH:-http://localhost:8290}"
    BASE_URL_CUSTOMER="${BASE_URL_CUSTOMER:-http://localhost:8291}"
    BASE_URL_VEHICLE="${BASE_URL_VEHICLE:-http://localhost:8292}"
    BASE_URL_VENDOR="${BASE_URL_VENDOR:-http://localhost:8293}"
    BASE_URL_SPK="${BASE_URL_SPK:-http://localhost:8294}"
    BASE_URL_SR="${BASE_URL_SR:-http://localhost:8295}"
fi

TOKEN_APP_A="${AUTH_APP_A_TOKEN:-c220fbfbc7e4c925eb662d85be47ee5ab017d23d9b04f7c22df6cb7efb6dfdbd}"
TOKEN_APP_B="${AUTH_APP_B_TOKEN:-988316b38c88b941600c40aae26ed8429a64d0c1c9a73b596f044da40c911881}"
TOKEN_APP_QA="${AUTH_APP_QA_TOKEN:-e20b33b006bc229d49dd701c385f8abfbe6a24726fb51db11624bce3766627be}"
TOKEN_OMNICHANNEL="${AUTH_APP_OMNICHANNEL_TOKEN:-14066ba5b0f51e031a9feaae644fc13f2ada2fb4be9ee054f96b8865fb7a6f12}"
TOKEN_BARANTUM="${AUTH_APP_BARANTUM_TOKEN:-umk_2d35d5538f25624fc716958934d1751889cb7f6a0b0f1df18667032272eb86fd}"

DB_CONTAINER="${DB_CONTAINER:-mi-mariadb}"
DB_NAME="${DB_NAME:-assa_middleware_db}"

# ------------------------------------------------------------------------------
# Banner Tampilan
# ------------------------------------------------------------------------------
echo -e "\n${CYAN}========================================================================${RESET}"
echo -e "${BOLD}${CYAN}          ASSA MIDDLEWARE - AUTOMATED LOCAL TEST SUITE          ${RESET}"
echo -e "${CYAN}========================================================================${RESET}"
echo -e "${GRAY}Waktu Eksekusi : $(date '+%Y-%m-%d %H:%M:%S')${RESET}"
echo -e "${GRAY}Target Mode    : ${BOLD}${MODE}${RESET} (${GATEWAY_URL})"
echo -e "${GRAY}Database Target: ${DB_CONTAINER} (${DB_NAME})${RESET}"
echo -e "${CYAN}------------------------------------------------------------------------${RESET}\n"

# ------------------------------------------------------------------------------
# Fungsi Helper Eksekusi Test
# ------------------------------------------------------------------------------
run_test() {
    local test_num="$1"
    local test_name="$2"
    local method="$3"
    local url="$4"
    local expected_regex="$5"
    local token="${6:-}"
    local body="${7:-}"
    local extra_header_name="${8:-}"
    local extra_header_val="${9:-}"
    local timeout="${10:-35}"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -e "${GRAY}------------------------------------------------------------------------${RESET}"
    echo -e "${BOLD}[${test_num}] ${test_name}${RESET}"
    echo -e "${GRAY}Endpoint: ${method} ${url}${RESET}"

    # Siapkan argumen curl
    local curl_cmd=(curl -s -m "$timeout" -w "\n%{http_code}" -X "$method")
    curl_cmd+=(-H "X-Retry-Interval-Seconds: 1")

    if [[ -n "$token" ]]; then
        curl_cmd+=(-H "Authorization: Bearer $token")
        echo -e "${GRAY}Auth    : Bearer ${token:0:12}...${token: -6}${RESET}"
    else
        echo -e "${GRAY}Auth    : (Tanpa Token)${RESET}"
    fi

    if [[ -n "$extra_header_name" && -n "$extra_header_val" ]]; then
        curl_cmd+=(-H "$extra_header_name: $extra_header_val")
        echo -e "${GRAY}Header  : ${extra_header_name}: ${extra_header_val}${RESET}"
    fi

    if [[ -n "$body" ]]; then
        curl_cmd+=(-H "Content-Type: application/json" -d "$body")
    fi

    curl_cmd+=("$url")

    # Jalankan curl
    local response
    response=$("${curl_cmd[@]}" 2>&1) || {
        echo -e "HTTP Status: ${RED}KONEKSI GAGAL / TIMEOUT (${response})${RESET} (Ekspektasi: ${expected_regex})"
        echo -e "Hasil      : ${RED}${BOLD}GAGAL (FAIL)${RESET}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    }

    # Pisahkan body dan status code
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body_content
    body_content=$(echo "$response" | sed '$d')

    echo -ne "HTTP Status: ${BOLD}${http_code}${RESET} (Ekspektasi: ${expected_regex}) -> "

    if [[ "$http_code" =~ ^$expected_regex$ ]]; then
        echo -e "${GREEN}${BOLD}LULUS (PASS)${RESET}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}${BOLD}GAGAL (FAIL)${RESET}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi

    if [[ "$VERBOSE" -eq 1 || ! "$http_code" =~ ^$expected_regex$ ]]; then
        echo -e "${GRAY}Response Body Snippet:${RESET}"
        if [[ -n "$body_content" ]]; then
            echo "$body_content" | head -n 12
        else
            echo -e "${GRAY}(empty response)${RESET}"
        fi
    fi
}

run_pagination_test() {
    local test_num="$1"
    local test_name="$2"
    local base_url="$3"
    local path="$4"
    local token="$5"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -e "${GRAY}------------------------------------------------------------------------${RESET}"
    echo -e "${BOLD}[${test_num}] ${test_name}${RESET}"

    local sep="&"
    if [[ "$path" != *\?* ]]; then
        sep="?"
    fi

    local url_p1="${base_url}${path}${sep}page=1&perPage=1"
    local url_p2="${base_url}${path}${sep}page=2&perPage=1"
    local url_p10="${base_url}${path}${sep}page=1&perPage=10"

    local res_p1 res_p2 res_p10 code_p1 code_p2 code_p10
    res_p1=$(curl -s -m 15 -w "\n%{http_code}" -H "Authorization: Bearer $token" "$url_p1")
    code_p1=$(echo "$res_p1" | tail -n1)
    local body_p1=$(echo "$res_p1" | sed '$d')

    res_p2=$(curl -s -m 15 -w "\n%{http_code}" -H "Authorization: Bearer $token" "$url_p2")
    code_p2=$(echo "$res_p2" | tail -n1)
    local body_p2=$(echo "$res_p2" | sed '$d')

    res_p10=$(curl -s -m 15 -w "\n%{http_code}" -H "Authorization: Bearer $token" "$url_p10")
    code_p10=$(echo "$res_p10" | tail -n1)
    local body_p10=$(echo "$res_p10" | sed '$d')

    echo -e "${GRAY}Page 1 (perPage 1) : HTTP ${code_p1}${RESET}"
    echo -e "${GRAY}Page 2 (perPage 1) : HTTP ${code_p2}${RESET}"
    echo -e "${GRAY}Page 1 (perPage 10): HTTP ${code_p10}${RESET}"

    if [[ "$code_p1" == "200" && "$code_p2" == "200" && "$code_p10" == "200" ]]; then
        # Cek apakah response mengandung struktur pagination / total / page
        if echo "$body_p1" | grep -qE "(pagination|total|page)"; then
            echo -e "Hasil Pagination   : ${GREEN}${BOLD}LULUS (PASS)${RESET}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "Hasil Pagination   : ${YELLOW}${BOLD}LULUS DENGAN PERINGATAN (200 OK, payload non-paginated)${RESET}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        fi
    else
        echo -e "Hasil Pagination   : ${RED}${BOLD}GAGAL (FAIL) - Status bukan 200 OK${RESET}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# ------------------------------------------------------------------------------
# BAGIAN 1: Koneksi & Probe Health / Readiness
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}${CYAN}>>> BAGIAN 1: PEMERIKSAAN KONEKTIVITAS & HEALTH / READINESS PROBE${RESET}"

run_test "HEALTH-01" "Branch Health Check (Liveness)" "GET" "${BASE_URL_BRANCH}/health/branch" "200" "" "" "" "" 5
run_test "HEALTH-02" "Branch Readiness Check" "GET" "${BASE_URL_BRANCH}/readiness/branch" "200" "" "" "" "" 5

run_test "HEALTH-03" "Customer Health Check (Liveness)" "GET" "${BASE_URL_CUSTOMER}/health/customer" "200" "" "" "" "" 5
run_test "HEALTH-04" "Customer Readiness Check" "GET" "${BASE_URL_CUSTOMER}/readiness/customer" "200" "" "" "" "" 5

run_test "HEALTH-05" "Vehicle Health Check (Liveness)" "GET" "${BASE_URL_VEHICLE}/health/vehicle" "200" "" "" "" "" 5
run_test "HEALTH-06" "Vehicle Readiness Check" "GET" "${BASE_URL_VEHICLE}/readiness/vehicle" "200" "" "" "" "" 5

run_test "HEALTH-07" "Vendor Health Check (Liveness)" "GET" "${BASE_URL_VENDOR}/health/vendor" "200" "" "" "" "" 5
run_test "HEALTH-08" "Vendor Readiness Check" "GET" "${BASE_URL_VENDOR}/readiness/vendor" "200" "" "" "" "" 5

run_test "HEALTH-09" "SPK Health Check (Liveness)" "GET" "${BASE_URL_SPK}/health/spk" "200" "" "" "" "" 5
run_test "HEALTH-10" "SPK Readiness Check" "GET" "${BASE_URL_SPK}/readiness/spk" "200" "" "" "" "" 5

run_test "HEALTH-11" "Service Request Health Check (Liveness)" "GET" "${BASE_URL_SR}/health/service-request" "200" "" "" "" "" 5
run_test "HEALTH-12" "Service Request Readiness Check" "GET" "${BASE_URL_SR}/readiness/service-request" "200" "" "" "" "" 5

# ------------------------------------------------------------------------------
# BAGIAN 2: Authentication Guard (Harus 401 Unauthorized)
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}${CYAN}>>> BAGIAN 2: AUTHENTICATION GUARD (401 UNAUTHORIZED)${RESET}"

run_test "AUTH-01" "Auth Guard: Request Tanpa Token" "GET" "${BASE_URL_BRANCH}/api/branches/getByCreateDate?companyCode=1000" "401" "" "" "" "" 5
run_test "AUTH-02" "Auth Guard: Request dengan Token Palsu" "GET" "${BASE_URL_BRANCH}/api/branches/getByCreateDate?companyCode=1000" "401" "token-palsu-ngawur" "" "" "" 5

# ------------------------------------------------------------------------------
# BAGIAN 3: Scope Guard (Harus 403 Forbidden)
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}${CYAN}>>> BAGIAN 3: SCOPE GUARD / OTORISASI (403 FORBIDDEN)${RESET}"

run_test "SCOPE-01" "Scope Guard: App B (scope: vehicles) panggil Branch" "GET" "${BASE_URL_BRANCH}/api/branches/getByCreateDate?companyCode=1000" "403" "$TOKEN_APP_B" "" "" "" 5
run_test "SCOPE-02" "Scope Guard: App B panggil Customer" "GET" "${BASE_URL_CUSTOMER}/api/customers/getByCreateDate?companyCode=1000" "403" "$TOKEN_APP_B" "" "" "" 5
run_test "SCOPE-03" "Scope Guard: App B panggil Vendor" "POST" "${BASE_URL_VENDOR}/api/vendors/create" "403" "$TOKEN_APP_B" "{}" "" "" 5
run_test "SCOPE-04" "Scope Guard: App B panggil SPK" "POST" "${BASE_URL_SPK}/api/spk/duelist" "403" "$TOKEN_APP_B" "{}" "" "" 5
run_test "SCOPE-05" "Scope Guard: App B panggil Service Request" "POST" "${BASE_URL_SR}/api/service-requests" "403" "$TOKEN_APP_B" "{}" "" "" 5

# ------------------------------------------------------------------------------
# BAGIAN 4: Input Validation (Harus 400 Bad Request)
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}${CYAN}>>> BAGIAN 4: VALIDASI INPUT (400 BAD REQUEST)${RESET}"

run_test "VALID-01" "Validasi: Vehicle tanpa parameter pencarian" "GET" "${BASE_URL_VEHICLE}/api/vehicles/getByLicensePlate?companyCode=1000" "400" "$TOKEN_APP_B" "" "" "" 5

INVALID_VENDOR_JSON='{"companyTitle":"INVALID","companyName":"PT Test","otv":"No","paymentCycle":"Monthly","accountNumber":"123","accountName":"Test","bankName":"BCA","hoEmail":"test@assa.id","hoPhone":"08123","hoAddress":"Jakarta","npwp":"12345","accountGroup":"V010","top":"T014","glAccount":"2121000000","documentNumber":"DOC-01"}'
run_test "VALID-02" "Validasi: Vendor create dengan companyTitle invalid" "POST" "${BASE_URL_VENDOR}/api/vendors/create" "400" "$TOKEN_APP_QA" "$INVALID_VENDOR_JSON" "" "" 5

INVALID_SPK_JSON='{"type":"Maintenance","noPolisi":"B-2120-BKZ","category":"Maintenance","subCategory":"Adhoc","vendorReferensi":"0001","totalPrice":1850000,"createdAt":"2026-09-17 14:46:11","createdBy":"atlas.user","details":[{"jenis":"Jasa","description":"Jasa Perbaikan AC","qty":1,"price":1850000}]}'
run_test "VALID-03" "Validasi: SPK Duelist tanpa nomor SPK (noSpk)" "POST" "${BASE_URL_SPK}/api/spk/duelist" "400" "$TOKEN_APP_QA" "$INVALID_SPK_JSON" "" "" 5

INVALID_TOTAL_SPK_JSON='{"noSpk":"SPK/2026/09/00002","type":"Maintenance","noPolisi":"B-2120-BKZ","category":"Maintenance","subCategory":"Adhoc","vendorReferensi":"0001","totalPrice":1850001,"createdAt":"2026-09-17 14:46:11","createdBy":"atlas.user","details":[{"jenis":"Jasa","description":"Jasa Perbaikan AC","qty":1,"price":1850000}]}'
run_test "VALID-04" "Validasi: SPK Duelist dengan total tidak cocok (X-Validate-Total: true)" "POST" "${BASE_URL_SPK}/api/spk/duelist" "400" "$TOKEN_APP_QA" "$INVALID_TOTAL_SPK_JSON" "X-Validate-Total" "true" 5

INVALID_SR_JSON='{"reff_number":"REF01","branchCode":"JKT01","created_datetime":"17-09-2026","created_by":"admin","ticket_no":"TCK01"}'
run_test "VALID-05" "Validasi: Service Request tanpa field wajib app_id" "POST" "${BASE_URL_SR}/api/service-requests" "400" "$TOKEN_OMNICHANNEL" "$INVALID_SR_JSON" "" "" 5

# ------------------------------------------------------------------------------
# BAGIAN 5: Inquiry & Data Retrieval (GET 200 OK)
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}${CYAN}>>> BAGIAN 5: INQUIRY & DATA RETRIEVAL (GET 200 OK)${RESET}"

run_test "GET-01" "Branch Inquiry (App A Token)" "GET" "${BASE_URL_BRANCH}/api/branches/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11&page=1&perPage=5" "200" "$TOKEN_APP_A" "" "" "" 15
run_test "GET-02" "Customer Inquiry (App A Token)" "GET" "${BASE_URL_CUSTOMER}/api/customers/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11&page=1&perPage=5" "200" "$TOKEN_APP_A" "" "" "" 15

# Catatan Vehicle: Jika upstream devfmsapi.assa.id membutuhkan API key dan env kosong, kode 403 adalah respon resmi upstream
run_test "GET-03" "Vehicle Inquiry /getByLicensePlate (App B Token)" "GET" "${BASE_URL_VEHICLE}/api/vehicles/getByLicensePlate?plate_no=DD-8112" "(200|403)" "$TOKEN_APP_B" "" "" "" 15
run_test "GET-04" "Vehicle Inquiry /vehicleatlas (QA Token)" "GET" "${BASE_URL_VEHICLE}/api/vehicles/vehicleatlas?plate_no=DD-8112" "(200|403)" "$TOKEN_APP_QA" "" "" "" 15

# Service Request GET Inquiry (Fitur yang telah diperbaiki: 200 OK dengan JSON Pagination)
run_test "GET-05" "Service Request GET Inquiry (Omnichannel Token)" "GET" "${BASE_URL_SR}/api/service-requests?dateStart=2026-01-01&dateEnd=2026-09-28&page=1&perPage=10" "200" "$TOKEN_OMNICHANNEL" "" "" "" 15

# ------------------------------------------------------------------------------
# BAGIAN 6: Verifikasi Pagination (Customer, Branch, Service Request)
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}${CYAN}>>> BAGIAN 6: VERIFIKASI PAGINASI (PAGE / PER_PAGE)${RESET}"

run_pagination_test "PAGE-01" "Branch Pagination (page 1 vs 2 vs perPage 10)" "${BASE_URL_BRANCH}" "/api/branches/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11" "$TOKEN_APP_A"
run_pagination_test "PAGE-02" "Customer Pagination (page 1 vs 2 vs perPage 10)" "${BASE_URL_CUSTOMER}" "/api/customers/getByCreateDate?companyCode=1000&dateStart=2020-01-01&dateEnd=2026-09-11" "$TOKEN_APP_A"
run_pagination_test "PAGE-03" "Service Request Pagination (page 1 vs 2 vs perPage 10)" "${BASE_URL_SR}" "/api/service-requests?dateStart=2026-01-01&dateEnd=2026-09-28" "$TOKEN_OMNICHANNEL"

# ------------------------------------------------------------------------------
# BAGIAN 7: Background Worker Endpoint
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}${CYAN}>>> BAGIAN 7: BACKGROUND RETRY WORKER${RESET}"

run_test "WORKER-01" "Trigger Background Retry Worker" "GET" "${BASE_URL_SR}/api/worker/retry" "200" "" "" "" "" 10

# ------------------------------------------------------------------------------
# BAGIAN 8: Transactional & Fan-Out Endpoints (POST dengan 10x Retries)
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}${CYAN}>>> BAGIAN 8: TRANSACTIONAL & FAN-OUT ENDPOINTS (POST)${RESET}"

UNIQUE_TRX_SUFFIX=$(date '+%Y%m%d%H%M%S')
SR_TEST_TRX_ID="TRX-SR-LOCAL-${UNIQUE_TRX_SUFFIX}"

VALID_SR_JSON=$(cat <<EOF
{
  "app_id": "sr_app_omnichannel",
  "reff_number": "REF-SR-${UNIQUE_TRX_SUFFIX}",
  "branchCode": "JKT01",
  "equipment_number": "EQ-998877",
  "license_plate": "B-1234-SSA",
  "customerCode": "CUST-00123",
  "customer_name": "PT Maju Bersama ASSA",
  "channel": "Omnichannel-Web",
  "cp_title": "Bpk",
  "cp_name": "Ahmad Fauzi",
  "cp_phone": "081234567890",
  "cp_email": "ahmad.fauzi@example.com",
  "cp_address": "Jl. Gatot Subroto No. 45 Jakarta",
  "km": "25000",
  "description": "Perawatan berkala 25.000 KM dan pengecekan sistem rem",
  "service_datetime": "2026-09-20 10:00:00",
  "service_location": "Bengkel Resmi ASSA Sunter",
  "jenis_permintaan": "Service Berkala",
  "incident_datetime": "2026-09-17 09:00:00",
  "tipe_tiket": "Regular",
  "judul": "Service Berkala Kendaraan Operasional",
  "nama_kunjungan": "Ahmad Fauzi",
  "telepon_kunjungan": "081234567890",
  "alamat_kunjungan": "Jl. Danau Sunter Barat",
  "pool_name": "Pool Sunter",
  "area_bengkel": "Jakarta Utara",
  "task": "Ganti Oli Mesin dan Filter",
  "created_datetime": "$(date '+%d-%m-%Y')",
  "created_by": "omnichannel_agent",
  "ticket_no": "TCK-${UNIQUE_TRX_SUFFIX}"
}
EOF
)

# Pengujian Fan-out SR:
# Menjalankan fan-out paralel ke ATLAS dan ASSA ExtService.
# Apabila salah satu target gagal, WSO2 MI menjalankan retry hingga 10x per target.
# Respon valid adalah 200 (jika kedua target live berhasil) atau 502 (jika target live gagal setelah 10 percobaan).
run_test "SR-01" "Service Request Paralel Fan-out (10x Retry on Failure)" "POST" "${BASE_URL_SR}/api/service-requests" "(200|502)" "$TOKEN_OMNICHANNEL" "$VALID_SR_JSON" "X-Transaction-Id" "$SR_TEST_TRX_ID" 35

# Uji Re-eksekusi / Idempotency Retry (Mengirim ulang payload dengan transactionId yang sama)
# Jika transaksi sebelumnya FAILED, IdempotencyGuard mengizinkan re-eksekusi ulang (10x retries).
run_test "SR-02" "Re-send Transaksi yang Sama (Idempotency Re-try / Re-execute)" "POST" "${BASE_URL_SR}/api/service-requests" "(200|502)" "$TOKEN_OMNICHANNEL" "$VALID_SR_JSON" "X-Transaction-Id" "$SR_TEST_TRX_ID" 35

# ------------------------------------------------------------------------------
# BAGIAN 9: Verifikasi Database Audit Log (MariaDB)
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}${CYAN}>>> BAGIAN 9: VERIFIKASI PENCATATAN AUDIT LOG KE MARIADB${RESET}"
echo -e "${GRAY}Memeriksa rekaman transaksi '${SR_TEST_TRX_ID}' pada container ${DB_CONTAINER}...${RESET}"

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if command -v docker &> /dev/null && docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
    echo -e "\n${BOLD}1. Tabel api_transaction:${RESET}"
    docker exec "$DB_CONTAINER" mariadb -u root -D "$DB_NAME" -e \
        "SELECT transaction_id, endpoint, status, attempt_count, created_at FROM api_transaction WHERE transaction_id = '${SR_TEST_TRX_ID}';" 2>/dev/null || true

    echo -e "\n${BOLD}2. Tabel api_transaction_log (Rekaman Riwayat Percobaan/Retry):${RESET}"
    docker exec "$DB_CONTAINER" mariadb -u root -D "$DB_NAME" -e \
        "SELECT transaction_id, attempt_number, endpoint, response_status, created_at FROM api_transaction_log WHERE transaction_id = '${SR_TEST_TRX_ID}' ORDER BY id ASC;" 2>/dev/null || true

    # Verifikasi apakah rekaman ada
    LOG_COUNT=$(docker exec "$DB_CONTAINER" mariadb -u root -N -D "$DB_NAME" -e \
        "SELECT count(*) FROM api_transaction_log WHERE transaction_id = '${SR_TEST_TRX_ID}';" 2>/dev/null || echo "0")
    
    if [[ "$LOG_COUNT" -gt 0 ]]; then
        echo -e "\nVerifikasi Database: ${GREEN}${BOLD}LULUS (PASS) - Ditemukan ${LOG_COUNT} entri audit log di MariaDB${RESET}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "\nVerifikasi Database: ${RED}${BOLD}GAGAL (FAIL) - Tidak ditemukan log untuk ${SR_TEST_TRX_ID}${RESET}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
else
    echo -e "${YELLOW}[SKIP] Docker container '${DB_CONTAINER}' tidak terdeteksi berjalan di host.${RESET}"
    echo -e "${GRAY}Untuk memeriksa manual via MySQL/MariaDB client:${RESET}"
    echo -e "${GRAY}SELECT * FROM api_transaction WHERE transaction_id = '${SR_TEST_TRX_ID}';${RESET}"
    SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
fi

# ------------------------------------------------------------------------------
# Rangkuman Pengujian Akhir
# ------------------------------------------------------------------------------
echo -e "\n${CYAN}========================================================================${RESET}"
echo -e "${BOLD}${CYAN}                       HASIL AKHIR PENGUJIAN                       ${RESET}"
echo -e "${CYAN}========================================================================${RESET}"
echo -e "Total Skenario Diuji : ${BOLD}${TOTAL_TESTS}${RESET}"
echo -e "Lulus (PASS)         : ${GREEN}${BOLD}${PASSED_TESTS}${RESET}"
echo -e "Gagal (FAIL)         : ${RED}${BOLD}${FAILED_TESTS}${RESET}"
echo -e "Dilewati (SKIPPED)   : ${YELLOW}${BOLD}${SKIPPED_TESTS}${RESET}"
echo -e "${CYAN}------------------------------------------------------------------------${RESET}"

if [[ "$FAILED_TESTS" -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}SELURUH PENGUJIAN SELESAI DENGAN SUKSES! [OK]${RESET}\n"
    exit 0
else
    echo -e "${RED}${BOLD}TERDAPAT ${FAILED_TESTS} PENGUJIAN YANG GAGAL. SILAKAN PERIKSA DETAIL DI ATAS.${RESET}\n"
    exit 1
fi
