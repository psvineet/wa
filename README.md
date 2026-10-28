# 🤖 WhatsApp AI Autoresponder

Auto-reply to WhatsApp messages using a free AI (Groq) — runs on any Linux server with 1GB RAM. No browser, no GUI, no paid API.

---

## ✨ Features

- 🔁 Auto-replies using **Groq free API** (Llama 3.1 8B)
- 📱 **No QR GUI** — scans via terminal ASCII QR or pair code
- 🧠 Custom bot personality via system prompt
- ✅ **Whitelist mode** — reply only to specific contacts
- 🚫 **Blacklist mode** — reply everyone except blocked numbers
- 👥 Group chat support (optional)
- 💾 Session saved — no re-scan on restart
- 🔄 Auto-restart via systemd
- 🪶 Lightweight — ~100MB RAM total

---

## 📦 Requirements

- Arch Linux / any Linux distro (script targets Arch)
- Python 3.8+
- Free [Groq API key](https://console.groq.com) (no credit card)
- Your WhatsApp account

---

## 🚀 Quick Setup

```bash
bash <(curl -s https://raw.githubusercontent.com/psvineet/wa/main/setup.sh)
```

The script will ask you:
1. **Groq API key** — get free at [console.groq.com](https://console.groq.com)
2. **Your phone number** — with country code, no `+` (e.g. `919876543210`)
3. **Bot personality** — custom system prompt or default
4. **Mode** — blacklist or whitelist
5. **Contacts** — numbers to allow or block
6. **Groups** — enable/disable group replies

Then it installs everything, sets up systemd, and launches the bot automatically.

---

## 📤 Push to GitHub

```bash
git init
git add .
git commit -m "feat: WhatsApp AI autoresponder"
git branch -M main
git remote add origin https://github.com/psvineet/wa.git
git push -u origin main
```

---

## 📁 Project Structure

```
~/wa/
├── bot.py          # Main bot
├── config.json     # All settings
├── session.db      # WA session (auto-created)
├── bot.log         # Logs
├── venv/           # Python virtualenv
└── wa-bot.service  # Systemd service
```

---

## ⚙️ Config Reference

```json
{
  "groq_api_key": "gsk_...",
  "groq_model": "llama-3.1-8b-instant",
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
| `mode` | `"whitelist"` reply only allowed / `"blacklist"` reply all except blocked |
| `allowed_contacts` | Numbers to reply (whitelist mode) |
| `blocked_contacts` | Numbers to skip (blacklist mode) |
| `allow_groups` | `true` / `false` |
| `allowed_groups` | Specific group IDs to allow (empty = all groups) |
| `blocked_groups` | Group IDs to skip |
| `reply_delay_seconds` | Delay before replying (feels more human) |

---

## 🔄 Manage Bot

```bash
# View live logs
sudo journalctl -u wa-bot -f

# Stop bot
sudo systemctl stop wa-bot

# Start bot
sudo systemctl start wa-bot

# Restart bot
sudo systemctl restart wa-bot

# Disable auto-start
sudo systemctl disable wa-bot
```

---

## 🔑 Get Free Groq API Key

1. Go to [console.groq.com](https://console.groq.com)
2. Sign up (no credit card needed)
3. Go to **API Keys** → **Create New Key**
4. Copy key starting with `gsk_...`

Free tier: **14,400 requests/day** — more than enough.

---

## 📱 First Login (QR Scan)

On first run, a QR code appears in terminal:

```
Scan with WhatsApp:
Phone → ⋮ Menu → Linked Devices → Link Device
```

Session saved to `session.db` — no re-scan needed on restart.

---

## ⚠️ Disclaimer

This project uses the unofficial WhatsApp Web protocol via [neonize](https://github.com/krypton-byte/neonize). Use at your own risk. Not affiliated with Meta/WhatsApp.

---

## 🛠️ Built With

- [neonize](https://github.com/krypton-byte/neonize) — Python WhatsApp library
- [Groq](https://groq.com) — Free LLM API
- [Llama 3.1](https://ai.meta.com/llama/) — AI model
