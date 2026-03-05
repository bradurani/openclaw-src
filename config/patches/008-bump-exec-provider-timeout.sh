#!/bin/sh
# 008-bump-exec-provider-timeout.sh — Increase awssm exec provider timeout
#
# The default OpenClaw exec provider timeout is 5000ms. The aws-sm-resolver
# calls the aws CLI which spawns Python, then makes HTTP calls to Secrets
# Manager. On cold start with 3 secrets fetched sequentially, this easily
# exceeds 5s. Bump to 30s.

set -e

CONFIG="$1"

echo "  patch 008: bumping awssm exec provider timeout to 30000ms"

jq '
  if .secrets.providers.awssm then
    .secrets.providers.awssm.timeoutMs = 30000
  else . end
' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"

echo "  patch 008: done"
