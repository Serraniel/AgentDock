#!/bin/bash
set -euo pipefail

export PATH="/root/.bun/bin:/usr/local/bin:$PATH"

DATA_DIR="${DATA_DIR:-/data}"
AUTH_DIR="$DATA_DIR/auth"
CONFIG_DIR="$DATA_DIR/config"
PROJECTS_DIR="$DATA_DIR/projects"
LOGS_DIR="$DATA_DIR/logs"

CHANNEL="${CHANNEL:-telegram}"
WEBUI_ENABLED="${WEBUI_ENABLED:-false}"
WEBUI_PORT="${WEBUI_PORT:-8080}"

mkdir -p "$AUTH_DIR" "$CONFIG_DIR" "$PROJECTS_DIR" "$LOGS_DIR"

apply_claude_config() {
  local target="$HOME/.claude.json"
  if [ -f "$CONFIG_DIR/claude.json" ]; then
    cp "$CONFIG_DIR/claude.json" "$target"
  elif [ -f "/etc/agentdock/claude.json" ]; then
    cp "/etc/agentdock/claude.json" "$target"
  fi

  local settings_target="$HOME/.claude/settings.json"
  mkdir -p "$HOME/.claude"
  if [ -f "$CONFIG_DIR/settings.json" ]; then
    cp "$CONFIG_DIR/settings.json" "$settings_target"
  elif [ -f "/etc/agentdock/settings.json" ]; then
    cp "/etc/agentdock/settings.json" "$settings_target"
  fi
}

restore_auth() {
  if [ -f "$AUTH_DIR/credentials" ]; then
    mkdir -p "$HOME/.claude"
    cp "$AUTH_DIR/credentials" "$HOME/.claude/credentials"
    echo "[agentdock] Auth credentials restored from volume."
    return 0
  fi
  return 1
}

persist_auth() {
  if [ -f "$HOME/.claude/credentials" ]; then
    cp "$HOME/.claude/credentials" "$AUTH_DIR/credentials"
    echo "[agentdock] Auth credentials persisted to volume."
  fi
}

wait_for_auth() {
  echo "[agentdock] No auth credentials found in $AUTH_DIR."
  echo "[agentdock] Starting first-run authentication..."
  echo ""
  if [ "$WEBUI_ENABLED" = "true" ]; then
    echo "[agentdock] Web UI enabled — open http://<host>:${WEBUI_PORT} to complete authentication."
    /scripts/webui.sh "$WEBUI_PORT" &
    WEBUI_PID=$!
  fi

  # Run interactive login; output goes to both terminal and log
  claude login 2>&1 | tee "$LOGS_DIR/auth.log"

  persist_auth

  if [ "${WEBUI_ENABLED:-false}" = "true" ] && [ -n "${WEBUI_PID:-}" ]; then
    kill "$WEBUI_PID" 2>/dev/null || true
  fi
}

setup_git_sync() {
  if [ -z "${GIT_SYNC_URL:-}" ]; then
    return
  fi

  echo "[agentdock] Configuring git sync to $GIT_SYNC_URL..."
  git config --global credential.helper store

  if [ -n "${GIT_SYNC_TOKEN:-}" ]; then
    local proto host
    proto=$(echo "$GIT_SYNC_URL" | sed 's|://.*||')
    host=$(echo "$GIT_SYNC_URL" | sed 's|.*://||' | sed 's|/.*||')
    echo "${proto}://agentdock:${GIT_SYNC_TOKEN}@${host}" > "$HOME/.git-credentials"
  fi

  if [ -n "${GIT_USER_NAME:-}" ]; then
    git config --global user.name "$GIT_USER_NAME"
  fi
  if [ -n "${GIT_USER_EMAIL:-}" ]; then
    git config --global user.email "$GIT_USER_EMAIL"
  fi
}

init_project_workspace() {
  local workspace="$PROJECTS_DIR/workspace"
  if [ ! -d "$workspace/.git" ]; then
    mkdir -p "$workspace"
    git -C "$workspace" init
    echo "[agentdock] Initialized project workspace at $workspace"
  fi
  cd "$workspace"
}

start_channel() {
  case "$CHANNEL" in
    telegram)
      if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
        echo "[agentdock] ERROR: TELEGRAM_BOT_TOKEN is required for channel=telegram"
        exit 1
      fi
      echo "[agentdock] Starting Claude Code with Telegram channel..."
      exec claude --channel telegram
      ;;
    discord)
      if [ -z "${DISCORD_BOT_TOKEN:-}" ]; then
        echo "[agentdock] ERROR: DISCORD_BOT_TOKEN is required for channel=discord"
        exit 1
      fi
      echo "[agentdock] Starting Claude Code with Discord channel..."
      exec claude --channel discord
      ;;
    none|"")
      echo "[agentdock] No channel configured — starting interactive Claude Code session."
      exec claude
      ;;
    *)
      echo "[agentdock] ERROR: Unknown channel '$CHANNEL'. Valid values: telegram, discord, none"
      exit 1
      ;;
  esac
}

echo "[agentdock] AgentDock starting..."
echo "[agentdock] Channel: $CHANNEL"
echo "[agentdock] Data dir: $DATA_DIR"

apply_claude_config
setup_git_sync
init_project_workspace

if ! restore_auth; then
  wait_for_auth
fi

start_channel
