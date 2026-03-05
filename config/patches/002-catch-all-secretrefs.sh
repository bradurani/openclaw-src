#!/bin/sh
# 002-catch-all-secretrefs.sh — Convert ALL remaining env-var refs to SecretRefs
#
# Patch 001 handled a fixed set of config paths. But the config may have
# additional ${...} references that weren't anticipated, causing the app to
# crash on startup with MissingEnvVarError.
#
# This patch walks the entire config tree and replaces every string value
# that is exactly "${SOME_VAR}" with the appropriate SecretRef, using a
# known mapping of env var names to Secrets Manager IDs.
#
# Env vars that ARE set at runtime (PGVECTOR_URL, AWS_REGION, etc.) are
# left alone — they resolve fine from the environment.

set -e

CONFIG="$1"

echo "  patch 002: scanning for remaining env-var references"

# Use jq to recursively walk the config and replace known env-var strings.
# The wrapper script sets PGVECTOR_URL, GH_TOKEN, OPENAI_DEFAULT_MODEL,
# OPENAI_CODING_MODEL, and AWS_* vars at runtime — leave those alone.
jq '
  def secretref(provider; id):
    {"source": "exec", "provider": provider, "id": id};

  # Map of env var names to Secrets Manager secret IDs.
  # Only vars that are NOT set in the runtime environment.
  {
    "OPENAI_API_KEY":  "openclaw/openai-api-key",
    "SLACK_BOT_TOKEN": "openclaw/slack-bot-token",
    "SLACK_APP_TOKEN": "openclaw/slack-app-token",
    "GATEWAY_TOKEN":   "openclaw/gateway-token"
  } as $secret_map |

  # Recursively walk and replace string values like "${VAR_NAME}"
  walk(
    if type == "string" and test("^\\$\\{[A-Z_][A-Z0-9_]*\\}$") then
      capture("^\\$\\{(?<var>.+)\\}$").var as $var |
      if $secret_map[$var] then
        secretref("awssm"; $secret_map[$var])
      else
        .  # Leave unknown/runtime env vars as-is
      end
    else
      .
    end
  )
' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"

echo "  patch 002: done"
