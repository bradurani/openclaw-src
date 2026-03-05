#!/bin/sh
# 001-secretref-aws-sm.sh — Migrate secrets to env var placeholders
#
# Idempotent: checks whether the awssm provider already exists before writing.
# All secrets are resolved via env vars set by the wrapper script, because
# the SecretRef exec provider cannot reliably find the `aws` CLI when
# spawned as a subprocess by OpenClaw's node process.

set -e

CONFIG="$1"

# Skip if the awssm provider is already configured
if jq -e '.secrets.providers.awssm' "$CONFIG" >/dev/null 2>&1; then
  echo "  patch 001: awssm provider already present — skipping"
  exit 0
fi

echo "  patch 001: adding awssm provider and env var secret references"

jq '
  # --- provider (kept for future use once PATH issue is resolved) ----------
  .secrets.providers.awssm = {
    "source": "exec",
    "command": "/usr/local/bin/aws-sm-resolver"
  }

  # --- secret references (all via env vars) --------------------------------
  | .models.providers.openai.apiKey = "${OPENAI_API_KEY}"
  | .channels.slack.botToken = "${SLACK_BOT_TOKEN}"
  | .channels.slack.appToken = "${SLACK_APP_TOKEN}"
  | .gateway.auth.token = "${GATEWAY_TOKEN}"

  # --- models array (required) --------------------------------------------
  | .models.providers.openai.models //= [
      {"id": "gpt-4.1", "name": "GPT-4.1"},
      {"id": "gpt-4.1-mini", "name": "GPT-4.1 Mini"},
      {"id": "gpt-4.1-nano", "name": "GPT-4.1 Nano"},
      {"id": "gpt-5.1-codex", "name": "GPT-5.1 Codex"},
      {"id": "gpt-5.2", "name": "GPT-5.2"},
      {"id": "gpt-5.2-codex", "name": "GPT-5.2 Codex"},
      {"id": "o3-mini", "name": "o3-mini"},
      {"id": "o4-mini", "name": "o4-mini"}
    ]
' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
