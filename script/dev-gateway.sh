#!/bin/bash
# Build the gateway image and run gateway and local CLI containers
set -e

IMAGE_NAME=openclaw-src:local
COMPOSE_FILE=../docker-compose.yml

# Build the gateway image
cd ..
echo "Building Docker image: $IMAGE_NAME"
docker build -t $IMAGE_NAME .

# Start the gateway container

echo "Starting openclaw-gateway container..."
docker compose -f $COMPOSE_FILE up -d openclaw-gateway

# Run the local CLI container interactively

echo "Running openclaw-cli container..."
docker compose -f $COMPOSE_FILE run --rm openclaw-cli

# Show status

echo "Gateway and CLI containers are running."
