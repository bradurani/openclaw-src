#!/bin/sh

# entrypoint.sh - Merge image config with EFS persistent state
#
# On ECS the EFS volume is mounted at /data. This script symlinks
# /home/node/.openclaw -> /data/.openclaw, copies completions/extensions/patches
# from the image, applies config patches, and then execs the main process.
# Locally (no /data mount) everything stays in ~/.openclaw as-is.
#
# NOTE: Changes to this file trigger a deploy via CI.

set -e

OPENCLAW_DIR="/home/node/.openclaw"
EFS_DIR="${EFS_MOUNT_PATH:-/data}"
EFS_OPENCLAW_DIR="${EFS_DIR}/.openclaw"

if [ -d "$EFS_DIR" ] && mountpoint -q "$EFS_DIR" 2>/dev/null; then
  echo "entrypoint: EFS detected at $EFS_DIR"

  mkdir -p "$EFS_OPENCLAW_DIR"
  chmod 700 "$EFS_OPENCLAW_DIR" 2>/dev/null || true

  # Symlink ~/.openclaw to the EFS-backed directory
  rm -rf "$OPENCLAW_DIR"
  ln -sfn "$EFS_OPENCLAW_DIR" "$OPENCLAW_DIR"

  echo "entrypoint: $OPENCLAW_DIR -> $EFS_OPENCLAW_DIR"
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
