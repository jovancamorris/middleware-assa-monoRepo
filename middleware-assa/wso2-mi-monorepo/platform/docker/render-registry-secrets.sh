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