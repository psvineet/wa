# 🤖 WhatsApp AI Autoresponder

Auto-reply to WhatsApp messages using a free AI (Groq) — runs on any Linux server with 1GB RAM. No browser, no GUI, no paid API.

---

## ✨ Features

- 🔁 Auto-replies using **Groq free API**
- 🎯 **Live model picker** — fetches your account's models at setup, you choose
- 📱 **No QR GUI** — scans via terminal ASCII QR
- 🧠 Custom bot personality via system prompt
- ✅ **Whitelist mode** — reply only to specific contacts
- 🚫 **Blacklist mode** — reply everyone except blocked numbers
- 👥 Group chat support (optional)
- 💾 Session saved — no re-scan on restart
- 🔄 Auto-reconnect on disconnect + clean Ctrl+C shutdown
- 🚀 `run.sh` — one command start, auto-activates venv (no manual activation needed)
- 🗑️ `remove.sh` — clean uninstaller
- 🔄 Auto-restart via systemd
- 🪶 Lightweight — ~100MB RAM
- 🐧 Arch, Ubuntu, Debian, Fedora, CentOS, openSUSE, Alpine

---

## 📦 Requirements

- Any Linux distro (auto-detected)
- Python 3.8+
- Free [Groq API key](https://console.groq.com) (no credit card)
- Your WhatsApp account

---

## 🚀 Quick Setup (one command)

```bash
bash <(curl -s https://raw.githubusercontent.com/psvineet/wa/main/setup.sh)
```

The script will ask you:
1. **Groq API key** — get free at [console.groq.com](https://console.groq.com)
2. **AI model** — fetched live from your account, pick by number
3. **Your phone number** — with country code, no `+` (e.g. `919876543210`)
4. **Bot personality** — custom system prompt or press Enter for default
5. **Reply mode** — blacklist or whitelist
6. **Contacts** — numbers to allow or block
7. **Groups** — enable/disable group replies
8. **Systemd service** — auto-start on boot (optional)

Then it installs everything and launches the bot automatically.

---

## 📁 Project Structure

```
~/wa/
├── bot.py          # Main bot
├── config.json     # All settings
├── run.sh          # Start the bot (handles venv automatically)
├── remove.sh       # Clean uninstaller
├── session.db      # WA session (auto-created on first run)
├── bot.log         # Logs
├── venv/           # Python virtualenv
└── wa-bot.service  # Systemd unit file
```

---

## ▶️ Running the Bot

**Always use `run.sh`** — it activates the venv automatically so you never get `ModuleNotFoundError`:

```bash
~/wa/run.sh
```

Or from inside the folder:

```bash
cd ~/wa && ./run.sh
```

> ⚠️ Never run `python bot.py` directly — you'll get `ModuleNotFoundError: No module named 'neonize'` unless you manually activated the venv first.

---

## ⚙️ Config Reference

```json
{
  "groq_api_key": "gsk_...",
  "groq_model": "openai/gpt-oss-20b",
  "system_prompt": "You are a helpful assistant...",
  "phone_number": "919876543210",

  "mode": "blacklist",

  "allowed_contacts": ["919999999999"],
  "blocked_contacts": ["911111111111"],

  "allow_groups": false,
  "allowed_groups": [],
  "blocked_groups": [],

  "ignore_own_messages": true,
  "reply_delay_seconds": 1
}
```

| Field | Description |
|---|---|
| `groq_model` | Model ID — must exist on your Groq account |
| `mode` | `"whitelist"` or `"blacklist"` |
| `allowed_contacts` | Numbers to reply (whitelist mode) |
| `blocked_contacts` | Numbers to skip (blacklist mode) |
| `allow_groups` | `true` / `false` |
| `allowed_groups` | Specific group IDs to allow (empty = all groups) |
| `blocked_groups` | Group IDs to skip |
| `reply_delay_seconds` | Delay before replying (feels more human) |

**To see which models are on your account:**

```bash
~/wa/run.sh --list-models
```

**To change model** — edit `config.json` then restart:

```bash
nano ~/wa/config.json   # update groq_model
~/wa/run.sh
```

---

## 🔄 Manage Bot

```bash
# Start
~/wa/run.sh

# Stop (if running in terminal)
Ctrl+C

# Systemd commands
sudo systemctl start   wa-bot
sudo systemctl stop    wa-bot
sudo systemctl restart wa-bot
sudo systemctl status  wa-bot
sudo systemctl disable wa-bot    # stop auto-start

# Live logs
sudo journalctl -u wa-bot -f

# Manual run (no systemd)
cd ~/wa && ./run.sh
```

---

## 🗑️ Uninstall

```bash
bash ~/wa/remove.sh
```

Removes the systemd service, stops the bot, and deletes `~/wa` completely.

---

## 🔑 Get Free Groq API Key

1. Go to [console.groq.com](https://console.groq.com)
2. Sign up — no credit card needed
3. **API Keys** → **Create New Key**
4. Copy the key starting with `gsk_...`

Free tier: **14,400 requests/day** — more than enough for personal use.

---

## 📱 First Login

On first run a QR code appears in terminal:

```
Phone → ⋮ Menu → Linked Devices → Link Device → Scan QR
```

Session saved to `session.db` — no re-scan on restart.

---

## 🐧 Supported Distros

| Distro | Package Manager |
|---|---|
| Arch / Manjaro | `pacman` |
| Ubuntu / Debian / Mint | `apt` |
| Fedora / RHEL 8+ / AlmaLinux | `dnf` |
| CentOS / RHEL 7 | `yum` |
| openSUSE | `zypper` |
| Alpine | `apk` |

---

## ❓ Troubleshooting

**`ModuleNotFoundError: No module named 'neonize'`**
Use `~/wa/run.sh` instead of `python bot.py` directly. `run.sh` activates the venv automatically.

**Bot disconnects / WebSocket EOF**
Built-in reconnect loop handles this — reconnects automatically after 5 seconds.

**Groq 404 — model not found**
Your account doesn't have that model. Run `~/wa/run.sh --list-models` to see what's available, then update `groq_model` in `config.json`.

**Groq 401 — unauthorized**
API key is invalid or revoked. Generate a new one at [console.groq.com](https://console.groq.com) and update `config.json`.

**Groq 429 — rate limit**
Free tier: 14,400 requests/day. The bot waits 10s and retries automatically.

---

## ⚠️ Disclaimer

Uses the unofficial WhatsApp Web protocol via [neonize](https://github.com/krypton-byte/neonize). Use at your own risk. Not affiliated with Meta/WhatsApp.

---

## 👤 Author

**Vineet** — [ci.vps@proton.me](mailto:ci.vps@proton.me) · [@psvineet](https://github.com/psvineet)

---

## 🛠️ Built With

- [neonize](https://github.com/krypton-byte/neonize) — Python WhatsApp library
- [Groq](https://groq.com) — Free LLM API
- [Meta Llama](https://ai.meta.com/llama/) / [Qwen](https://qwenlm.github.io/) — AI models
