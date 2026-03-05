#!/bin/sh
# 009-add-passenv-to-awssm.sh — Pass AWS credential env vars to the exec provider
#
# OpenClaw spawns exec providers with an empty environment by default.
# Without passEnv the aws-sm-resolver has no way to discover ECS task-role
# credentials or the configured AWS region.

set -e

CONFIG="$1"

echo "  patch 009: adding passEnv to awssm exec provider"

jq '
  .secrets.providers.awssm.passEnv = [
    "AWS_REGION",
    "AWS_DEFAULT_REGION",
    "AWS_CONTAINER_CREDENTIALS_RELATIVE_URI",
    "AWS_CONTAINER_CREDENTIALS_FULL_URI",
    "ECS_CONTAINER_METADATA_URI_V4",
    "HOME"
  ]
' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"

echo "  patch 009: done"
