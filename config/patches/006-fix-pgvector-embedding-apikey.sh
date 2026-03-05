#!/bin/sh
# 006-fix-pgvector-embedding-apikey.sh — Use env var for pgvector embedding key
#
# The memory-pgvector plugin's embedding.apiKey only accepts a plain string,
# not a SecretRef object. Replace the SecretRef with an env var placeholder
# so the wrapper script can inject the value at runtime.

set -e

CONFIG="$1"

echo "  patch 006: fixing pgvector embedding apiKey (must be plain string)"

jq '
  # Replace SecretRef object with env var placeholder
  if .plugins.entries["memory-pgvector"].config.embedding.apiKey | type == "object" then
    .plugins.entries["memory-pgvector"].config.embedding.apiKey = "${OPENAI_API_KEY}"
  else . end
' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"

echo "  patch 006: done"
