#!/bin/sh
# 004-fix-secretref-format.sh — Rewrite SecretRef objects & provider to correct schema
#
# Previous patches (001, 002) used the wrong format:
#
#   WRONG provider:  { "type": "exec", "command": "..." }
#   CORRECT:         { "source": "exec", "command": "..." }
#
#   WRONG secretref: { "$secretRef": { "provider": "awssm", "id": "..." } }
#   CORRECT:         { "source": "exec", "provider": "awssm", "id": "..." }
#
# This patch:
#   1. Fixes the awssm provider: replaces "type" with "source"
#   2. Converts all $secretRef wrapper objects to native SecretRef format
#   3. Adds openai baseUrl default if missing (newly required by schema)

set -e

CONFIG="$1"

echo "  patch 004: rewriting SecretRef objects and provider to correct format"

jq '
  # 1. Fix provider: "type" → "source"
  (if .secrets.providers.awssm then
    .secrets.providers.awssm |= (del(.type) | .source = "exec")
  else . end)

  # 2. Convert {"$secretRef": {"provider": P, "id": I}} → {"source": "exec", "provider": P, "id": I}
  | walk(
    if type == "object" and has("$secretRef") and (."$secretRef" | type == "object") then
      ."$secretRef" | {source: "exec", provider: .provider, id: .id}
    else
      .
    end
  )

  # 3. Add openai baseUrl if missing
  | if .models.providers.openai and (.models.providers.openai.baseUrl == null) then
      .models.providers.openai.baseUrl = "https://api.openai.com/v1"
    else . end
' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"

echo "  patch 004: done"
