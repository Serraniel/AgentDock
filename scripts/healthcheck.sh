#!/bin/bash
# Verify claude binary is reachable and auth credentials exist
export PATH="/root/.bun/bin:/usr/local/bin:$PATH"

AUTH_DIR="${DATA_DIR:-/data}/auth"

if ! command -v claude &>/dev/null; then
  echo "UNHEALTHY: claude binary not found"
  exit 1
fi

if [ ! -f "$AUTH_DIR/credentials" ] && [ ! -f "$HOME/.claude/credentials" ]; then
  echo "UNHEALTHY: no auth credentials — awaiting first-run authentication"
  exit 1
fi

echo "HEALTHY"
exit 0
