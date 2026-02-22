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
PERSISTENT_DIRS="sessions logs workspace credentials cron identity"

if [ -d "$EFS_DIR" ] && mountpoint -q "$EFS_DIR" 2>/dev/null; then
  echo "entrypoint: EFS detected at $EFS_DIR — linking persistent state"

  for dir in $PERSISTENT_DIRS; do
    efs_path="${EFS_DIR}/${dir}"
    local_path="${OPENCLAW_DIR}/${dir}"

    # Create directory on EFS if it doesn't exist yet
    mkdir -p "$efs_path"

    # Remove the baked-in directory (or placeholder) from the image
    rm -rf "$local_path"

    # Symlink so openclaw reads/writes to EFS transparently
    ln -sfn "$efs_path" "$local_path"

    echo "entrypoint:   ${dir}/ -> ${efs_path}"
  done
else
  echo "entrypoint: no EFS mount at $EFS_DIR — running with local state"
fi

# Hand off to the original CMD
exec "$@"
