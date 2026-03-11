#!/bin/sh

# entrypoint.sh - Merge image config with EFS persistent state
#
# On ECS the EFS volume is mounted at /data. The Docker image bakes a symlink
# /home/node/.openclaw -> /data/.openclaw so the root FS can be read-only.
# This script ensures the EFS target directory exists and copies completions,
# extensions, and config patches from the image staging area into EFS.
# Locally (no /data mount) everything stays in ~/.openclaw as-is.
#
# NOTE: Changes to this file trigger a deploy via CI.

set -e

OPENCLAW_DIR="${HOME}/.openclaw"
EFS_DIR="${EFS_MOUNT_PATH:-/data}"
EFS_OPENCLAW_DIR="${EFS_DIR}/.openclaw"

if [ -d "$EFS_DIR" ] && mountpoint -q "$EFS_DIR" 2>/dev/null; then
  echo "entrypoint: EFS detected at $EFS_DIR"

  # Create .openclaw directory on EFS if it doesn't exist.
  # The symlink /home/node/.openclaw -> /data/.openclaw is baked into the image
  # at build time so the root filesystem can stay read-only.
  mkdir -p "$EFS_OPENCLAW_DIR"
  # Ensure strict permissions on the state dir
  if [ "$(id -u)" = "0" ]; then
    chown node:node "$EFS_OPENCLAW_DIR"
  fi
  chmod 700 "$EFS_OPENCLAW_DIR" 2>/dev/null || true

  echo "entrypoint: $OPENCLAW_DIR -> $EFS_OPENCLAW_DIR (symlink baked in image)"
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

# ---------------------------------------------------------------------------
# Config patches — idempotent jq scripts applied to openclaw.json on startup.
# Patches live in config/patches/NNN-name.sh (baked into the image).
# A marker file on EFS tracks which patches have already been applied so each
# patch runs at most once per persistent volume.
# ---------------------------------------------------------------------------
PATCHES_DIR="/home/node/src/openclaw/config/patches"
PATCHES_APPLIED="${OPENCLAW_DIR}/.patches-applied"
CONFIG_FILE="${OPENCLAW_DIR}/openclaw.json"

if [ -d "$PATCHES_DIR" ] && [ -f "$CONFIG_FILE" ]; then
  touch "$PATCHES_APPLIED"
  for patch in "$PATCHES_DIR"/*.sh; do
    [ -f "$patch" ] || continue
    patch_name=$(basename "$patch")
    if grep -qxF "$patch_name" "$PATCHES_APPLIED"; then
      echo "entrypoint: patch $patch_name already applied"
    else
      echo "entrypoint: applying patch $patch_name"
      sh "$patch" "$CONFIG_FILE"
      echo "$patch_name" >> "$PATCHES_APPLIED"
      echo "entrypoint: patch $patch_name applied"
    fi
  done
fi

if [ "$#" -eq 0 ]; then
  echo "entrypoint: no command provided" >&2
  exit 1
fi

exec "$@"
