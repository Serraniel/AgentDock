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

# Determine and apply authentication.
# Priority:
#   1. ANTHROPIC_API_KEY env var  → API key auth (no login needed, ToS-compliant for automation)
#   2. Existing credentials file  → restore previous OAuth session
#   3. AUTH_MODE=console          → interactive Anthropic Console OAuth (API billing)
#   4. AUTH_MODE=subscription     → interactive claude.ai subscription OAuth
#   5. Default fallback           → console OAuth (same as 3)
setup_auth() {
  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    echo "[agentdock] Auth: ANTHROPIC_API_KEY detected — using API key (Anthropic Console billing)."
    echo "[agentdock] No login required."
    return 0
  fi

  if restore_auth; then
    return 0
  fi

  echo "[agentdock] No auth credentials found. Starting first-run authentication..."
  echo ""

  if [ "$WEBUI_ENABLED" = "true" ]; then
    echo "[agentdock] Web UI enabled — open http://<host>:${WEBUI_PORT} for guidance."
    /scripts/webui.sh "$WEBUI_PORT" &
    WEBUI_PID=$!
  fi

  case "${AUTH_MODE:-console}" in
    apikey)
      echo "[agentdock] ERROR: AUTH_MODE=apikey requires ANTHROPIC_API_KEY to be set."
      exit 1
      ;;
    console)
      echo "[agentdock] Auth mode: Anthropic Console (API billing — recommended for automation)."
      echo "[agentdock] See docs/tos-compliance.md for guidance."
      claude auth login --console 2>&1 | tee "$LOGS_DIR/auth.log"
      ;;
    subscription)
      echo "[agentdock] Auth mode: claude.ai subscription."
      echo "[agentdock] WARNING: Subscription plans are designed for interactive personal use."
      echo "[agentdock] For always-on automated agents, ANTHROPIC_API_KEY is recommended."
      echo "[agentdock] See docs/tos-compliance.md for details."
      claude auth login --claudeai 2>&1 | tee "$LOGS_DIR/auth.log"
      ;;
    *)
      echo "[agentdock] Unknown AUTH_MODE '${AUTH_MODE}'. Valid: apikey, console, subscription."
      exit 1
      ;;
  esac

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

# Detect whether the installed claude binary supports native Channels.
# Returns 0 (true) if supported, 1 (false) if not.
has_native_channel_support() {
  claude --help 2>&1 | grep -q -- '--channel'
}

start_channel() {
  case "$CHANNEL" in
    telegram)
      if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
        echo "[agentdock] ERROR: TELEGRAM_BOT_TOKEN is required for channel=telegram"
        exit 1
      fi
      if has_native_channel_support; then
        echo "[agentdock] Native Channels detected — starting claude --channel telegram"
        exec claude --channel telegram
      else
        echo "[agentdock] Native Channels not available in this Claude Code version."
        echo "[agentdock] Starting fallback Telegram bot (claude --print mode)..."
        echo "[agentdock] NOTE: Session context is not preserved between messages in fallback mode."
        exec bun run /scripts/telegram-fallback.ts
      fi
      ;;
    discord)
      if [ -z "${DISCORD_BOT_TOKEN:-}" ]; then
        echo "[agentdock] ERROR: DISCORD_BOT_TOKEN is required for channel=discord"
        exit 1
      fi
      if has_native_channel_support; then
        echo "[agentdock] Native Channels detected — starting claude --channel discord"
        exec claude --channel discord
      else
        echo "[agentdock] Native Channels not available in this Claude Code version."
        echo "[agentdock] Starting fallback Discord bot (claude --print mode)..."
        echo "[agentdock] NOTE: Session context is not preserved between messages in fallback mode."
        echo "[agentdock] NOTE: Set DISCORD_CHANNEL_ID to restrict the bot to one channel."
        exec bun run /scripts/discord-fallback.ts
      fi
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
setup_auth
start_channel
