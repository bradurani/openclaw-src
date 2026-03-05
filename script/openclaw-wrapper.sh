#!/usr/bin/env bash
set -euo pipefail

# OpenClaw credentials (OpenAI, Slack) are resolved natively via the
# SecretRef exec provider configured in openclaw.json.
#
# This wrapper injects env vars needed by non-OpenClaw tools AND fields
# that only accept plain strings (not SecretRef objects):
#   - GH_TOKEN       — GitHub CLI auth (used by agents for git operations)
#   - PGVECTOR_URL   — memory-pgvector plugin (uses ${PGVECTOR_URL} env interpolation)
#   - GATEWAY_TOKEN  — gateway.auth.token only accepts a plain string

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

export OPENAI_DEFAULT_MODEL="${OPENAI_DEFAULT_MODEL:-openai/gpt-5.2}"
export OPENAI_CODING_MODEL="${OPENAI_CODING_MODEL:-openai/gpt-5.1-codex}"

exec node /app/openclaw.mjs "$@"
