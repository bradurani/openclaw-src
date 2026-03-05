#!/bin/sh
# 001-secretref-aws-sm.sh — Migrate secrets to native SecretRef exec provider
#
# Idempotent: checks whether the awssm provider already exists before writing.
# Replaces env-var references (${OPENAI_API_KEY}, ${SLACK_BOT_TOKEN}, etc.)
# with SecretRef objects pointing to the aws-sm-resolver exec provider.

set -e

CONFIG="$1"

# Skip if the awssm provider is already configured
if jq -e '.secrets.providers.awssm' "$CONFIG" >/dev/null 2>&1; then
  echo "  patch 001: awssm provider already present — skipping"
  exit 0
fi

echo "  patch 001: adding SecretRef exec provider (awssm) and secret references"

jq '
  # --- provider -----------------------------------------------------------
  .secrets.providers.awssm = {
    "source": "exec",
    "command": "/usr/local/bin/aws-sm-resolver"
  }

  # --- secret references ---------------------------------------------------
  | .models.providers.openai.apiKey = {
      "source": "exec", "provider": "awssm", "id": "openclaw/openai-api-key"
    }
  | .channels.slack.botToken = {
      "source": "exec", "provider": "awssm", "id": "openclaw/slack-bot-token"
    }
  | .channels.slack.appToken = {
      "source": "exec", "provider": "awssm", "id": "openclaw/slack-app-token"
    }

  # gateway.auth.token only accepts a plain string — use env var interpolation
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
