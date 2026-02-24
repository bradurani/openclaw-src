#!/bin/sh
# entrypoint.sh — Merge image config with EFS persistent state
#
# On ECS the EFS volume is mounted at /data. This script symlinks runtime state
# directories from ~/.openclaw into /data so they persist across deploys.
# Locally (no /data mount) everything stays in ~/.openclaw as-is.
#
# NOTE: Changes to this file trigger a deploy via CI.

set -e

OPENCLAW_DIR="${HOME}/.openclaw"
EFS_DIR="${EFS_MOUNT_PATH:-/data}"


# Symlink the entire .openclaw directory to EFS
EFS_OPENCLAW_DIR="${EFS_DIR}/.openclaw"

if [ -d "$EFS_DIR" ] && mountpoint -q "$EFS_DIR" 2>/dev/null; then
  echo "entrypoint: EFS detected at $EFS_DIR — linking .openclaw directory"

  # Create .openclaw directory on EFS if it doesn't exist
  mkdir -p "$EFS_OPENCLAW_DIR"
  # Ensure strict permissions on the state dir
  if [ "$(id -u)" = "0" ]; then
    chown node:node "$EFS_OPENCLAW_DIR"
  fi
  chmod 700 "$EFS_OPENCLAW_DIR" 2>/dev/null || true
  # Remove the baked-in .openclaw directory from the image
  rm -rf "$OPENCLAW_DIR"

  # Symlink so openclaw reads/writes to EFS transparently
  ln -sfn "$EFS_OPENCLAW_DIR" "$OPENCLAW_DIR"

  echo "entrypoint: $OPENCLAW_DIR linked to $EFS_OPENCLAW_DIR for persistence"
else
  echo "entrypoint: no EFS mount at $EFS_DIR"
  echo "entrypoint: using local $OPENCLAW_DIR"
fi

# Copy completions directory into local .openclaw
if [ -d "/home/node/src/openclaw/completions" ]; then
  cp -r /home/node/src/openclaw/completions "$OPENCLAW_DIR/"
fi

# Copy each subfolder from /home/node/src/openclaw/extensions to $OPENCLAW_DIR/extensions
if [ -d "/home/node/src/openclaw/extensions" ]; then
  mkdir -p "$OPENCLAW_DIR/extensions"
  for ext_dir in /home/node/src/openclaw/extensions/*/; do
    if [ -d "$ext_dir" ]; then
      ext_name=$(basename "$ext_dir")
      echo "entrypoint: copying extension $ext_name to $OPENCLAW_DIR/extensions/"
      rm -rf "$OPENCLAW_DIR/extensions/$ext_name"
      cp -r "$ext_dir" "$OPENCLAW_DIR/extensions/$ext_name"
    fi
  done
fi

# Map secrets to the env vars openclaw expects
export CHANNELS__SLACK__TOKEN="${CHANNELS__SLACK__TOKEN:-$SLACK_BOT_TOKEN}"
export OPENAI_DEFAULT_MODEL="openai/gpt-5.2"
export OPENAI_CODING_MODEL="openai/gpt-5.1-codex"

# Hand off to the original CMD
exec "$@"
