#!/bin/sh
# Render database connection values into MI registry resources.
#
# The dblookup/dbreport mediators reference these values through the `key`
# attribute on <driver>/<url>/<user>/<password> inside <pool>, so no database
# credential is stored in the CAR or in the repository.
#
# Required environment: DB_USERNAME, DB_PASSWORD
# Optional environment: DB_URL, DB_DRIVER, DB_REGISTRY_DIR
set -eu

MI_HOME="${WSO2_SERVER_HOME:-/home/wso2carbon/wso2mi}"
# MI resolves the conf:/repository/... registry path against the *config*
# repository, which lives under registry/config/repository. Verified on
# MI 4.6.0: writing to registry/repository/... yields
# "Registry entry defined with key: conf:/repository/... not found".
REGISTRY_DIR="${DB_REGISTRY_DIR:-$MI_HOME/registry/config/repository/assa/db}"

DEFAULT_DRIVER='org.mariadb.jdbc.Driver'
# Note: the URL is stored unescaped. It is a plain text file, not XML, so an
# ampersand must NOT be written as &amp; here.
DEFAULT_URL='jdbc:mariadb://localhost:3307/assa_middleware_db?useSSL=false&allowPublicKeyRetrieval=true'

if [ -z "${DB_USERNAME:-}" ]; then
    echo "[ENTRYPOINT] ERROR: DB_USERNAME is not set. Cannot render registry secrets." >&2
    exit 1
fi

if [ -z "${DB_PASSWORD:-}" ]; then
    echo "[ENTRYPOINT] ERROR: DB_PASSWORD is not set. Cannot render registry secrets." >&2
    exit 1
fi

mkdir -p "$REGISTRY_DIR"

printf '%s' "${DB_DRIVER:-$DEFAULT_DRIVER}" > "$REGISTRY_DIR/driver"
printf '%s' "${DB_URL:-$DEFAULT_URL}"        > "$REGISTRY_DIR/url"
printf '%s' "$DB_USERNAME"                   > "$REGISTRY_DIR/username"
printf '%s' "$DB_PASSWORD"                   > "$REGISTRY_DIR/password"

chmod 600 "$REGISTRY_DIR/username" "$REGISTRY_DIR/password"
chmod 644 "$REGISTRY_DIR/driver" "$REGISTRY_DIR/url"

echo "[ENTRYPOINT] Registry secrets rendered to $REGISTRY_DIR (driver, url, username, password)"

# Render Inbound VFS URLs to file.properties so $SYSTEM: lookups in inbound-endpoints resolve
CONF_DIR="$MI_HOME/conf"
FILE_PROP="$CONF_DIR/file.properties"
mkdir -p "$CONF_DIR"
touch "$FILE_PROP"

SAP_USER="${FTP_SAP_USERNAME:-middlewaredev}"
SAP_PASS_RAW="${FTP_SAP_PASSWORD:-}"
SAP_PASS_ENC=$(printf '%s' "$SAP_PASS_RAW" | sed 's/#/%23/g')
SAP_HOST="${FTP_SAP_HOST:-devqaxmlpool.assa.id}"
SAP_PORT="${FTP_SAP_PORT:-21}"

if [ -z "${FTP_VENDOR_INBOUND_FILE_URI:-}" ]; then
    if [ -n "$SAP_PASS_ENC" ]; then
        FTP_VENDOR_INBOUND_FILE_URI="ftp://${SAP_USER}:${SAP_PASS_ENC}@${SAP_HOST}:${SAP_PORT}/vmd/upload?vfs.passive=true"
        FTP_VENDOR_INBOUND_MOVE_SUCCESS="ftp://${SAP_USER}:${SAP_PASS_ENC}@${SAP_HOST}:${SAP_PORT}/vmd/upload/success?vfs.passive=true"
        FTP_VENDOR_INBOUND_MOVE_FAILED="ftp://${SAP_USER}:${SAP_PASS_ENC}@${SAP_HOST}:${SAP_PORT}/vmd/upload/failed?vfs.passive=true"
    else
        FTP_VENDOR_INBOUND_FILE_URI="vfs:file:///home/wso2carbon/ftp_dummy/vmd/upload"
        FTP_VENDOR_INBOUND_MOVE_SUCCESS="vfs:file:///home/wso2carbon/ftp_dummy/vmd/upload/success"
        FTP_VENDOR_INBOUND_MOVE_FAILED="vfs:file:///home/wso2carbon/ftp_dummy/vmd/upload/failed"
    fi
