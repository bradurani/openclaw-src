#!/bin/sh
# entrypoint.sh — Merge image config with EFS persistent state
#
# On ECS the EFS volume is mounted at /data. This script symlinks runtime state
# directories from ~/.openclaw into /data so they persist across deploys.
# Locally (no /data mount) everything stays in ~/.openclaw as-is.

set -e

OPENCLAW_DIR="${HOME}/.openclaw"
EFS_DIR="${EFS_MOUNT_PATH:-/data}"

# Directories that hold runtime state and must persist across container restarts.
# Symlink the entire OPENCLAW_DIR to EFS_DIR for persistent state
if [ -d "$EFS_DIR" ] && mountpoint -q "$EFS_DIR" 2>/dev/null; then
  echo "entrypoint: EFS detected at $EFS_DIR — linking persistent state"

  # Remove the baked-in directory (or placeholder) from the image
  rm -rf "$OPENCLAW_DIR"

  # Symlink so openclaw reads/writes to EFS transparently
  ln -sfn "$EFS_DIR" "$OPENCLAW_DIR"

  echo "entrypoint:   $OPENCLAW_DIR -> $EFS_DIR"
else
  echo "entrypoint: no EFS mount at $EFS_DIR — exiting"
  exit 1 
fi

# Map secrets to the env vars openclaw expects
export CHANNELS__SLACK__TOKEN="${CHANNELS__SLACK__TOKEN:-$SLACK_BOT_TOKEN}"
export OPENAI_DEFAULT_MODEL="openai/gpt-5.2"
export OPENAI_CODING_MODEL="openai/gpt-5.1-codex"

# Hand off to the original CMD
exec "$@"
