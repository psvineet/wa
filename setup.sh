#!/bin/bash
# WhatsApp AI Bot - Universal Setup
# Supports: Arch, Ubuntu, Debian, Fedora, CentOS, RHEL, openSUSE, Alpine
# Run: bash setup.sh

# ── Safety ─────────────────────────────────────────────────────────────────────
set -euo pipefail
IFS=$'\n\t'

# ── Colors ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Helpers ────────────────────────────────────────────────────────────────────
info()    { echo -e "${CYAN}  $*${NC}"; }
success() { echo -e "${GREEN}  ✓ $*${NC}"; }
warn()    { echo -e "${YELLOW}  ! $*${NC}"; }
error()   { echo -e "${RED}  ✗ $*${NC}"; exit 1; }
ask()     { echo -e "${CYAN}  $*${NC}"; }

# ── Banner ─────────────────────────────────────────────────────────────────────
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

# ── Step 1: Detect distro + install packages ───────────────────────────────────
echo -e "${YELLOW}[1/6] Detecting distro and installing packages...${NC}"

PKG_INSTALLED=false

if command -v pacman &>/dev/null; then
    info "Distro: Arch / Manjaro"
    sudo pacman -Sy --noconfirm python python-pip python-virtualenv curl
    PKG_INSTALLED=true

elif command -v apt-get &>/dev/null; then
    info "Distro: Debian / Ubuntu / Mint"
    sudo apt-get update -qq
    sudo apt-get install -y python3 python3-pip python3-venv curl
    PKG_INSTALLED=true

elif command -v dnf &>/dev/null; then
    info "Distro: Fedora / RHEL 8+ / AlmaLinux"
    sudo dnf install -y python3 python3-pip python3-virtualenv curl
    PKG_INSTALLED=true

elif command -v yum &>/dev/null; then
    info "Distro: CentOS / RHEL 7"
    sudo yum install -y python3 python3-pip curl
    pip3 install --quiet virtualenv
    PKG_INSTALLED=true

elif command -v zypper &>/dev/null; then
    info "Distro: openSUSE"
    sudo zypper install -y python3 python3-pip python3-virtualenv curl
    PKG_INSTALLED=true

elif command -v apk &>/dev/null; then
    info "Distro: Alpine"
    sudo apk add --no-cache python3 py3-pip curl
    pip3 install --quiet virtualenv
    PKG_INSTALLED=true
fi

[[ "$PKG_INSTALLED" == false ]] && error "Unknown distro. Install python3 + pip manually then rerun."

# ensure 'python' command exists
if ! command -v python &>/dev/null; then
    PYTHON3_PATH="$(command -v python3)"
    sudo ln -sf "$PYTHON3_PATH" /usr/local/bin/python 2>/dev/null || \
    sudo ln -sf "$PYTHON3_PATH" /usr/bin/python 2>/dev/null || true
fi

python --version &>/dev/null || error "python3 not found after install. Check your system."
success "Packages installed"
echo ""

# ── Step 2: Create folder ──────────────────────────────────────────────────────
BOTDIR="$HOME/wa"
echo -e "${YELLOW}[2/6] Creating project at ~/wa ...${NC}"
mkdir -p "$BOTDIR"
cd "$BOTDIR"
success "Folder ready: $BOTDIR"
echo ""

# ── Step 3: Interactive config ─────────────────────────────────────────────────
echo -e "${YELLOW}[3/6] Configuration${NC}"
echo "  ─────────────────────────────────────────"
echo ""

