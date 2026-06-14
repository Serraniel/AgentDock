#!/usr/bin/env bun
/**
 * Interim Telegram channel for AgentDock.
 *
 * Used when the native `claude --channel telegram` flag is not yet available.
 * Long-polls the Telegram Bot API, forwards messages to `claude --print`,
 * and sends the response back. Only the paired user can send commands.
 *
 * Pairing: on first run, a code is printed to stdout. Send that code to the
 * bot in Telegram to link your account. State is saved in /data/auth/.
 */

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "fs";

const TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const DATA_DIR = process.env.DATA_DIR || "/data";
const WORKSPACE_DIR = `${DATA_DIR}/projects/workspace`;
const PAIRING_FILE = `${DATA_DIR}/auth/telegram-pairing.json`;
const API_BASE = `https://api.telegram.org/bot${TOKEN}`;

// ---------------------------------------------------------------------------
// Telegram API helpers
// ---------------------------------------------------------------------------

async function tgCall(method: string, body: Record<string, unknown> = {}): Promise<any> {
  const res = await fetch(`${API_BASE}/${method}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  return res.json();
}

async function sendMessage(chatId: number, text: string): Promise<void> {
  // Telegram caps messages at 4096 characters — split if needed
  for (let i = 0; i < text.length; i += 4000) {
    await tgCall("sendMessage", {
      chat_id: chatId,
      text: text.slice(i, i + 4000),
    });
  }
}

// ---------------------------------------------------------------------------
// Pairing
// ---------------------------------------------------------------------------

interface PairingState {
  userId: number;
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
// Main loop
// ---------------------------------------------------------------------------

async function main(): Promise<void> {
  if (!TOKEN) {
    console.error("[telegram] TELEGRAM_BOT_TOKEN is not set — cannot start fallback channel.");
    process.exit(1);
  }

  let paired = loadPairing();
  let pairingCode: string | null = null;

  if (paired) {
    console.log(`[telegram] Paired with user ${paired.userId} (${paired.username ?? "unknown"})`);
  } else {
    pairingCode = generatePairingCode();
    console.log("[telegram] ──────────────────────────────────────────");
    console.log("[telegram] No paired account found.");
    console.log(`[telegram] Send this code to your bot to link your account:`);
    console.log(`[telegram]   ${pairingCode}`);
    console.log("[telegram] ──────────────────────────────────────────");
  }

  let offset = 0;
  console.log("[telegram] Polling for messages...");

  while (true) {
    let res: any;

    try {
      res = await tgCall("getUpdates", {
        timeout: 30,
        offset,
        allowed_updates: ["message"],
      });
    } catch (err) {
      console.error("[telegram] Network error, retrying in 10s:", err);
      await Bun.sleep(10_000);
      continue;
    }

    if (!res.ok) {
      console.error("[telegram] API error:", JSON.stringify(res));
      await Bun.sleep(10_000);
      continue;
    }

    for (const update of res.result ?? []) {
      offset = update.update_id + 1;

      const msg = update.message;
      if (!msg?.text) continue;

      const userId: number = msg.from.id;
      const chatId: number = msg.chat.id;
      const text: string = msg.text.trim();

      // ── Pairing flow ──
      if (!paired) {
        if (text === pairingCode) {
          const state: PairingState = { userId, username: msg.from.username };
          savePairing(state);
          paired = state;
          pairingCode = null;
          console.log(`[telegram] Paired with user ${userId} (@${msg.from.username ?? "?"})`);
          await sendMessage(chatId, "Paired successfully. You can now send commands to Claude Code.");
        }
        // Silently ignore everyone else — same behaviour as native Channels
        continue;
      }

      // ── Only respond to the paired user ──
      if (userId !== paired.userId) continue;

      console.log(`[telegram] → ${text.substring(0, 100)}${text.length > 100 ? "…" : ""}`);
      await sendMessage(chatId, "Working on it…");

      const response = await runClaude(text);
      await sendMessage(chatId, response);
      console.log(`[telegram] ← ${response.length} chars`);
    }
  }
}

main().catch((err) => {
  console.error("[telegram] Fatal:", err);
  process.exit(1);
});
