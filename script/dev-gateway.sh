#!/bin/bash

# Build the gateway image and run gateway and local CLI containers
set -e

IMAGE_NAME=openclaw-src:local
COMPOSE_FILE="docker-compose.yml"

# Build the gateway image
cd $(dirname "$0")/..  # Ensure we're in the openclaw-src directory
docker compose -f $COMPOSE_FILE build openclaw-gateway

# Start the gateway container

echo "Starting openclaw-gateway container..."
docker compose -f $COMPOSE_FILE up -d --force-recreate openclaw-gateway

# Run the local CLI container interactively

# echo "Running openclaw-cli container..."
# docker compose -f $COMPOSE_FILE run --rm -it openclaw-cli tui
