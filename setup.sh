#!/bin/bash
# WhatsApp AI Bot - Arch Linux Full Auto Setup
# Run: bash setup.sh

set -e

# ── Colors ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo -e "${BOLD}${CYAN}"
echo "  ██╗    ██╗ █████╗     ██████╗  ██████╗ ████████╗"
echo "  ██║    ██║██╔══██╗    ██╔══██╗██╔═══██╗╚══██╔══╝"
echo "  ██║ █╗ ██║███████║    ██████╔╝██║   ██║   ██║   "
echo "  ██║███╗██║██╔══██║    ██╔══██╗██║   ██║   ██║   "
echo "  ╚███╔███╔╝██║  ██║    ██████╔╝╚██████╔╝   ██║   "
echo "   ╚══╝╚══╝ ╚═╝  ╚═╝    ╚═════╝  ╚═════╝    ╚═╝   "
echo -e "${NC}"
echo -e "${BOLD}  WhatsApp AI Autoresponder — Setup Wizard${NC}"
echo "  ─────────────────────────────────────────"
echo ""

# ── Step 1: System packages ────────────────────────────────────────────────────
echo -e "${YELLOW}[1/6] Installing system packages...${NC}"
sudo pacman -Sy --noconfirm python python-pip python-virtualenv 2>/dev/null | tail -1
echo -e "${GREEN}  ✓ Done${NC}"
echo ""

# ── Step 2: Create folder ──────────────────────────────────────────────────────
BOTDIR="$HOME/wa"
echo -e "${YELLOW}[2/6] Creating project folder at ~/wa ...${NC}"
mkdir -p "$BOTDIR"
cd "$BOTDIR"
echo -e "${GREEN}  ✓ Done${NC}"
echo ""

# ── Step 3: Interactive config ─────────────────────────────────────────────────
echo -e "${YELLOW}[3/6] Configuration${NC}"
echo "  ─────────────────────────────────────────"
echo ""

# Groq API key
echo -e "${CYAN}  Get your FREE Groq API key at:${NC}"
echo -e "${BOLD}  https://console.groq.com${NC}"
echo -e "  → Signup → API Keys → Create New Key"
echo ""
while true; do
    read -rp "  Paste your Groq API key: " GROQ_KEY
    if [[ "$GROQ_KEY" == gsk_* ]]; then
        echo -e "${GREEN}  ✓ Key looks valid${NC}"
        break
    else
        echo -e "${RED}  ✗ Key should start with 'gsk_' — try again${NC}"
    fi
done
echo ""

