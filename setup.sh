#!/bin/bash
# WhatsApp AI Bot - Arch Linux one-shot setup
# Run: bash setup.sh
set -e

echo "=== WhatsApp AI Bot Setup (Arch Linux) ==="

# ── System deps ────────────────────────────────────────────────────────────────
echo "[1/5] Installing system packages..."
sudo pacman -Sy --noconfirm python python-pip python-virtualenv

# ── Directory ──────────────────────────────────────────────────────────────────
echo "[2/5] Creating project folder..."
mkdir -p ~/whatsapp-ai-bot
cd ~/whatsapp-ai-bot

# ── bot.py ─────────────────────────────────────────────────────────────────────
echo "[3/5] Writing bot.py..."
cat > bot.py << 'BOTEOF'
#!/usr/bin/env python3
"""
WhatsApp AI Autoresponder
Uses: neonize (WA) + Groq free API (LLM)
Login: pair code via terminal (no QR image, no GUI)
"""

import json
import time
import logging
import requests
from neonize.client import NewClient
from neonize.events import MessageEv, ConnectedEv, PairStatusEv, event
from neonize.utils import log as neonize_log

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler("bot.log"),
        logging.StreamHandler()
    ]
)
log = logging.getLogger("wa-bot")
neonize_log.setLevel(logging.WARNING)

# ── Config ────────────────────────────────────────────────────────────────────
with open("config.json") as f:
    cfg = json.load(f)

GROQ_API_KEY   = cfg["groq_api_key"]
GROQ_MODEL     = cfg["groq_model"]
SYSTEM_PROMPT  = cfg["system_prompt"]
PHONE_NUMBER   = cfg["phone_number"]

MODE           = cfg["mode"]
ALLOWED        = set(cfg["allowed_contacts"])
BLOCKED        = set(cfg["blocked_contacts"])

ALLOW_GROUPS   = cfg["allow_groups"]
ALLOWED_GROUPS = set(cfg["allowed_groups"])
BLOCKED_GROUPS = set(cfg["blocked_groups"])

IGNORE_OWN     = cfg["ignore_own_messages"]
REPLY_DELAY    = cfg["reply_delay_seconds"]

# ── Groq LLM ──────────────────────────────────────────────────────────────────
def ask_groq(user_message: str) -> str:
    try:
        resp = requests.post(
            "https://api.groq.com/openai/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {GROQ_API_KEY}",
                "Content-Type": "application/json"
            },
            json={
                "model": GROQ_MODEL,
                "messages": [
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user",   "content": user_message}
                ],
                "max_tokens": 200,
                "temperature": 0.7
            },
            timeout=15
        )
        resp.raise_for_status()
        return resp.json()["choices"][0]["message"]["content"].strip()
    except requests.exceptions.Timeout:
        log.warning("Groq timeout")
        return "Sorry, slow to respond right now. Try again soon!"
    except Exception as e:
        log.error(f"Groq error: {e}")
        return "Sorry, couldn't process that right now."

# ── Filters ───────────────────────────────────────────────────────────────────
def extract_number(jid: str) -> str:
    return jid.split("@")[0]

def is_group(jid: str) -> bool:
    return "@g.us" in jid

def should_reply(sender_jid: str, chat_jid: str) -> bool:
    if IGNORE_OWN and extract_number(sender_jid) == PHONE_NUMBER:
        return False

    if is_group(chat_jid):
        if not ALLOW_GROUPS:
            return False
        group_id = extract_number(chat_jid)
        if BLOCKED_GROUPS and group_id in BLOCKED_GROUPS:
            return False
        if ALLOWED_GROUPS and group_id not in ALLOWED_GROUPS:
            return False
        return True

    number = extract_number(sender_jid)
    if MODE == "whitelist":
        return number in ALLOWED
    elif MODE == "blacklist":
        return number not in BLOCKED
    return True

# ── WA Client ─────────────────────────────────────────────────────────────────
client = NewClient("session.db")

@client.event(ConnectedEv)
def on_connected(_client, _event):
    log.info("✅ Connected to WhatsApp!")

