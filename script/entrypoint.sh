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

# Extensions are baked into the image under /home/node/src/openclaw/extensions.
# Do NOT copy them into the persistent state dir ($OPENCLAW_DIR/extensions), otherwise
# they are treated as untracked local code and can trigger plugin provenance warnings.
#
# Instead, for baked-in plugins we want to use *tracked installs* so OpenClaw records
# provenance under plugins.installs. The install target here is a local directory
# in the image (not the npm registry).

# Ensure memory-pgvector is installed (tracked) into the persistent state dir.
# This is idempotent: if an install record already exists, we skip.
if [ -d "/home/node/src/openclaw/extensions/memory-pgvector" ]; then
  INSTALLED=$(node - <<'NODE'
const fs = require('fs');
try {
  const p = process.env.HOME + '/.openclaw/openclaw.json';
  const j = JSON.parse(fs.readFileSync(p, 'utf8'));
  const ok = !!(j.plugins && j.plugins.installs && j.plugins.installs['memory-pgvector']);
  process.stdout.write(ok ? '1' : '0');
} catch {
  process.stdout.write('0');
}
NODE
)

  if [ "$INSTALLED" != "1" ]; then
    echo "entrypoint: installing tracked plugin memory-pgvector into state dir"
    node openclaw.mjs plugins install /home/node/src/openclaw/extensions/memory-pgvector
  fi
fi

# Map secrets to the env vars openclaw expects
export CHANNELS__SLACK__TOKEN="${CHANNELS__SLACK__TOKEN:-$SLACK_BOT_TOKEN}"
export OPENAI_DEFAULT_MODEL="openai/gpt-5.2"
export OPENAI_CODING_MODEL="openai/gpt-5.1-codex"

# Hand off to the original CMD
exec "$@"
