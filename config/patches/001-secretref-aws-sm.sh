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
    "type": "exec",
    "command": "/usr/local/bin/aws-sm-resolver",
    "env": {
      "AWS_REGION": "${AWS_REGION}",
      "AWS_CONTAINER_CREDENTIALS_RELATIVE_URI": "${AWS_CONTAINER_CREDENTIALS_RELATIVE_URI}",
      "AWS_DEFAULT_REGION": "${AWS_DEFAULT_REGION}",
      "AWS_EXECUTION_ENV": "${AWS_EXECUTION_ENV}",
      "AWS_CONTAINER_CREDENTIALS_FULL_URI": "${AWS_CONTAINER_CREDENTIALS_FULL_URI}",
      "AWS_CONTAINER_AUTHORIZATION_TOKEN": "${AWS_CONTAINER_AUTHORIZATION_TOKEN}"
    }
  }

  # --- secret references ---------------------------------------------------
  | .models.providers.openai.apiKey = {
      "$secretRef": { "provider": "awssm", "id": "openclaw/openai-api-key" }
    }
  | .channels.slack.botToken = {
      "$secretRef": { "provider": "awssm", "id": "openclaw/slack-bot-token" }
    }
  | .channels.slack.appToken = {
      "$secretRef": { "provider": "awssm", "id": "openclaw/slack-app-token" }
    }
  | .gateway.auth.token = {
      "$secretRef": { "provider": "awssm", "id": "openclaw/gateway-token" }
    }
' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
