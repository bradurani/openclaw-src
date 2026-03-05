#!/bin/sh
# 003-strip-awssm-env-block.sh — Remove env block from awssm provider
#
# Patch 001 added an explicit env block to the awssm exec provider that
# forwards AWS credential env vars like AWS_CONTAINER_CREDENTIALS_FULL_URI.
# OpenClaw's config parser treats every ${VAR} as a required substitution,
# so any unset var causes a MissingEnvVarError crash on startup.
#
# The exec provider inherits the container's full environment automatically,
# so the env block is unnecessary. Remove it.

set -e

CONFIG="$1"

if ! jq -e '.secrets.providers.awssm.env' "$CONFIG" >/dev/null 2>&1; then
  echo "  patch 003: awssm env block not present — skipping"
  exit 0
fi

echo "  patch 003: removing env block from awssm provider"

jq 'del(.secrets.providers.awssm.env)' "$CONFIG" > "${CONFIG}.tmp" \
  && mv "${CONFIG}.tmp" "$CONFIG"

echo "  patch 003: done"
