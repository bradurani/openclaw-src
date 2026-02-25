#!/usr/bin/env bash
set -euo pipefail

LOAD_SECRETS_BIN="/usr/local/bin/load-secrets"

# ECS Exec starts new processes that do not inherit the entrypoint shell's
# runtime-loaded secrets. Load them again for each openclaw invocation in ECS.
if [[ -n "${AWS_EXECUTION_ENV:-}" ]] && [[ "${OPENCLAW_SECRETS_LOADED:-0}" != "1" ]] && [[ -x "$LOAD_SECRETS_BIN" ]]; then
  # shellcheck disable=SC1090
  eval "$($LOAD_SECRETS_BIN --format shell)"
fi

exec node /app/openclaw.mjs "$@"
