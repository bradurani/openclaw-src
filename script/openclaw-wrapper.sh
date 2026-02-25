#!/usr/bin/env bash
set -euo pipefail

LOAD_SECRETS_BIN="/usr/local/bin/load-secrets"
SECRETS_SOURCE="${OPENCLAW_SECRETS_SOURCE:-aws}"

case "$SECRETS_SOURCE" in
  aws)
    if [[ -x "$LOAD_SECRETS_BIN" ]]; then
      # shellcheck disable=SC1090
      eval "$($LOAD_SECRETS_BIN --format shell)"
    fi
    ;;
  env)
    # Use environment values already injected by the caller (for example .env).
    ;;
  *)
    echo "openclaw-wrapper: unsupported OPENCLAW_SECRETS_SOURCE='$SECRETS_SOURCE' (expected: aws or env)" >&2
    exit 1
    ;;
esac

export CHANNELS__SLACK__TOKEN="${CHANNELS__SLACK__TOKEN:-${SLACK_BOT_TOKEN:-}}"
export OPENAI_DEFAULT_MODEL="${OPENAI_DEFAULT_MODEL:-openai/gpt-5.2}"
export OPENAI_CODING_MODEL="${OPENAI_CODING_MODEL:-openai/gpt-5.1-codex}"

if [[ -z "${SLACK_BOT_TOKEN:-}" ]]; then
  echo "openclaw-wrapper: SLACK_BOT_TOKEN is not set; set OPENCLAW_SECRETS_SOURCE=env to use .env values or ensure AWS secrets access is configured" >&2
fi

exec node /app/openclaw.mjs "$@"