# Phone number
echo -e "${CYAN}  Your WhatsApp number (with country code, no + or spaces):${NC}"
echo -e "  Example: India 91XXXXXXXXXX | US 1XXXXXXXXXX | UK 44XXXXXXXXXX"
echo ""
while true; do
    read -rp "  Phone number: " PHONE
    PHONE="${PHONE//[^0-9]/}"  # strip non-digits
    if [[ ${#PHONE} -ge 10 && ${#PHONE} -le 15 ]]; then
        echo -e "${GREEN}  ✓ Number: $PHONE${NC}"
        break
    else
        echo -e "${RED}  ✗ Invalid — digits only, 10-15 chars${NC}"
    fi
done
echo ""

# Bot personality
echo -e "${CYAN}  Bot personality / system prompt:${NC}"
echo -e "  (Press Enter for default)"
read -rp "  System prompt: " SYS_PROMPT
if [[ -z "$SYS_PROMPT" ]]; then
    SYS_PROMPT="You are a helpful assistant replying on behalf of the phone owner. Keep replies short and friendly."
fi
echo -e "${GREEN}  ✓ Prompt set${NC}"
echo ""

# Mode
echo -e "${CYAN}  Reply mode:${NC}"
echo "  1) blacklist — reply everyone EXCEPT blocked numbers (recommended)"
echo "  2) whitelist — reply ONLY allowed numbers"
echo ""
while true; do
    read -rp "  Choose [1/2]: " MODE_CHOICE
    if [[ "$MODE_CHOICE" == "1" ]]; then
        MODE="blacklist"
        echo -e "${GREEN}  ✓ Blacklist mode${NC}"
        break
    elif [[ "$MODE_CHOICE" == "2" ]]; then
        MODE="whitelist"
        echo -e "${GREEN}  ✓ Whitelist mode${NC}"
        break
    else
        echo -e "${RED}  ✗ Enter 1 or 2${NC}"
    fi
done
echo ""

# Contacts
ALLOWED_JSON="[]"
BLOCKED_JSON="[]"

if [[ "$MODE" == "whitelist" ]]; then
    echo -e "${CYAN}  Allowed contacts (numbers that get AI replies):${NC}"
    echo -e "  Enter one per line. Empty line when done."
    ALLOWED_LIST=()
    while true; do
        read -rp "  Number (or Enter to finish): " NUM
        NUM="${NUM//[^0-9]/}"
        [[ -z "$NUM" ]] && break
        ALLOWED_LIST+=("\"$NUM\"")
        echo -e "${GREEN}  ✓ Added $NUM${NC}"
    done
    if [[ ${#ALLOWED_LIST[@]} -gt 0 ]]; then
        ALLOWED_JSON="[$(IFS=,; echo "${ALLOWED_LIST[*]}")]"
    fi
else
    echo -e "${CYAN}  Blocked contacts (numbers to SKIP — leave empty to reply everyone):${NC}"
    echo -e "  Enter one per line. Empty line when done."
    BLOCKED_LIST=()
    while true; do
        read -rp "  Number (or Enter to finish): " NUM
        NUM="${NUM//[^0-9]/}"
        [[ -z "$NUM" ]] && break
        BLOCKED_LIST+=("\"$NUM\"")
        echo -e "${GREEN}  ✓ Blocked $NUM${NC}"
    done
    if [[ ${#BLOCKED_LIST[@]} -gt 0 ]]; then
        BLOCKED_JSON="[$(IFS=,; echo "${BLOCKED_LIST[*]}")]"
    fi
fi
echo ""

# Groups
echo -e "${CYAN}  Reply in WhatsApp groups?${NC}"
read -rp "  Enable group replies? [y/N]: " GRP
if [[ "$GRP" =~ ^[Yy]$ ]]; then
    ALLOW_GROUPS="true"
    echo -e "${GREEN}  ✓ Groups enabled${NC}"
else
    ALLOW_GROUPS="false"
    echo -e "${GREEN}  ✓ Groups disabled${NC}"
fi
echo ""

# ── Step 4: Write files ────────────────────────────────────────────────────────
echo -e "${YELLOW}[4/6] Writing config and bot files...${NC}"

# config.json
cat > config.json << CFGEOF
{
  "groq_api_key": "$GROQ_KEY",
  "groq_model": "llama-3.1-8b-instant",
  "system_prompt": "$SYS_PROMPT",
  "phone_number": "$PHONE",
  "mode": "$MODE",
  "allowed_contacts": $ALLOWED_JSON,
  "blocked_contacts": $BLOCKED_JSON,
  "allow_groups": $ALLOW_GROUPS,
  "allowed_groups": [],
  "blocked_groups": [],
  "ignore_own_messages": true,
  "reply_delay_seconds": 1
}
CFGEOF

# bot.py
cat > bot.py << 'BOTEOF'
#!/usr/bin/env python3
"""
WhatsApp AI Autoresponder
neonize + Groq free API
"""

import json, time, logging, requests
from neonize.client import NewClient
from neonize.events import MessageEv, ConnectedEv, PairStatusEv
from neonize.utils import log as neonize_log

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.FileHandler("bot.log"), logging.StreamHandler()]
)
log = logging.getLogger("wa-bot")
neonize_log.setLevel(logging.WARNING)

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

def ask_groq(user_message: str) -> str:
    try:
        resp = requests.post(
            "https://api.groq.com/openai/v1/chat/completions",
            headers={"Authorization": f"Bearer {GROQ_API_KEY}", "Content-Type": "application/json"},
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
        return "Sorry, slow right now. Try again soon!"
    except Exception as e:
        log.error(f"Groq error: {e}")
        return "Sorry, couldn't process that right now."

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
        gid = extract_number(chat_jid)
        if BLOCKED_GROUPS and gid in BLOCKED_GROUPS: return False
        if ALLOWED_GROUPS and gid not in ALLOWED_GROUPS: return False
        return True
    number = extract_number(sender_jid)
    if MODE == "whitelist": return number in ALLOWED
    if MODE == "blacklist": return number not in BLOCKED
    return True

client = NewClient("session.db")

@client.event(ConnectedEv)
def on_connected(_c, _e):
    log.info("✅ Connected to WhatsApp!")

@client.event(PairStatusEv)
def on_pair(_c, e):
    log.info(f"📱 Paired: {e.ID.User}")

@client.event(MessageEv)
def on_message(_c, message: MessageEv):
    try:
        info       = message.Info
        chat_jid   = str(info.MessageSource.Chat)
        sender_jid = str(info.MessageSource.Sender)
        if info.MessageSource.IsFromMe: return

        text = ""
        if message.Message.conversation:
            text = message.Message.conversation
        elif message.Message.extendedTextMessage.text:
            text = message.Message.extendedTextMessage.text
        if not text.strip(): return

        log.info(f"📩 {sender_jid}: {text[:80]}")
        if not should_reply(sender_jid, chat_jid):
            log.info(f"⏭️  Skipped: {sender_jid}")
            return

        if REPLY_DELAY > 0: time.sleep(REPLY_DELAY)
        reply = ask_groq(text)
        log.info(f"🤖 {reply[:80]}")
        _c.reply_message(reply, message)
    except Exception as e:
        log.error(f"Error: {e}", exc_info=True)

if __name__ == "__main__":
    log.info("🚀 Starting WhatsApp AI Bot...")
    log.info(f"   Mode   : {MODE}")
    log.info(f"   Groups : {'on' if ALLOW_GROUPS else 'off'}")
    log.info(f"   Model  : {GROQ_MODEL}")
    log.info("")
    log.info("👉 Scan QR or enter pair code shown below")
    log.info("")
    client.connect()
BOTEOF

# systemd service
WHOAMI=$(whoami)
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

echo -e "${GREEN}  ✓ Files written${NC}"
echo ""

# ── Step 5: Venv + packages ────────────────────────────────────────────────────
echo -e "${YELLOW}[5/6] Installing Python packages (neonize, requests)...${NC}"
python -m venv venv
source venv/bin/activate
pip install --upgrade pip -q
pip install neonize requests -q
echo -e "${GREEN}  ✓ Packages installed${NC}"
echo ""

# ── Step 6: Systemd (optional) ─────────────────────────────────────────────────
echo -e "${CYAN}  Install as systemd service? (auto-start on boot, runs in background)${NC}"
read -rp "  Install service? [Y/n]: " SVC_CHOICE

INSTALL_SERVICE=false
if [[ ! "$SVC_CHOICE" =~ ^[Nn]$ ]]; then
    INSTALL_SERVICE=true
    echo -e "${YELLOW}[6/6] Setting up auto-start service...${NC}"
    sudo cp wa-bot.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable wa-bot
    echo -e "${GREEN}  ✓ Service enabled — bot will auto-start on every reboot${NC}"
else
    echo -e "${YELLOW}  Skipped. Run manually anytime:${NC}"
    echo -e "  cd ~/wa && source venv/bin/activate && python bot.py"
fi
echo ""

# ── Launch ─────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${GREEN}============================================${NC}"
echo -e "${BOLD}${GREEN}  ✅ Setup complete! Launching bot now...  ${NC}"
echo -e "${BOLD}${GREEN}============================================${NC}"
echo ""
echo -e "${CYAN}  Scan the QR code below with WhatsApp:${NC}"
echo -e "  Phone → ⋮ Menu → Linked Devices → Link Device"
echo ""

if [[ "$INSTALL_SERVICE" == true ]]; then
    echo -e "${YELLOW}  After QR scan, press Ctrl+C — systemd will keep it running.${NC}"
    echo -e "  Logs: sudo journalctl -u wa-bot -f"
else
    echo -e "${YELLOW}  Press Ctrl+C to stop bot anytime.${NC}"
fi
echo ""

# run bot
cd "$BOTDIR"
source venv/bin/activate
python bot.py

# if service installed, hand off to systemd after first run
if [[ "$INSTALL_SERVICE" == true ]]; then
    echo ""
    echo -e "${GREEN}  Starting bot via systemd...${NC}"
    sudo systemctl start wa-bot
    echo -e "${GREEN}  ✓ Bot running in background via systemd${NC}"
    echo -e "  View logs: sudo journalctl -u wa-bot -f"
fi
