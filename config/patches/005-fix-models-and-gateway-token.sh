#!/bin/sh
# 005-fix-models-and-gateway-token.sh — Add required models array, fix gateway token
#
# Two remaining validation errors after patches 001-004:
#
# 1. models.providers.openai.models — REQUIRED array of {id, name} objects.
#    The provider entry was missing this entirely.
#
# 2. gateway.auth.token — only accepts a plain string, NOT a SecretRef object.
#    Move it to an env-var reference so the wrapper script can inject it at
#    runtime, just like GH_TOKEN and PGVECTOR_URL.

set -e

CONFIG="$1"

echo "  patch 005: adding models array and fixing gateway token"

jq '
  # 1. Add models array if missing from openai provider
  .models.providers.openai.models //= [
    {"id": "gpt-4.1", "name": "GPT-4.1"},
    {"id": "gpt-4.1-mini", "name": "GPT-4.1 Mini"},
    {"id": "gpt-4.1-nano", "name": "GPT-4.1 Nano"},
    {"id": "gpt-5.1-codex", "name": "GPT-5.1 Codex"},
    {"id": "gpt-5.2", "name": "GPT-5.2"},
    {"id": "gpt-5.2-codex", "name": "GPT-5.2 Codex"},
    {"id": "o3-mini", "name": "o3-mini"},
    {"id": "o4-mini", "name": "o4-mini"}
  ]

  # 2. Replace gateway.auth.token SecretRef with env var placeholder
  | if .gateway.auth.token | type == "object" then
      .gateway.auth.token = "${GATEWAY_TOKEN}"
    else . end
' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"

echo "  patch 005: done"
