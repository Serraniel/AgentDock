#!/usr/bin/env bun
/**
 * Interim Discord channel for AgentDock.
 *
 * Discord requires a persistent WebSocket gateway connection — unlike Telegram
 * there is no long-polling REST alternative. This script opens the Gateway,
 * listens for messages in a configured channel, and forwards them to
 * `claude --print`. Only the paired user ID can send commands.
 *
 * Required env vars:
 *   DISCORD_BOT_TOKEN     — bot token from Discord Developer Portal
 *   DISCORD_CHANNEL_ID    — text channel ID the bot should listen in
 *   DISCORD_ALLOWED_USER  — Discord user ID allowed to send commands
 *                           (if empty, prints a pairing code on first message)
 */

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "fs";

const TOKEN = process.env.DISCORD_BOT_TOKEN;
const DATA_DIR = process.env.DATA_DIR || "/data";
const WORKSPACE_DIR = `${DATA_DIR}/projects/workspace`;
const PAIRING_FILE = `${DATA_DIR}/auth/discord-pairing.json`;

const CHANNEL_ID = process.env.DISCORD_CHANNEL_ID ?? "";
const DISCORD_API = "https://discord.com/api/v10";

// ---------------------------------------------------------------------------
// Pairing
// ---------------------------------------------------------------------------

interface PairingState {
  userId: string;
  username?: string;
}

function loadPairing(): PairingState | null {
  if (!existsSync(PAIRING_FILE)) return null;
  return JSON.parse(readFileSync(PAIRING_FILE, "utf8"));
}

function savePairing(state: PairingState): void {
  mkdirSync(`${DATA_DIR}/auth`, { recursive: true });
  writeFileSync(PAIRING_FILE, JSON.stringify(state, null, 2));
}

function generatePairingCode(): string {
  return Math.random().toString(36).substring(2, 8).toUpperCase();
}

// ---------------------------------------------------------------------------
// Discord REST helper
// ---------------------------------------------------------------------------

async function discordPost(path: string, body: Record<string, unknown>): Promise<any> {
  const res = await fetch(`${DISCORD_API}${path}`, {
    method: "POST",
    headers: {
      Authorization: `Bot ${TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  return res.json();
}

async function sendMessage(channelId: string, content: string): Promise<void> {
  for (let i = 0; i < content.length; i += 2000) {
    await discordPost(`/channels/${channelId}/messages`, {
      content: content.slice(i, i + 2000),
    });
  }
}

// ---------------------------------------------------------------------------
// Claude Code invocation
// ---------------------------------------------------------------------------

async function runClaude(prompt: string): Promise<string> {
  const proc = Bun.spawn(
    ["claude", "--print", "--dangerously-skip-permissions", prompt],
    {
      cwd: WORKSPACE_DIR,
      env: { ...process.env },
      stdout: "pipe",
      stderr: "pipe",
    }
  );

  const [stdout, stderr] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);

  const code = await proc.exited;

  if (code !== 0 && !stdout.trim()) {
    return `Error (exit ${code}):\n${stderr.trim() || "no output"}`;
  }

  return stdout.trim() || "(no output)";
}

// ---------------------------------------------------------------------------
// Discord Gateway (WebSocket)
// ---------------------------------------------------------------------------

const GATEWAY_INTENTS = 1 << 9; // GUILD_MESSAGES
const GATEWAY_INTENTS_WITH_CONTENT = GATEWAY_INTENTS | (1 << 15); // MESSAGE_CONTENT

async function connectGateway(): Promise<void> {
  const gwRes = await fetch(`${DISCORD_API}/gateway`, {
    headers: { Authorization: `Bot ${TOKEN}` },
  });
  const { url } = (await gwRes.json()) as { url: string };
  const ws = new WebSocket(`${url}?v=10&encoding=json`);

  let heartbeatInterval: Timer | null = null;
  let seq: number | null = null;
  let paired = loadPairing();
  let pairingCode: string | null = null;

  if (paired) {
    console.log(`[discord] Paired with user ${paired.userId} (@${paired.username ?? "?"})`);
  } else {
    pairingCode = generatePairingCode();
    console.log("[discord] ─────────────────────────────────────────");
    console.log("[discord] No paired account found.");
    console.log("[discord] Post this code in the bot's channel to pair:");
    console.log(`[discord]   ${pairingCode}`);
    console.log("[discord] ─────────────────────────────────────────");
  }

  ws.onmessage = async (event) => {
    const payload = JSON.parse(event.data as string);
    const { op, d, s, t } = payload;
    if (s !== null) seq = s;

    switch (op) {
      case 10: // Hello
        heartbeatInterval = setInterval(() => {
          ws.send(JSON.stringify({ op: 1, d: seq }));
        }, d.heartbeat_interval);

        ws.send(
          JSON.stringify({
            op: 2, // Identify
            d: {
              token: TOKEN,
              intents: GATEWAY_INTENTS_WITH_CONTENT,
              properties: { os: "linux", browser: "agentdock", device: "agentdock" },
            },
          })
        );
        break;

      case 0: // Dispatch
        if (t === "MESSAGE_CREATE") {
          const msg = d;
          if (msg.author.bot) return;
          if (CHANNEL_ID && msg.channel_id !== CHANNEL_ID) return;

          const userId: string = msg.author.id;
          const channelId: string = msg.channel_id;
          const text: string = msg.content?.trim() ?? "";
          if (!text) return;

          if (!paired) {
            if (text === pairingCode) {
              const state: PairingState = { userId, username: msg.author.username };
              savePairing(state);
              paired = state;
              pairingCode = null;
              console.log(`[discord] Paired with user ${userId} (@${msg.author.username})`);
              await sendMessage(channelId, "Paired successfully. You can now send commands to Claude Code.");
            }
            return;
          }

          if (userId !== paired.userId) return;

          console.log(`[discord] → ${text.substring(0, 100)}${text.length > 100 ? "…" : ""}`);
          await sendMessage(channelId, "Working on it…");

          const response = await runClaude(text);
          await sendMessage(channelId, response);
          console.log(`[discord] ← ${response.length} chars`);
        }
        break;
    }
  };

  ws.onclose = (event) => {
    if (heartbeatInterval) clearInterval(heartbeatInterval);
    console.log(`[discord] WebSocket closed (${event.code}), reconnecting in 5s…`);
    setTimeout(connectGateway, 5_000);
  };

  ws.onerror = (err) => {
    console.error("[discord] WebSocket error:", err);
  };
}

async function main(): Promise<void> {
  if (!TOKEN) {
    console.error("[discord] DISCORD_BOT_TOKEN is not set — cannot start fallback channel.");
    process.exit(1);
  }

  if (!CHANNEL_ID) {
    console.warn("[discord] DISCORD_CHANNEL_ID not set — bot will respond in any channel it can read.");
  }

  console.log("[discord] Connecting to Discord Gateway…");
  await connectGateway();
}

main().catch((err) => {
  console.error("[discord] Fatal:", err);
  process.exit(1);
});