# ── Groq API key ──────────────────────────────────────────────────────────────
ask "Get your FREE Groq API key at:"
echo -e "  ${BOLD}https://console.groq.com${NC}"
echo -e "  Signup → API Keys → Create New Key (no credit card needed)"
echo ""
GROQ_KEY=""
while true; do
    read -rp "  Paste Groq API key: " GROQ_KEY
    GROQ_KEY="${GROQ_KEY// /}"
    if [[ "$GROQ_KEY" == gsk_* && ${#GROQ_KEY} -gt 20 ]]; then
        success "Key format valid — verifying with Groq..."
        break
    else
        warn "Key must start with 'gsk_' and be complete — try again"
    fi
done
echo ""

# ── Fetch available chat models from Groq ────────────────────────────────────
info "Fetching available models from your Groq account..."

# excluded: audio/speech, guard, embedding, TTS, safety-only models
EXCLUDE_PATTERN="whisper|tts|guard|safeguard|orpheus|allam|embed"

MODELS_JSON=$(curl -sf https://api.groq.com/openai/v1/models \
    -H "Authorization: Bearer $GROQ_KEY" 2>/dev/null) || true

if [[ -z "$MODELS_JSON" ]]; then
    warn "Could not reach Groq API. Check your internet / API key."
    warn "Falling back to: openai/gpt-oss-20b"
    GROQ_MODEL="openai/gpt-oss-20b"
else
    # Filter to text/chat models only, sorted
    mapfile -t CHAT_MODELS < <(
        echo "$MODELS_JSON" \
        | python3 -c "
import json, sys, re
data = json.load(sys.stdin)
exclude = re.compile(r'whisper|tts|guard|safeguard|orpheus|allam|embed', re.I)
models = [m['id'] for m in data.get('data', []) if not exclude.search(m['id'])]
models.sort()
print('\n'.join(models))
" 2>/dev/null
    )

    if [[ ${#CHAT_MODELS[@]} -eq 0 ]]; then
        warn "No chat models found. Check your API key permissions."
        warn "Falling back to: openai/gpt-oss-20b"
        GROQ_MODEL="openai/gpt-oss-20b"
    else
        echo ""
        echo -e "  ${BOLD}Available chat models on your account:${NC}"
        echo ""
        for i in "${!CHAT_MODELS[@]}"; do
            printf "  ${CYAN}%2d)${NC} %s\n" "$((i+1))" "${CHAT_MODELS[$i]}"
        done
        echo ""

        GROQ_MODEL=""
        while true; do
            read -rp "  Choose model number [1-${#CHAT_MODELS[@]}]: " MODEL_CHOICE
            if [[ "$MODEL_CHOICE" =~ ^[0-9]+$ ]] \
               && [[ "$MODEL_CHOICE" -ge 1 ]] \
               && [[ "$MODEL_CHOICE" -le ${#CHAT_MODELS[@]} ]]; then
                GROQ_MODEL="${CHAT_MODELS[$((MODEL_CHOICE-1))]}"
                success "Model: $GROQ_MODEL"
                break
            else
                warn "Enter a number between 1 and ${#CHAT_MODELS[@]}"
            fi
        done
    fi
fi
echo ""

# ── Phone number ──────────────────────────────────────────────────────────────
ask "Your WhatsApp number (country code + number, no + or spaces):"
echo -e "  India: 91XXXXXXXXXX | US: 1XXXXXXXXXX | UK: 44XXXXXXXXXX"
echo ""
PHONE=""
while true; do
    read -rp "  Phone number: " PHONE
    PHONE="${PHONE//[^0-9]/}"
    if [[ ${#PHONE} -ge 10 && ${#PHONE} -le 15 ]]; then
        success "Number: $PHONE"
        break
    else
        warn "Invalid — digits only, 10–15 characters"
    fi
done
echo ""

# ── Bot personality ───────────────────────────────────────────────────────────
ask "Bot personality / system prompt (Enter for default):"
read -rp "  Prompt: " SYS_PROMPT
if [[ -z "${SYS_PROMPT:-}" ]]; then
    SYS_PROMPT="You are a helpful assistant replying on behalf of the phone owner. Keep replies short and friendly."
fi
SYS_PROMPT="${SYS_PROMPT//\\/\\\\}"   # escape backslashes first
SYS_PROMPT="${SYS_PROMPT//\"/\\\"}"   # then escape double quotes
success "Prompt set"
echo ""

# ── Reply mode ────────────────────────────────────────────────────────────────
ask "Reply mode:"
echo "  1) blacklist — reply everyone EXCEPT blocked numbers (recommended)"
echo "  2) whitelist — reply ONLY specific numbers"
echo ""
MODE=""
while true; do
    read -rp "  Choose [1/2]: " MODE_CHOICE
    case "$MODE_CHOICE" in
        1) MODE="blacklist"; success "Blacklist mode"; break ;;
        2) MODE="whitelist"; success "Whitelist mode"; break ;;
        *) warn "Enter 1 or 2" ;;
    esac
done
echo ""

# ── Contacts ──────────────────────────────────────────────────────────────────
ALLOWED_JSON="[]"
BLOCKED_JSON="[]"

build_json_array() {
    local -n arr=$1
    if [[ ${#arr[@]} -eq 0 ]]; then echo "[]"; return; fi
    local json="["
    for i in "${!arr[@]}"; do
        json+="\"${arr[$i]}\""
        [[ $i -lt $((${#arr[@]}-1)) ]] && json+=","
    done
    json+="]"
    echo "$json"
}

if [[ "$MODE" == "whitelist" ]]; then
    ask "Allowed contacts (only these get AI replies):"
    echo -e "  Enter one number per line. Empty line when done."
    ALLOWED_LIST=()
    while true; do
        read -rp "  Number (Enter to finish): " NUM
        NUM="${NUM//[^0-9]/}"
        [[ -z "$NUM" ]] && break
        ALLOWED_LIST+=("$NUM")
        success "Added $NUM"
    done
    ALLOWED_JSON="$(build_json_array ALLOWED_LIST)"
else
    ask "Blocked contacts (leave empty to reply everyone):"
    echo -e "  Enter one number per line. Empty line when done."
    BLOCKED_LIST=()
    while true; do
        read -rp "  Number (Enter to finish): " NUM
        NUM="${NUM//[^0-9]/}"
        [[ -z "$NUM" ]] && break
        BLOCKED_LIST+=("$NUM")
        success "Blocked $NUM"
    done
    BLOCKED_JSON="$(build_json_array BLOCKED_LIST)"
fi
echo ""

# ── Groups ────────────────────────────────────────────────────────────────────
ask "Reply in WhatsApp groups?"
read -rp "  Enable group replies? [y/N]: " GRP
if [[ "${GRP:-}" =~ ^[Yy]$ ]]; then
    ALLOW_GROUPS="true"
    success "Groups enabled"
else
    ALLOW_GROUPS="false"
    success "Groups disabled"
fi
echo ""

# ── Step 4: Write files ────────────────────────────────────────────────────────
echo -e "${YELLOW}[4/6] Writing bot files...${NC}"

# config.json
cat > config.json << CFGEOF
{
  "groq_api_key": "$GROQ_KEY",
  "groq_model": "$GROQ_MODEL",
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

python3 -c "import json; json.load(open('config.json'))" \
    || error "config.json is invalid JSON — report this bug"

# bot.py
cat > bot.py << 'BOTEOF'
#!/usr/bin/env python3
"""
WhatsApp AI Autoresponder
neonize + Groq API

Author : Vineet <ci.vps@proton.me>
GitHub : https://github.com/psvineet/wa
License: MIT
"""

import json, time, logging, sys, requests
from neonize.client import NewClient
from neonize.events import MessageEv, ConnectedEv, PairStatusEv
from neonize.utils import log as neonize_log

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [wa-bot %(levelname)s] - %(message)s",
    handlers=[
        logging.FileHandler("bot.log"),
        logging.StreamHandler(sys.stdout)
    ]
)
log = logging.getLogger("wa-bot")
neonize_log.setLevel(logging.WARNING)

# ── Config ────────────────────────────────────────────────────────────────────
try:
    with open("config.json") as f:
        cfg = json.load(f)
except Exception as e:
    log.error(f"Cannot read config.json: {e}")
    sys.exit(1)

GROQ_API_KEY   = cfg["groq_api_key"]
GROQ_MODEL     = cfg["groq_model"]
SYSTEM_PROMPT  = cfg["system_prompt"]
PHONE_NUMBER   = cfg["phone_number"]
MODE           = cfg["mode"]
ALLOWED        = set(cfg.get("allowed_contacts", []))
BLOCKED        = set(cfg.get("blocked_contacts", []))
ALLOW_GROUPS   = cfg.get("allow_groups", False)
ALLOWED_GROUPS = set(cfg.get("allowed_groups", []))
BLOCKED_GROUPS = set(cfg.get("blocked_groups", []))
IGNORE_OWN     = cfg.get("ignore_own_messages", True)
REPLY_DELAY    = cfg.get("reply_delay_seconds", 1)

if not GROQ_API_KEY.startswith("gsk_"):
    log.error("groq_api_key must start with 'gsk_' — check config.json")
    sys.exit(1)

# ── Groq ──────────────────────────────────────────────────────────────────────
def ask_groq(user_message: str):
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
        log.warning("Groq timeout — skipping reply")
        return None

    except requests.exceptions.HTTPError as e:
        if e.response is not None:
            status = e.response.status_code
            body   = e.response.text[:300]
        else:
            status, body = "?", str(e)

        if status == 401:
            log.error("Groq 401 — API key invalid or revoked. Update config.json and restart.")
        elif status == 404:
            log.error(f"Groq 404 — model '{GROQ_MODEL}' not found on your account. "
                      f"Run: python3 -c \"import requests,json; "
                      f"[print(m['id']) for m in requests.get('https://api.groq.com/openai/v1/models',"
                      f"headers={{'Authorization':'Bearer {GROQ_API_KEY}'}}).json()['data']]\"")
        elif status == 429:
            log.warning("Groq rate limit — waiting 10s")
            time.sleep(10)
        else:
            log.error(f"Groq HTTP {status}: {body}")
        return None

    except Exception as e:
        log.error(f"Groq error: {e}")
        return None

# ── JID helpers ───────────────────────────────────────────────────────────────
def jid_to_str(jid_obj) -> str:
    """Convert a neonize JID proto object to a clean string."""
    try:
        user   = jid_obj.User or ""
        server = jid_obj.Server or "s.whatsapp.net"
        return f"{user}@{server}"
    except Exception:
        return str(jid_obj)

def jid_number(jid: str) -> str:
    return jid.split("@")[0]

def is_group(jid: str) -> bool:
    return jid.endswith("@g.us")

# ── Filter logic ──────────────────────────────────────────────────────────────
def should_reply(sender_jid: str, chat_jid: str) -> bool:
    if IGNORE_OWN and jid_number(sender_jid) == PHONE_NUMBER:
        return False

    if is_group(chat_jid):
        if not ALLOW_GROUPS:
            return False
        gid = jid_number(chat_jid)
        if BLOCKED_GROUPS and gid in BLOCKED_GROUPS:
            return False
        if ALLOWED_GROUPS and gid not in ALLOWED_GROUPS:
            return False
        return True

    number = jid_number(sender_jid)
    if MODE == "whitelist":
        return number in ALLOWED
    if MODE == "blacklist":
        return number not in BLOCKED
    return True

# ── Client ────────────────────────────────────────────────────────────────────
client = NewClient("session.db")

@client.event(ConnectedEv)
def on_connected(_c, _e):
    log.info("✅ Connected to WhatsApp!")

@client.event(PairStatusEv)
def on_pair(_c, e):
    log.info(f"📱 Paired as: {e.ID.User}")

@client.event(MessageEv)
def on_message(_c, message: MessageEv):
    try:
        info       = message.Info
        chat_jid   = jid_to_str(info.MessageSource.Chat)
        sender_jid = jid_to_str(info.MessageSource.Sender)

        if info.MessageSource.IsFromMe:
            return

        # extract text (plain or extended)
        text = (
            message.Message.conversation
            or message.Message.extendedTextMessage.text
            or ""
        ).strip()

        if not text:
            return  # skip media, stickers, voice notes

        log.info(f"📩 {jid_number(sender_jid)}: {text[:80]}")

        if not should_reply(sender_jid, chat_jid):
            log.info(f"⏭  Skipped {jid_number(sender_jid)}")
            return

        if REPLY_DELAY > 0:
            time.sleep(REPLY_DELAY)

        reply = ask_groq(text)
        if reply:
            log.info(f"🤖 {reply[:80]}")
            _c.reply_message(reply, message)

    except Exception as e:
        log.error(f"Message handler error: {e}", exc_info=True)

# ── Main (with auto-reconnect) ────────────────────────────────────────────────
if __name__ == "__main__":
    log.info("🚀 WhatsApp AI Bot starting...")
    log.info(f"   Mode   : {MODE}")
    log.info(f"   Groups : {'on' if ALLOW_GROUPS else 'off'}")
    log.info(f"   Model  : {GROQ_MODEL}")
    log.info("")
    log.info("👉 Scan QR with WhatsApp: Linked Devices → Link Device")
    log.info("")

    while True:
        try:
            client.connect()
        except KeyboardInterrupt:
            log.info("Stopped by user.")
            sys.exit(0)
        except Exception as e:
            log.error(f"Disconnected: {e} — reconnecting in 5s...")
            time.sleep(5)
BOTEOF

# systemd service
WHOAMI=$(whoami)
cat > wa-bot.service << SVCEOF
[Unit]
Description=WhatsApp AI Autoresponder
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$WHOAMI
WorkingDirectory=$BOTDIR
ExecStart=$BOTDIR/venv/bin/python bot.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
SVCEOF

success "All files written"
echo ""

# ── Step 5: Venv + pip ─────────────────────────────────────────────────────────
echo -e "${YELLOW}[5/6] Creating virtualenv and installing packages...${NC}"

python -m venv venv || python3 -m venv venv || error "venv creation failed"
# shellcheck disable=SC1091
source venv/bin/activate

pip install --upgrade pip -q
pip install neonize requests -q

python -c "import neonize, requests" || error "Package import failed after install"
success "Packages installed and verified"
echo ""

# ── Step 6: Systemd (optional) ─────────────────────────────────────────────────
echo -e "${YELLOW}[6/6] Auto-start service${NC}"
ask "Install as systemd service? Runs in background, auto-starts on boot."
read -rp "  Install service? [Y/n]: " SVC_CHOICE

INSTALL_SERVICE=false
if [[ ! "${SVC_CHOICE:-}" =~ ^[Nn]$ ]]; then
    if command -v systemctl &>/dev/null; then
        INSTALL_SERVICE=true
        sudo cp wa-bot.service /etc/systemd/system/
        sudo systemctl daemon-reload
        sudo systemctl enable wa-bot
        success "Service installed and enabled on boot"
    else
        warn "systemd not found — skipping service install"
    fi
else
    warn "Skipped. Run manually: cd ~/wa && source venv/bin/activate && python bot.py"
fi
echo ""

# ── Done ──────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${GREEN}============================================${NC}"
echo -e "${BOLD}${GREEN}  ✅ Setup complete! Launching bot...      ${NC}"
echo -e "${BOLD}${GREEN}============================================${NC}"
echo ""
info "Scan QR with WhatsApp:"
echo -e "  Phone → ⋮ Menu → Linked Devices → Link Device"
echo ""

if [[ "$INSTALL_SERVICE" == true ]]; then
    warn "After QR scan — press Ctrl+C. Systemd keeps it alive automatically."
    echo -e "  Logs: sudo journalctl -u wa-bot -f"
else
    warn "Press Ctrl+C anytime to stop."
fi
echo ""

cd "$BOTDIR"
source venv/bin/activate
python bot.py || true

if [[ "$INSTALL_SERVICE" == true ]]; then
    echo ""
    info "Handing off to systemd..."
    sudo systemctl start wa-bot || true
    success "Bot running in background"
    echo -e "  Logs : sudo journalctl -u wa-bot -f"
    echo -e "  Stop : sudo systemctl stop wa-bot"
fi
