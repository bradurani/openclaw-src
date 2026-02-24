#!/bin/bash
# Test a websocket connection to the local openclaw-gateway

GATEWAY_URL="ws://localhost:18789"

# Use websocat if available
if command -v websocat >/dev/null 2>&1; then
  echo "Testing WebSocket connection to $GATEWAY_URL using websocat..."
  websocat "$GATEWAY_URL"
else
  echo "websocat not found. Install with: brew install websocat"
fi
