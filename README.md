# 🤖 WhatsApp AI Autoresponder

Auto-reply to WhatsApp messages using a free AI (Groq) — runs on any Linux server with 1GB RAM. No browser, no GUI, no paid API.

---

## ✨ Features

- 🔁 Auto-replies using **Groq free API** (Llama, Qwen, and more)
- 📱 **No QR GUI** — scans via terminal ASCII QR
- 🧠 Custom bot personality via system prompt
- 🎯 **Live model picker** — fetches your account's available models at setup
- ✅ **Whitelist mode** — reply only to specific contacts
- 🚫 **Blacklist mode** — reply everyone except blocked numbers
- 👥 Group chat support (optional)
- 💾 Session saved — no re-scan on restart
- 🔄 Auto-restart via systemd + built-in reconnect loop
- 🪶 Lightweight — ~100MB RAM total
- 🐧 Works on Arch, Ubuntu, Debian, Fedora, CentOS, openSUSE, Alpine

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
5. **Mode** — blacklist or whitelist
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
├── session.db      # WA session (auto-created on first run)
├── bot.log         # Logs
├── venv/           # Python virtualenv
└── wa-bot.service  # Systemd service
```

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
| `groq_model` | Model ID — must be one available on your Groq account |
| `mode` | `"whitelist"` reply only allowed / `"blacklist"` reply all except blocked |
| `allowed_contacts` | Numbers to reply (whitelist mode) |
| `blocked_contacts` | Numbers to skip (blacklist mode) |
| `allow_groups` | `true` / `false` |
| `allowed_groups` | Specific group IDs to allow (empty = all groups) |
| `blocked_groups` | Group IDs to skip |
| `reply_delay_seconds` | Delay before replying (feels more human) |

> **Tip:** To see which models are available on your key, run:
> ```bash
> curl -s https://api.groq.com/openai/v1/models \
>   -H "Authorization: Bearer $(python3 -c "import json; print(json.load(open('config.json'))['groq_api_key'])")" \
>   | python3 -c "import json,sys; [print(m['id']) for m in json.load(sys.stdin)['data']]" | sort
> ```

---

## 🔄 Manage Bot

```bash
# View live logs
sudo journalctl -u wa-bot -f

# Stop
sudo systemctl stop wa-bot

# Start
sudo systemctl start wa-bot

# Restart
sudo systemctl restart wa-bot

# Disable auto-start
sudo systemctl disable wa-bot

# Manual run (no systemd)
cd ~/wa && source venv/bin/activate && python bot.py
```

---

## 🔑 Get Free Groq API Key

1. Go to [console.groq.com](https://console.groq.com)
2. Sign up — no credit card needed
3. **API Keys** → **Create New Key**
4. Copy key starting with `gsk_...`

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

**Bot disconnects / WebSocket EOF**
The bot has a built-in reconnect loop — it will reconnect automatically after 5 seconds. No action needed.

**Groq 404 — model not found**
Your Groq account may not have access to that model. Re-run setup to pick from your available models, or update `groq_model` in `config.json` manually.

**Groq 401 — unauthorized**
Your API key is invalid or revoked. Generate a new one at [console.groq.com](https://console.groq.com) and update `config.json`.

**Groq 429 — rate limit**
Free tier allows 14,400 requests/day. The bot waits 10s and retries automatically.

---

## ⚠️ Disclaimer

This project uses the unofficial WhatsApp Web protocol via [neonize](https://github.com/krypton-byte/neonize). Use at your own risk. Not affiliated with Meta/WhatsApp.

---

## 👤 Author

**Vineet** — [ci.vps@proton.me](mailto:ci.vps@proton.me)

GitHub: [@psvineet](https://github.com/psvineet)

---

## 🛠️ Built With

- [neonize](https://github.com/krypton-byte/neonize) — Python WhatsApp library
- [Groq](https://groq.com) — Free LLM API
- [Meta Llama](https://ai.meta.com/llama/) / [Qwen](https://qwenlm.github.io/) — AI models
