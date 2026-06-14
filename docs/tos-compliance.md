# AgentDock — Legal Compliance Guide

This document covers trademark considerations and Anthropic Terms of Service
compliance for deploying and using AgentDock.

---

## Trademark Notice

AgentDock is an **independent, community project**. It is not affiliated with,
endorsed by, or sponsored by Anthropic PBC.

- "Claude" and "Anthropic" are trademarks of Anthropic PBC.
- AgentDock does not include the words "Claude" or "Anthropic" in its name.
- AgentDock uses Claude Code (the CLI tool published by Anthropic) as a runtime
  dependency, in the same way any developer tool might use another CLI tool.
- Referencing these names in documentation for compatibility purposes (e.g.
  "requires a Claude Code subscription") is nominative fair use, not trademark
  infringement.

---

## Anthropic Terms of Service — What You Need to Know

### The two billing models and what they allow

Anthropic offers two ways to access Claude programmatically:

#### 1. Anthropic Console (API) — Recommended for AgentDock

- Sign up at console.anthropic.com
- Pay-per-use based on token consumption
- Explicitly designed for developers building applications and automations
- Set `ANTHROPIC_API_KEY` in AgentDock's environment — no OAuth login required
- **This is the clearly ToS-compliant path for running an always-on automated agent**

#### 2. claude.ai Subscription (Pro / Max / Team)

- Monthly subscription for interactive personal use via claude.ai
- Claude Code supports this via `claude auth login --claudeai`
- The subscription ToS is written for **individual, interactive use**
- Running AgentDock as an always-on automated bot on your subscription is a
  **grey area** — Anthropic has not explicitly prohibited personal automation,
  but the intent of the subscription product is interactive use
- If you use a subscription, you are responsible for reviewing
  [Anthropic's usage policies](https://www.anthropic.com/legal/usage-policy)
  and ensuring your use case is permitted under your plan

### AgentDock's design decisions for compliance

| Concern | How AgentDock addresses it |
|---------|---------------------------|
| Account sharing | Enforced single-user pairing — only ONE Telegram/Discord account can control the bot; the credentials are yours alone |
| Providing Claude access to others | Not possible by design — allowlist allows only the paired account |
| Commercial resale of Claude access | AgentDock has no mechanism for this; the project does not monetize API access |
| Automated usage without API billing | `ANTHROPIC_API_KEY` is the recommended and default-documented auth method |

---

## Recommended Setup (API Key)

Using an API key is the most ToS-compliant and operationally clean approach.
You pay only for what you use, and the usage falls clearly under API terms.

### Get an API key

1. Go to [console.anthropic.com](https://console.anthropic.com)
2. Create an account or log in
3. Navigate to **API Keys** → **Create Key**
4. Copy the key (starts with `sk-ant-...`)

### Configure AgentDock

```env
ANTHROPIC_API_KEY=sk-ant-...
```

Set this in your `.env` file or Portainer stack environment variables.
When `ANTHROPIC_API_KEY` is set, AgentDock skips the OAuth login flow entirely
and authenticates directly via the API key. No `claude login` step needed.

---

## Subscription Usage (Personal Use)

If you choose to use a claude.ai subscription instead of an API key:

- You must be the **sole user** of the AgentDock instance
- The paired Telegram/Discord account must be **your own personal account**
- Do not expose the container's control channel to other people
- Review your plan's terms at [claude.ai/settings](https://claude.ai/settings)
- Be aware that subscription plans may have **rate limits** that an always-on
  agent can hit; the API has separate, configurable rate limits

---

## Summary: Which Auth to Use

| Situation | Use |
|-----------|-----|
| Personal always-on agent for yourself | API key (Console) — recommended |
| Developer testing locally | Either works |
| Running on a shared or team server | API key (Console) only |
| Providing access to others | Not permitted under any plan |

---

## Upstream Licenses and Attributions

- **Claude Code** (`@anthropic-ai/claude-code`): proprietary, Anthropic PBC —
  installed at runtime, not bundled in this image
- **Bun**: MIT License
- **Node.js**: MIT License
- **Base images** (Arch Linux, Debian, Ubuntu, Alpine): their respective licenses
- **AgentDock scripts and configuration**: MIT License
