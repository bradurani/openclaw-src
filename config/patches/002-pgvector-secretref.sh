#!/bin/sh
# 002-pgvector-secretref.sh — Migrate memory-pgvector embedding API key to SecretRef
#
# The memory-pgvector extension references ${OPENAI_API_KEY} for embeddings.
# Patch 001 didn't cover plugin config paths. This converts the env-var
# reference to a native SecretRef pointing to the same Secrets Manager entry.

set -e

CONFIG="$1"

# Skip if already a SecretRef (has $secretRef key)
if jq -e '.plugins.entries["memory-pgvector"].config.embedding.apiKey["$secretRef"]' "$CONFIG" >/dev/null 2>&1; then
  echo "  patch 002: memory-pgvector embedding apiKey already a SecretRef — skipping"
  exit 0
fi

# Skip if the path doesn't exist at all
if ! jq -e '.plugins.entries["memory-pgvector"].config.embedding.apiKey' "$CONFIG" >/dev/null 2>&1; then
  echo "  patch 002: memory-pgvector embedding apiKey path not found — skipping"
  exit 0
fi

echo "  patch 002: converting memory-pgvector embedding apiKey to SecretRef"

jq '
  .plugins.entries["memory-pgvector"].config.embedding.apiKey = {
    "$secretRef": { "provider": "awssm", "id": "openclaw/openai-api-key" }
  }
' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
