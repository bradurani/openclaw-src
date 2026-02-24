#!/bin/bash

# Load app secrets for local scripts (skip with OPENCLAW_SKIP_FETCH_ENV=1)
if [ -z "${OPENCLAW_SKIP_FETCH_ENV:-}" ] && [ -x "script/fetch-env" ]; then
  eval "$(script/fetch-env)"
fi
# Update and rebuild the openclaw:local base image from the latest main branch
set -e

OPENCLAW_DIR="../openclaw"
IMAGE_NAME="openclaw:local"

cd "$OPENCLAW_DIR"
echo "Pulling latest main branch in $OPENCLAW_DIR..."
git checkout main
git pull origin main

echo "Building Docker base image: $IMAGE_NAME"
docker build -t $IMAGE_NAME .

echo "Base image $IMAGE_NAME updated."
