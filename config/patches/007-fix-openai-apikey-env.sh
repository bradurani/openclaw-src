#!/bin/sh
# 007-fix-openai-apikey-env.sh — Use env var for openai provider apiKey
#
# The exec provider cannot find the `aws` CLI when spawned by OpenClaw's
# node process (PATH issue). As a workaround, resolve all remaining
# SecretRef-using fields via env vars instead. The wrapper script already
# exports OPENAI_API_KEY from Secrets Manager before launching the app.
#
# Also convert Slack bot/app tokens since they have the same problem.

set -e

CONFIG="$1"

echo "  patch 007: converting remaining SecretRefs to env var placeholders"

jq '
  # openai apiKey
  if .models.providers.openai.apiKey | type == "object" then
    .models.providers.openai.apiKey = "${OPENAI_API_KEY}"
  else . end

  # slack botToken
  | if .channels.slack.botToken | type == "object" then
      .channels.slack.botToken = "${SLACK_BOT_TOKEN}"
    else . end

  # slack appToken
  | if .channels.slack.appToken | type == "object" then
      .channels.slack.appToken = "${SLACK_APP_TOKEN}"
    else . end
' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"

echo "  patch 007: done"
