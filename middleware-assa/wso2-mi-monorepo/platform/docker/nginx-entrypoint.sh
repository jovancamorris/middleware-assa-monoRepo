#!/bin/sh
set -eu

printf 'window.__SWAGGER_CONFIG__ = {"serverUrl":"%s"};\n' \
  "${SWAGGER_SERVER_URL:-http://localhost:6031}" \
  > /tmp/swagger-config.js

exec nginx -g 'daemon off;'
