# AgentDock — AI Agent Instructions

This file is the primary guide for an AI agent (e.g. Claude CoWork) deploying AgentDock
on a Docker host via Portainer or direct Docker access.

## What This Project Is

AgentDock runs Claude Code with Channels enabled inside a Docker container, giving you an
always-on AI coding agent reachable via Telegram or Discord from any device.

## Deploying via Portainer MCP

Use these steps in order. Each step tells you what to check before moving on.

### Step 1 — Prerequisites

Verify the Docker host has:
- Docker Engine running
- At least 1 GB free RAM
- Outbound internet access (for pulling the image and reaching Telegram/Discord)
- A volume directory the container can write to (e.g. `/opt/agentdock/data`)

```
# Check Docker is running
docker info

# Check free space
df -h /opt
```

### Step 2 — Create the data directory

```bash
mkdir -p /opt/agentdock/data
```

This directory persists across container restarts. It stores:
- `auth/credentials` — claude.ai OAuth token (required)
- `config/` — Claude settings and MCP configs
- `projects/workspace/` — git-backed project workspace
- `logs/` — audit log

### Step 3 — Create the Portainer stack

In Portainer → Stacks → Add Stack → Web editor, paste the following.
Fill in the environment variables before deploying.

```yaml
services:
  agentdock:
    image: ghcr.io/serraniel/agentdock:latest
    container_name: agentdock
    restart: unless-stopped
    environment:
      CHANNEL: telegram
      TELEGRAM_BOT_TOKEN: "YOUR_BOT_TOKEN_HERE"
      # DISCORD_BOT_TOKEN: "YOUR_DISCORD_TOKEN_HERE"
      WEBUI_ENABLED: "false"
      GIT_USER_NAME: "AgentDock"
      GIT_USER_EMAIL: "agentdock@localhost"
      # Optional — push projects to a remote git repo:
      # GIT_SYNC_URL: "https://github.com/youruser/yourrepo"
      # GIT_SYNC_TOKEN: "ghp_..."
    volumes:
      - /opt/agentdock/data:/data
    security_opt:
      - no-new-privileges:true
    tmpfs:
      - /tmp
```

Required variables to fill in:
- `TELEGRAM_BOT_TOKEN` — from @BotFather on Telegram (send `/newbot`)
- OR `DISCORD_BOT_TOKEN` + change `CHANNEL` to `discord`

### Step 4 — First-run authentication

AgentDock needs a claude.ai account linked once. After the container starts:

```bash
docker exec -it agentdock claude login
```

This prints a URL. Open it in a browser, log in with your claude.ai account,
and paste the confirmation code back into the terminal.

The credentials are saved to `/opt/agentdock/data/auth/credentials` and survive
container restarts. You will not need to repeat this step unless you delete the volume.

### Step 5 — Pair your Telegram account

1. Start the container (it will print a pairing code in the logs)
2. Open Telegram, send the pairing code to your bot
3. Only your paired account can send commands — all others are silently ignored

Check logs:
```bash
docker logs agentdock -f
```

### Step 6 — Verify

Send your Telegram bot:
```
Hello! What can you do?
```

Claude should respond with its capabilities.

---

## Configuration Reference

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `CHANNEL` | yes | `telegram` | `telegram`, `discord`, or `none` |
| `TELEGRAM_BOT_TOKEN` | if telegram | — | Token from @BotFather |
| `DISCORD_BOT_TOKEN` | if discord | — | Token from Discord Developer Portal |
| `WEBUI_ENABLED` | no | `false` | Show status page on port 8080 during first run |
| `WEBUI_PORT` | no | `8080` | Web UI port |
| `GIT_SYNC_URL` | no | — | Remote to push project workspace to |
| `GIT_SYNC_TOKEN` | no | — | Auth token for git sync |
| `GIT_USER_NAME` | no | `AgentDock` | Git author name |
| `GIT_USER_EMAIL` | no | `agentdock@localhost` | Git author email |

### Customising Claude's Permissions

Edit `/opt/agentdock/data/config/settings.json` (created on first run from defaults).
The default config allows: git, npm, node, file read/write.
The default config blocks: sudo, su, piped curl/wget installs.

To allow additional tools, add them to the `permissions.allow` array:
```json
{
  "permissions": {
    "allow": ["Bash(git:*)", "Bash(npm:*)", "Bash(python3:*)"]
  }
}
```

Restart the container after editing: `docker restart agentdock`

### Adding MCP Servers

Place MCP server config in `/opt/agentdock/data/config/settings.json` under the
`mcpServers` key (standard Claude Code MCP format). Restart the container to apply.

---

## Data Volume Layout

```
/opt/agentdock/data/
  auth/
    credentials          ← claude.ai OAuth token — BACK THIS UP
  config/
    settings.json        ← Claude Code settings (permissions, MCP servers)
    claude.json          ← Claude project config
  projects/
    workspace/           ← git repo — all work happens here
      .git/
  logs/
    auth.log             ← login flow log
```

The volume is the single source of truth. A new container with the same volume
restores the exact same agent setup automatically.

---

## Troubleshooting

**Container exits immediately**
→ Check logs: `docker logs agentdock`
→ Most likely: missing `TELEGRAM_BOT_TOKEN` or invalid `CHANNEL` value

**"No auth credentials" in logs**
→ Run: `docker exec -it agentdock claude login`

**Bot does not respond to messages**
→ Confirm pairing: the bot only responds to the paired account
→ Check the channel is connected: look for "Starting Claude Code with Telegram channel" in logs

**Container crashes after update**
→ The data volume is safe — restart with the same volume and re-authenticate if needed

---

## Image Tags

```
ghcr.io/serraniel/agentdock:latest      # Arch Linux, most recent release
ghcr.io/serraniel/agentdock:arch        # Arch Linux, most recent release
ghcr.io/serraniel/agentdock:debian      # Debian bookworm-slim
ghcr.io/serraniel/agentdock:ubuntu      # Ubuntu 24.04
ghcr.io/serraniel/agentdock:alpine      # Alpine 3.21 (smallest image)
ghcr.io/serraniel/agentdock:0.1.0-arch  # Pinned version
```

---

## Project Structure (for contributors)

```
AgentDock/
  docker/
    arch/Dockerfile      ← Arch Linux image (default/latest)
    debian/Dockerfile    ← Debian image
    ubuntu/Dockerfile    ← Ubuntu image
    alpine/Dockerfile    ← Alpine image
  scripts/
    entrypoint.sh        ← Container startup logic
    healthcheck.sh       ← Docker HEALTHCHECK target
    webui.sh             ← Minimal first-run status page
  config/
    settings.json        ← Default Claude permissions (copied to volume on first run)
    claude.json          ← Default Claude project config
  .github/workflows/
    build.yml            ← Build all images on git tag
    claude-update.yml    ← Daily: auto-tag on new Claude Code npm release
    base-update.yml      ← Weekly: rebuild on base image digest change
  docker-compose.yml     ← Compose file for standalone deployment
  .env.example           ← All environment variables documented
```
