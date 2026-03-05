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
  | .gateway.auth.token = {
      "source": "exec", "provider": "awssm", "id": "openclaw/gateway-token"
    }
' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
