# AgentDock

An always-on, self-hosted Claude Code agent running in Docker. Control it from anywhere via Telegram or Discord using [Claude Code Channels](https://docs.anthropic.com/en/docs/claude-code/channels).

**AgentDock is an independent community project and is not affiliated with or endorsed by Anthropic PBC.**
Using AgentDock requires your own Anthropic account. For automated/always-on deployments, an
[Anthropic Console API key](https://console.anthropic.com) is recommended — see [docs/tos-compliance.md](docs/tos-compliance.md).

AgentDock runs Claude Code on your own infrastructure — a VPS, NAS, thin client, or any Docker host — so your AI coding agent is reachable from your phone or any device, independent of your main machine.

## Features

- **Claude Code Channels** — two-way Telegram and Discord integration
- **Multi-platform images** — Arch Linux (default), Debian, Ubuntu, Alpine
- **Persistent data volume** — auth, config, and projects survive container restarts
- **Git-backed projects** — each workspace is a git repository with full history
- **Optional remote sync** — push projects to GitHub, GitLab, Forgejo, etc.
- **Auto-updates** — GitHub Actions rebuild images on new Claude Code and base image releases
- **Security-first** — non-root user, no inbound ports, allowlist-only channel access

## Quick Start

### 1. Prerequisites

- Docker and Docker Compose
- An Anthropic account — either:
  - **Recommended:** [Anthropic Console](https://console.anthropic.com) API key (pay-per-use, ToS-compliant for automation)
  - **Alternative:** [claude.ai](https://claude.ai) Pro/Max subscription (personal interactive use)
- A Telegram bot token from [@BotFather](https://t.me/BotFather) or a Discord bot token

### 2. Configure

```bash
cp .env.example .env
# Set ANTHROPIC_API_KEY, CHANNEL, and TELEGRAM_BOT_TOKEN (or DISCORD_BOT_TOKEN)
```

### 3. Start

```bash
docker compose up -d
docker logs agentdock -f
```

**If using an API key** (`ANTHROPIC_API_KEY` set in `.env`): no login step needed — skip to step 4.

**If using OAuth**: on first run, authenticate inside the container:

```bash
# Recommended — Anthropic Console (API billing, ToS-compliant for automation):
docker exec -it agentdock claude auth login --console

# Alternative — claude.ai subscription (personal interactive use only):
docker exec -it agentdock claude auth login --claudeai
```

Follow the URL, log in, paste the code back. Credentials are saved to your data volume and not needed again.

### 4. Pair your Telegram / Discord account

When Claude Code starts with the channel, it prints a pairing code. Send that code to your bot on Telegram (or Discord) to link your account. Only paired accounts can send commands.

### 5. Test it

Send your bot a message:

```
Create a file called hello.txt with the content "AgentDock is alive"
```

## Image Tags

Images are published to `ghcr.io/serraniel/agentdock`.

| Tag | Description |
|-----|-------------|
| `latest` | Latest release, Arch Linux base |
| `arch` | Latest release, Arch Linux base |
| `debian` | Latest release, Debian bookworm-slim base |
| `ubuntu` | Latest release, Ubuntu 24.04 base |
| `alpine` | Latest release, Alpine 3.21 base |
| `1.2.3-arch` | Specific AgentDock version, Arch Linux |
| `1.2.3-debian` | Specific AgentDock version, Debian |

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `CHANNEL` | yes | `telegram` | `telegram`, `discord`, or `none` |
| `TELEGRAM_BOT_TOKEN` | if telegram | — | Bot token from @BotFather |
| `DISCORD_BOT_TOKEN` | if discord | — | Bot token from Discord Developer Portal |
| `DATA_PATH` | no | `./agentdock-data` | Host path for persistent data volume |
| `WEBUI_ENABLED` | no | `false` | Expose a status page on first run |
| `WEBUI_PORT` | no | `8080` | Port for the web UI |
| `GIT_SYNC_URL` | no | — | Remote URL for project workspace sync |
| `GIT_SYNC_TOKEN` | no | — | Auth token for git sync |
| `GIT_USER_NAME` | no | `AgentDock` | Git author name |
| `GIT_USER_EMAIL` | no | `agentdock@localhost` | Git author email |

## Data Volume Layout

```
agentdock-data/
  auth/         # claude.ai credentials (back this up)
  config/       # claude settings, MCP configs — edit to customise
  projects/     # git-backed project workspaces
  logs/         # audit log
```

The data volume is the single source of truth. A fresh container with the same volume re-creates an identical agent setup.

## Security

- Claude runs as non-root user `agentdock` (UID 1000)
- No inbound ports required (Telegram/Discord use outbound polling)
- Channel access is allowlist-only — only your paired account can send commands
- `sudo` and system-level commands are blocked in the default permission config
- Only `/data` is writable; system paths are read-only

## Development

```bash
# Build locally (Arch image)
docker build -f docker/arch/Dockerfile -t agentdock:local .

# Run with local build
docker compose -f docker-compose.yml up
```

## License

MIT