else
    FTP_VENDOR_INBOUND_MOVE_SUCCESS="${FTP_VENDOR_INBOUND_MOVE_SUCCESS:-vfs:file:///home/wso2carbon/ftp_dummy/vmd/upload/success}"
    FTP_VENDOR_INBOUND_MOVE_FAILED="${FTP_VENDOR_INBOUND_MOVE_FAILED:-vfs:file:///home/wso2carbon/ftp_dummy/vmd/upload/failed}"
fi

AP_USER="${FTP_APDUELIST_USERNAME:-${FTP_SAP_USERNAME:-middlewaredev}}"
AP_PASS_RAW="${FTP_APDUELIST_PASSWORD:-${FTP_SAP_PASSWORD:-}}"
AP_PASS_ENC=$(printf '%s' "$AP_PASS_RAW" | sed 's/#/%23/g')
AP_HOST="${FTP_APDUELIST_HOST:-${FTP_SAP_HOST:-devqaxmlpool.assa.id}}"
AP_PORT="${FTP_APDUELIST_PORT:-${FTP_SAP_PORT:-21}}"

if [ -z "${FTP_APDUELIST_INBOUND_FILE_URI:-}" ]; then
    if [ -n "$AP_PASS_ENC" ]; then
        FTP_APDUELIST_INBOUND_FILE_URI="ftp://${AP_USER}:${AP_PASS_ENC}@${AP_HOST}:${AP_PORT}/apduelist/upload?vfs.passive=true"
        FTP_APDUELIST_INBOUND_MOVE_SUCCESS="ftp://${AP_USER}:${AP_PASS_ENC}@${AP_HOST}:${AP_PORT}/apduelist/upload/success?vfs.passive=true"
        FTP_APDUELIST_INBOUND_MOVE_FAILED="ftp://${AP_USER}:${AP_PASS_ENC}@${AP_HOST}:${AP_PORT}/apduelist/upload/failed?vfs.passive=true"
    else
        FTP_APDUELIST_INBOUND_FILE_URI="vfs:file:///home/wso2carbon/ftp_dummy/apduelist/upload"
        FTP_APDUELIST_INBOUND_MOVE_SUCCESS="vfs:file:///home/wso2carbon/ftp_dummy/apduelist/upload/success"
        FTP_APDUELIST_INBOUND_MOVE_FAILED="vfs:file:///home/wso2carbon/ftp_dummy/apduelist/upload/failed"
    fi
else
    FTP_APDUELIST_INBOUND_MOVE_SUCCESS="${FTP_APDUELIST_INBOUND_MOVE_SUCCESS:-vfs:file:///home/wso2carbon/ftp_dummy/apduelist/upload/success}"
    FTP_APDUELIST_INBOUND_MOVE_FAILED="${FTP_APDUELIST_INBOUND_MOVE_FAILED:-vfs:file:///home/wso2carbon/ftp_dummy/apduelist/upload/failed}"
fi

# Create fallback directories in case local dummy VFS is used
mkdir -p /home/wso2carbon/ftp_dummy/vmd/upload/success \
         /home/wso2carbon/ftp_dummy/vmd/upload/failed \
         /home/wso2carbon/ftp_dummy/apduelist/upload/success \
         /home/wso2carbon/ftp_dummy/apduelist/upload/failed 2>/dev/null || true

export FTP_VENDOR_INBOUND_FILE_URI
export FTP_VENDOR_INBOUND_MOVE_SUCCESS
export FTP_VENDOR_INBOUND_MOVE_FAILED
export FTP_APDUELIST_INBOUND_FILE_URI
export FTP_APDUELIST_INBOUND_MOVE_SUCCESS
export FTP_APDUELIST_INBOUND_MOVE_FAILED

for vfs_var in FTP_VENDOR_INBOUND_FILE_URI FTP_VENDOR_INBOUND_MOVE_SUCCESS FTP_VENDOR_INBOUND_MOVE_FAILED \
               FTP_APDUELIST_INBOUND_FILE_URI FTP_APDUELIST_INBOUND_MOVE_SUCCESS FTP_APDUELIST_INBOUND_MOVE_FAILED; do
    eval vfs_val=\${$vfs_var:-}
    if [ -n "$vfs_val" ]; then
        sed -i "/^${vfs_var}=/d" "$FILE_PROP" 2>/dev/null || true
        printf '%s=%s\n' "$vfs_var" "$vfs_val" >> "$FILE_PROP"
    fi
done
echo "[ENTRYPOINT] Inbound VFS URLs registered and exported (FTP_VENDOR_*, FTP_APDUELIST_*)"