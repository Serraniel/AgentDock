# Changelog

All notable changes to AgentDock are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
AgentDock uses [Semantic Versioning](https://semver.org/).

Image tag format: `MAJOR.MINOR.PATCH-platform` (e.g. `1.0.0-arch`)

---

## [Unreleased]

### Added
- Initial project scaffold
- Multi-platform Dockerfiles: Arch Linux, Debian, Ubuntu, Alpine
- Entrypoint with channel auto-configuration via environment variables
- Persistent data volume layout: auth, config, projects, logs
- Git-backed project workspace initialisation
- Optional git remote sync (GitHub, GitLab, Forgejo)
- GitHub Actions: build workflow with multi-arch (amd64 + arm64) support
- GitHub Actions: daily Claude Code version check and auto-tag
- GitHub Actions: weekly base image digest check and rebuild trigger
- Security: non-root user, blocked sudo/system commands in default config
- Web UI stub for first-run auth guidance
