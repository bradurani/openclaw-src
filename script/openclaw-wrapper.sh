#!/usr/bin/env bash
set -euo pipefail

# All secrets are resolved here via env vars rather than SecretRef exec
# provider because the exec provider cannot reliably find the `aws` CLI
# when spawned as a subprocess by OpenClaw's node process (PATH issue).
#
# Env vars injected:
#   - GH_TOKEN        — GitHub CLI auth (used by agents for git operations)
#   - PGVECTOR_URL    — memory-pgvector plugin connection string
#   - GATEWAY_TOKEN   — gateway.auth.token (only accepts plain string)
#   - OPENAI_API_KEY  — openai provider + pgvector embedding
#   - SLACK_BOT_TOKEN — Slack channel bot token
#   - SLACK_APP_TOKEN — Slack channel app-level token

REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-2}}"

fetch_secret() {
  aws secretsmanager get-secret-value \
    --secret-id "$1" \
    --region "$REGION" \
    --query 'SecretString' \
    --output text 2>/dev/null || true
}

export GH_TOKEN="${GH_TOKEN:-$(fetch_secret openclaw/github-token)}"
export PGVECTOR_URL="${PGVECTOR_URL:-$(fetch_secret openclaw/pgvector-url)}"
export GATEWAY_TOKEN="${GATEWAY_TOKEN:-$(fetch_secret openclaw/gateway-token)}"
export OPENAI_API_KEY="${OPENAI_API_KEY:-$(fetch_secret openclaw/openai-api-key)}"
export SLACK_BOT_TOKEN="${SLACK_BOT_TOKEN:-$(fetch_secret openclaw/slack-bot-token)}"
export SLACK_APP_TOKEN="${SLACK_APP_TOKEN:-$(fetch_secret openclaw/slack-app-token)}"

export OPENAI_DEFAULT_MODEL="${OPENAI_DEFAULT_MODEL:-openai/gpt-5.2}"
export OPENAI_CODING_MODEL="${OPENAI_CODING_MODEL:-openai/gpt-5.1-codex}"

exec node /app/openclaw.mjs "$@"
