# AgentDock — Requirements & Vision

This document captures all requirements and ideas from the initial project conception.
It serves as the source of truth for what AgentDock is, what it must do, and what
future directions are planned.

---

## Core Goal

An **always-on, self-hosted Claude Code agent** running in Docker, independent of any
single machine (no requirement for the user's main PC to be on). The agent must be
reachable and controllable from anywhere — via phone, tablet, or any device — using
native Claude tooling or messaging platforms.

Target deployment: a thin client or VPS running Docker (alongside services like
Immich, Paperless, etc.), managed via Portainer.

---

## Remote Access — Requirements

### Primary (native Claude)
- **Claude Code Channels** (Anthropic research preview as of March 2026):
  two-way Telegram and Discord integration built into Claude Code
- Claude CoWork dispatch from the Claude mobile/desktop app (if compatible
  with headless/remote sessions — to be verified)

### Secondary (optional integrations)
- Open-WebUI as a chat interface (future consideration)
- Generic bridge options (Telegram/Discord bots) as fallback

### Non-goals for remote access
- No open inbound ports — Telegram/Discord use outbound polling only
- No VPN or tunnel required for basic operation

---

## Docker & Distribution — Requirements

### Image variants
- Arch Linux (default, user preference) → `latest` and `:arch` tags
- Debian bookworm-slim → `:debian`
- Ubuntu 24.04 → `:ubuntu`
- Alpine 3.21 → `:alpine`

### Tag scheme
```
latest                  → most recent release, Arch Linux
arch                    → most recent release, Arch Linux
debian                  → most recent release, Debian
1.2.3-arch              → pinned AgentDock version, Arch Linux
1.2.3-debian            → pinned AgentDock version, Debian
```
Version format: `MAJOR.MINOR.PATCH` (semantic versioning on AgentDock itself).

### Multi-architecture
- `linux/amd64` for all platforms
- `linux/arm64` for Debian, Ubuntu, Alpine (Arch Linux has no arm64 base image)

### Registry
- GitHub Container Registry (GHCR): `ghcr.io/serraniel/agentdock`

---

## GitHub Actions — Requirements

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `build.yml` | push to `v*` tag, manual | Build and push all platform images |
| `claude-update.yml` | daily cron (06:00 UTC) | Detect new `@anthropic-ai/claude-code` npm release, auto-tag new patch version |
| `base-update.yml` | weekly cron (Mon 07:00 UTC) | Detect base image digest changes, trigger rebuild |

Claude Code version in use is tracked in `.claude-version` for delta detection.
Base image digests are tracked in `.base-digests/<platform>`.

---

## Configuration — Requirements

### Principle: environment-variable-driven, volume-persisted

All runtime configuration comes from:
1. **Environment variables** — set at container startup (channel, tokens, git sync)
2. **Data volume** (`/data`) — persists auth, user config, projects, logs

No secrets or user config are baked into the image.

### First-run self-configuration
- Container detects missing auth and guides the user through `claude login`
- Default Claude settings and permissions are copied from the image to the volume
  on first run (volume config always takes precedence on subsequent starts)
- Git workspace is initialised automatically

### Configuration files (volume-scoped, user-editable)
- `/data/config/settings.json` — Claude Code permissions, MCP server definitions
- `/data/config/claude.json` — Claude project defaults

### Optional web UI
- Minimal status page (port 8080) for first-run auth guidance
- Enabled via `WEBUI_ENABLED=true`
- Not a full management interface — just a helper for the OAuth flow

---

## Security — Requirements

- **Non-root user**: Claude runs as `agentdock` (UID 1000)
- **No inbound ports**: only outbound connections to Telegram/Discord APIs
- **Channel allowlist**: only the paired account can send commands; unpaired
  senders are silently ignored (enforced by Claude Code Channels)
- **Permission blocklist**: `sudo`, `su`, piped curl/wget installs, chmod 777
  are blocked by default in `settings.json`
- **System immutability**: Claude must not modify system configuration without
  explicit permission. Only `/data` (the volume) is the writable surface.
- **Resilience requirement**: the data volume alone must be sufficient to
  reconstruct an identical agent setup on a new container. No state outside
  the volume.

---

## Persistent Data — Requirements

### Volume layout
```
/data/
  auth/
    credentials        ← claude.ai OAuth token (must survive restarts)
  config/
    settings.json      ← Claude permissions + MCP server config
    claude.json        ← Claude project defaults
  projects/
    workspace/         ← primary git-backed project workspace
  logs/
    auth.log
```

### Git-backed project workspaces
- Each project folder is a git repository
- Provides local history, diff browsing, recovery
- Workspace is pre-initialised on first run

### Optional remote git sync
- Projects can be pushed to GitHub, GitLab, Forgejo, or any git remote
- Configured via `GIT_SYNC_URL` + `GIT_SYNC_TOKEN` environment variables
- Git author identity configurable via `GIT_USER_NAME` / `GIT_USER_EMAIL`
- Sync is opt-in — works entirely local without it

---

## Software Installation — Requirements

- Claude must be able to install additional tools as needed during operation
- Installation must be scoped to the data volume or user home directory
  (no system-wide changes)
- Additional MCP servers can be configured via `/data/config/settings.json`
- Future: consider an `EXTRA_PACKAGES` env var to pre-install tooling at
  container startup

---

## Synchronisation — Considered Approaches

Several synchronisation strategies were considered:

### A) Centralised (current approach)
The Docker container is the single source of truth. Data lives in `/data` volume.
Remote git sync is optional for backup/portability. **Selected for v1.0.**

### B) Federated (future consideration)
Each device runs an AgentDock instance. A shared git remote (GitHub, Forgejo, etc.)
or file sync (Nextcloud, Syncthing) keeps project workspaces in sync across devices.
Suitable if the user wants Claude available both on a VPS and a local machine with
different tool access.

### C) Local-primary with sync
Claude CoWork runs locally on the main machine with full software access (computer
use, local apps). AgentDock provides a sync layer for project history via git.
Tradeoff: still requires the main machine to be on for heavy tasks.

---

## Open Questions / Future Work

- [ ] **Claude CoWork compatibility**: verify whether Claude CoWork sessions can
      be hosted remotely (not just locally). May require Anthropic support.
- [ ] **Auth flow UX**: the current web UI is a static guidance page. A proper
      OAuth proxy that handles the callback and saves credentials automatically
      would improve first-run experience.
- [ ] **Open-WebUI integration**: optional chat interface as a sidecar container.
      Adds a web-based alternative to Telegram/Discord.
- [ ] **`EXTRA_PACKAGES` env var**: pre-install additional system tools at
      container startup for users who need e.g. Python, Rust, or specific CLIs.
- [ ] **Multi-workspace support**: allow multiple named git workspaces under
      `/data/projects/` selectable via channel commands.
- [ ] **Portainer stack template**: publish as a Portainer App Template for
      one-click deployment from the Portainer UI.
- [ ] **arm64 Arch support**: monitor the `archlinux` Docker Hub image for
      eventual arm64 support and re-enable when available.
- [ ] **Forgejo/Gitea self-hosted sync**: document setup for users running
      their own git server alongside AgentDock.
