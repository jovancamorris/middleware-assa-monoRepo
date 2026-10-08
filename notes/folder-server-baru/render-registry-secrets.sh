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
REGISTRY_DIR="${DB_REGISTRY_DIR:-$MI_HOME/registry/config/repository/assa/db}"

DEFAULT_DRIVER='org.mariadb.jdbc.Driver'
DEFAULT_HOST="${DB_HOST:-mariadb}"
DEFAULT_PORT="${DB_PORT:-3306}"
DEFAULT_NAME="${DB_NAME:-assa_middleware_db}"
DEFAULT_URL="jdbc:mariadb://${DEFAULT_HOST}:${DEFAULT_PORT}/${DEFAULT_NAME}?useSSL=false&allowPublicKeyRetrieval=true"

DB_USERNAME="${DB_USERNAME:-root}"
DB_PASSWORD="${DB_PASSWORD:-}"


mkdir -p "$REGISTRY_DIR"

printf '%s' "${DB_DRIVER:-$DEFAULT_DRIVER}" > "$REGISTRY_DIR/driver"
printf '%s' "${DB_URL:-$DEFAULT_URL}"        > "$REGISTRY_DIR/url"
printf '%s' "$DB_USERNAME"                   > "$REGISTRY_DIR/username"
printf '%s' "$DB_PASSWORD"                   > "$REGISTRY_DIR/password"

chmod 600 "$REGISTRY_DIR/username" "$REGISTRY_DIR/password"
chmod 644 "$REGISTRY_DIR/driver" "$REGISTRY_DIR/url"

echo "[ENTRYPOINT] Registry secrets rendered to $REGISTRY_DIR (driver, url, username, password)"

# Configure Service Catalog in deployment.toml if enabled
if [ "${APIM_SERVICE_CATALOG_ENABLE:-false}" = "true" ]; then
    MI_CONF="$MI_HOME/conf/deployment.toml"
    APIM_HOST_URL="${APIM_HOST:-https://api-manager:9443}"
    APIM_USER="${APIM_ADMIN_USERNAME:-admindev}"
    APIM_PASS="${APIM_ADMIN_PASSWORD:-4554r3nt*2023}"
    if [ -f "$MI_CONF" ]; then
        if ! grep -q "apim_host" "$MI_CONF"; then
            printf '\n[[service_catalog]]\napim_host = "%s"\nenable = true\nusername = "%s"\npassword = "%s"\n' "$APIM_HOST_URL" "$APIM_USER" "$APIM_PASS" >> "$MI_CONF"
            echo "[ENTRYPOINT] Service Catalog configured to $APIM_HOST_URL"
        fi
    fi
fi