@client.event(PairStatusEv)
def on_pair(_client, event):
    log.info(f"📱 Paired: {event.ID.User}")

@client.event(MessageEv)
def on_message(_client, message: MessageEv):
    try:
        msg_info    = message.Info
        chat_jid    = str(msg_info.MessageSource.Chat)
        sender_jid  = str(msg_info.MessageSource.Sender)

        if msg_info.MessageSource.IsFromMe:
            return

        text = ""
        if message.Message.conversation:
            text = message.Message.conversation
        elif message.Message.extendedTextMessage.text:
            text = message.Message.extendedTextMessage.text

        if not text.strip():
            return

        log.info(f"📩 From {sender_jid}: {text[:80]}")

        if not should_reply(sender_jid, chat_jid):
            log.info(f"⏭️  Skipped: {sender_jid}")
            return

        if REPLY_DELAY > 0:
            time.sleep(REPLY_DELAY)

        reply = ask_groq(text)
        log.info(f"🤖 Reply: {reply[:80]}")
        _client.reply_message(reply, message)

    except Exception as e:
        log.error(f"Handler error: {e}", exc_info=True)

# ── Main ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    log.info("🚀 Starting WhatsApp AI Bot...")
    log.info(f"   Mode   : {MODE}")
    log.info(f"   Groups : {'on' if ALLOW_GROUPS else 'off'}")
    log.info(f"   Model  : {GROQ_MODEL}")
    log.info("")
    log.info("👉 First run: WA app → Linked Devices → Link Device → Enter code")
    log.info("")
    client.connect(PHONE_NUMBER)
BOTEOF

# ── config.json ────────────────────────────────────────────────────────────────
echo "[4/5] Writing config.json..."
cat > config.json << 'CFGEOF'
{
  "groq_api_key": "YOUR_GROQ_API_KEY_HERE",
  "groq_model": "llama-3.1-8b-instant",
  "system_prompt": "You are a helpful assistant replying on behalf of the phone owner. Keep replies short and friendly.",

  "phone_number": "919876543210",

  "mode": "whitelist",

  "allowed_contacts": [
    "919876543210",
    "911234567890"
  ],

  "blocked_contacts": [],

  "allow_groups": false,
  "allowed_groups": [],
  "blocked_groups": [],

  "ignore_own_messages": true,
  "reply_delay_seconds": 1
}
CFGEOF

# ── systemd service ────────────────────────────────────────────────────────────
echo "[4/5] Writing systemd service..."
WHOAMI=$(whoami)
BOTDIR=$(pwd)
cat > wa-bot.service << SVCEOF
[Unit]
Description=WhatsApp AI Autoresponder
After=network.target

[Service]
Type=simple
User=$WHOAMI
WorkingDirectory=$BOTDIR
ExecStart=$BOTDIR/venv/bin/python bot.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCEOF

# ── virtualenv + pip ───────────────────────────────────────────────────────────
echo "[5/5] Creating venv and installing packages..."
python -m venv venv
source venv/bin/activate
pip install --upgrade pip -q
pip install neonize requests -q

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  ✅ Setup complete!"
echo "============================================"
echo ""
echo "NEXT STEPS:"
echo ""
echo "  1. Edit config:"
echo "     nano ~/whatsapp-ai-bot/config.json"
echo "     → Set groq_api_key  (get free at console.groq.com)"
echo "     → Set phone_number  (country code + number, no +)"
echo "     → Set allowed_contacts list"
echo ""
echo "  2. First run (pair code login):"
echo "     cd ~/whatsapp-ai-bot"
echo "     source venv/bin/activate"
echo "     python bot.py"
echo "     → Terminal shows 8-digit code"
echo "     → WA phone: Linked Devices → Link Device → Enter code"
echo ""
echo "  3. Auto-start on boot:"
echo "     sudo cp ~/whatsapp-ai-bot/wa-bot.service /etc/systemd/system/"
echo "     sudo systemctl enable --now wa-bot"
echo "     sudo journalctl -u wa-bot -f"
echo ""
echo "  Session saved to session.db — no re-pairing on restart."
echo "============================================"
