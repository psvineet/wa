#!/bin/bash
# WhatsApp AI Bot - Universal Setup
# Supports: Arch, Ubuntu, Debian, Fedora, CentOS, RHEL, openSUSE, Alpine
# Run: bash <(curl -s https://raw.githubusercontent.com/psvineet/wa/main/setup.sh)

set -euo pipefail
IFS=$'\n\t'

# ── Colors ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

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
echo -e "${YELLOW}[1/7] Detecting distro and installing packages...${NC}"
PKG_INSTALLED=false

if   command -v pacman  &>/dev/null; then info "Arch / Manjaro"
     sudo pacman -Sy --noconfirm python python-pip python-virtualenv curl; PKG_INSTALLED=true
elif command -v apt-get &>/dev/null; then info "Debian / Ubuntu / Mint"
     sudo apt-get update -qq && sudo apt-get install -y python3 python3-pip python3-venv curl; PKG_INSTALLED=true
elif command -v dnf     &>/dev/null; then info "Fedora / RHEL 8+ / AlmaLinux"
     sudo dnf install -y python3 python3-pip python3-virtualenv curl; PKG_INSTALLED=true
elif command -v yum     &>/dev/null; then info "CentOS / RHEL 7"
     sudo yum install -y python3 python3-pip curl && pip3 install --quiet virtualenv; PKG_INSTALLED=true
elif command -v zypper  &>/dev/null; then info "openSUSE"
     sudo zypper install -y python3 python3-pip python3-virtualenv curl; PKG_INSTALLED=true
elif command -v apk     &>/dev/null; then info "Alpine"
     sudo apk add --no-cache python3 py3-pip curl && pip3 install --quiet virtualenv; PKG_INSTALLED=true
fi

[[ "$PKG_INSTALLED" == false ]] && error "Unknown distro. Install python3 + pip manually then rerun."

if ! command -v python &>/dev/null; then
    PYTHON3_PATH="$(command -v python3)"
    sudo ln -sf "$PYTHON3_PATH" /usr/local/bin/python 2>/dev/null || \
    sudo ln -sf "$PYTHON3_PATH" /usr/bin/python       2>/dev/null || true
fi

python --version &>/dev/null || error "python3 not found after install."
success "Packages installed"
echo ""

# ── Step 2: Create project folder ──────────────────────────────────────────────
BOTDIR="$HOME/wa"
echo -e "${YELLOW}[2/7] Creating project at ~/wa ...${NC}"
mkdir -p "$BOTDIR" && cd "$BOTDIR"
success "Folder ready: $BOTDIR"
echo ""

# ── Step 3: Configuration ──────────────────────────────────────────────────────
echo -e "${YELLOW}[3/7] Configuration${NC}"
echo "  ─────────────────────────────────────────"
echo ""

# ── Groq API key
ask "Get your FREE Groq API key at:"
echo -e "  ${BOLD}https://console.groq.com${NC}"
echo -e "  Signup → API Keys → Create New Key (no credit card)"
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

# ── Fetch available chat models live
info "Fetching available models from your Groq account..."
MODELS_JSON=$(curl -sf https://api.groq.com/openai/v1/models \
    -H "Authorization: Bearer $GROQ_KEY" 2>/dev/null) || true

GROQ_MODEL=""
if [[ -z "$MODELS_JSON" ]]; then
    warn "Could not reach Groq API — defaulting to: openai/gpt-oss-20b"
    GROQ_MODEL="openai/gpt-oss-20b"
else
    mapfile -t CHAT_MODELS < <(
        echo "$MODELS_JSON" | python3 -c "
import json, sys, re
data = json.load(sys.stdin)
exclude = re.compile(r'whisper|tts|guard|safeguard|orpheus|allam|embed', re.I)
models = sorted([m['id'] for m in data.get('data',[]) if not exclude.search(m['id'])])
print('\n'.join(models))
" 2>/dev/null
    )

    if [[ ${#CHAT_MODELS[@]} -eq 0 ]]; then
        warn "No chat models found — defaulting to: openai/gpt-oss-20b"
        GROQ_MODEL="openai/gpt-oss-20b"
    else
        echo ""
        echo -e "  ${BOLD}Available models on your account:${NC}"
        echo ""
        for i in "${!CHAT_MODELS[@]}"; do
            printf "  ${CYAN}%2d)${NC} %s\n" "$((i+1))" "${CHAT_MODELS[$i]}"
        done
        echo ""
        while true; do
            read -rp "  Choose model number [1-${#CHAT_MODELS[@]}]: " MC
            if [[ "$MC" =~ ^[0-9]+$ ]] && (( MC >= 1 && MC <= ${#CHAT_MODELS[@]} )); then
                GROQ_MODEL="${CHAT_MODELS[$((MC-1))]}"
                success "Model: $GROQ_MODEL"
                break
            else
                warn "Enter a number between 1 and ${#CHAT_MODELS[@]}"
            fi
        done
    fi
fi
echo ""

# ── Phone number
ask "Your WhatsApp number (with country code, no + or spaces):"
echo -e "  India: ${BOLD}91${NC}9876543210 | US: ${BOLD}1${NC}2025551234 | UK: ${BOLD}44${NC}7911123456"
echo ""
PHONE=""
while true; do
    read -rp "  Phone number: " PHONE
    PHONE="${PHONE//[^0-9]/}"
    if [[ ${#PHONE} -ge 10 && ${#PHONE} -le 15 ]]; then
        success "Number: $PHONE"
        break
    else
        warn "Digits only, 10–15 characters, include country code"
    fi
done

# extract country code (first 1-3 digits heuristic)
# we store full number and let bot do suffix matching — no strict extraction needed
echo ""

# ── Bot personality
ask "Bot personality / system prompt (Enter for default):"
read -rp "  Prompt: " SYS_PROMPT
if [[ -z "${SYS_PROMPT:-}" ]]; then
    SYS_PROMPT="You are Vineet's personal AI assistant on WhatsApp. Reply on his behalf — be concise, warm, and natural. Match the language the sender uses (Hindi, English, or Hinglish). Never reveal you are an AI unless directly asked. Keep replies under 3 sentences. Always start every reply with 🤖"
fi
SYS_PROMPT="${SYS_PROMPT//\\/\\\\}"
SYS_PROMPT="${SYS_PROMPT//\"/\\\"}"
success "Prompt set"
echo ""

# ── Reply mode
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

# ── Contacts helper
build_json_array() {
    local -n arr=$1
    if [[ ${#arr[@]} -eq 0 ]]; then echo "[]"; return; fi
    local json="["
    for i in "${!arr[@]}"; do
        json+="\"${arr[$i]}\""
        [[ $i -lt $((${#arr[@]}-1)) ]] && json+=","
    done
    json+="]"; echo "$json"
}

ALLOWED_JSON="[]"; BLOCKED_JSON="[]"

if [[ "$MODE" == "whitelist" ]]; then
    ask "Allowed contacts — enter with country code (e.g. 919876543210). Empty line to finish."
    ALLOWED_LIST=()
    while true; do
        read -rp "  Number: " NUM; NUM="${NUM//[^0-9]/}"
        [[ -z "$NUM" ]] && break
        ALLOWED_LIST+=("$NUM"); success "Added $NUM"
    done
    ALLOWED_JSON="$(build_json_array ALLOWED_LIST)"
else
    ask "Blocked contacts — enter with country code (e.g. 919876543210). Empty line to finish."
    BLOCKED_LIST=()
    while true; do
        read -rp "  Number: " NUM; NUM="${NUM//[^0-9]/}"
        [[ -z "$NUM" ]] && break
        BLOCKED_LIST+=("$NUM"); success "Blocked $NUM"
    done
    BLOCKED_JSON="$(build_json_array BLOCKED_LIST)"
fi
echo ""

# ── Groups
ask "Reply in WhatsApp groups?"
read -rp "  Enable group replies? [y/N]: " GRP
if [[ "${GRP:-}" =~ ^[Yy]$ ]]; then
    ALLOW_GROUPS="true"; success "Groups enabled"
else
    ALLOW_GROUPS="false"; success "Groups disabled"
fi
echo ""

# ── Step 4: Write all files ────────────────────────────────────────────────────
echo -e "${YELLOW}[4/7] Writing bot files...${NC}"

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

# ── bot.py ─────────────────────────────────────────────────────────────────────
cat > bot.py << 'BOTEOF'
#!/usr/bin/env python3
"""
WhatsApp AI Autoresponder — neonize + Groq
Author : Vineet <ci.vps@proton.me>
GitHub : https://github.com/psvineet/wa
License: MIT
"""

import json, os, time, logging, sys, signal, requests
from neonize.client import NewClient
from neonize.events import MessageEv, ConnectedEv, PairStatusEv
from neonize.utils import log as neonize_log

# ── Paths (absolute so bot.log always lands in ~/wa/) ─────────────────────────
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
LOG_FILE = os.path.join(BASE_DIR, "bot.log")
DB_FILE  = os.path.join(BASE_DIR, "session.db")
CFG_FILE = os.path.join(BASE_DIR, "config.json")

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [wa-bot %(levelname)s] - %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE, encoding="utf-8"),
        logging.StreamHandler(sys.stdout)
    ]
)
log = logging.getLogger("wa-bot")
neonize_log.setLevel(logging.WARNING)

# suppress noisy neonize sub-loggers
for _noisy in ("neonize.utils.ffmpeg", "neonize.utils", "whatsmeow"):
    logging.getLogger(_noisy).setLevel(logging.CRITICAL)

# ── Config ────────────────────────────────────────────────────────────────────
try:
    with open(CFG_FILE) as f:
        cfg = json.load(f)
except Exception as e:
    log.error(f"Cannot read config.json: {e}")
    sys.exit(1)

GROQ_API_KEY   = cfg["groq_api_key"]
GROQ_MODEL     = cfg["groq_model"]
SYSTEM_PROMPT  = cfg["system_prompt"]
PHONE_NUMBER   = cfg["phone_number"].strip()
MODE           = cfg["mode"]
ALLOWED        = [n.strip() for n in cfg.get("allowed_contacts", [])]
BLOCKED        = [n.strip() for n in cfg.get("blocked_contacts", [])]
ALLOW_GROUPS   = cfg.get("allow_groups", False)
ALLOWED_GROUPS = [n.strip() for n in cfg.get("allowed_groups", [])]
BLOCKED_GROUPS = [n.strip() for n in cfg.get("blocked_groups", [])]
IGNORE_OWN     = cfg.get("ignore_own_messages", True)
REPLY_DELAY    = cfg.get("reply_delay_seconds", 1)

if not GROQ_API_KEY.startswith("gsk_"):
    log.error("groq_api_key must start with 'gsk_' — check config.json")
    sys.exit(1)

# ── Number normalisation + matching ───────────────────────────────────────────
def norm(number: str) -> str:
    """Strip non-digits and leading zeros/plus."""
    return number.strip().lstrip('+').lstrip('0').strip()

def numbers_match(stored: str, jid_num: str) -> bool:
    """
    Match phone numbers regardless of country-code prefix.
    E.g. stored='9876543210' matches jid_num='919876543210' (India prefix 91).
    Also handles full match when both have country code.
    """
    s = norm(stored)
    j = norm(jid_num)
    return j == s or j.endswith(s) or s.endswith(j)

def in_list(jid_num: str, number_list: list) -> bool:
    return any(numbers_match(n, jid_num) for n in number_list)

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
        status = e.response.status_code if e.response is not None else "?"
        body   = e.response.text[:300]  if e.response is not None else str(e)
        if status == 401:
            log.error("Groq 401 — API key invalid. Update config.json and restart.")
        elif status == 404:
            log.error(f"Groq 404 — model '{GROQ_MODEL}' not on your account. "
                      f"Run: ~/wa/run.sh --list-models")
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
    try:
        user   = jid_obj.User   or ""
        server = jid_obj.Server or "s.whatsapp.net"
        return f"{user}@{server}"
    except Exception:
        return str(jid_obj)

def jid_number(jid: str) -> str:
    return jid.split("@")[0]

def is_group(jid: str) -> bool:
    return jid.endswith("@g.us")

def is_lid(jid: str) -> bool:
    """LID JIDs (@lid) carry a Meta internal ID, not a phone number."""
    return jid.endswith("@lid")

# ── Filter ────────────────────────────────────────────────────────────────────
def should_reply(sender_jid: str, chat_jid: str) -> bool:
    # ignore own messages
    if IGNORE_OWN and numbers_match(PHONE_NUMBER, jid_number(sender_jid)):
        return False

    # group handling
    if is_group(chat_jid):
        if not ALLOW_GROUPS:
            return False
        gid = jid_number(chat_jid)
        if BLOCKED_GROUPS and in_list(gid, BLOCKED_GROUPS):
            return False
        if ALLOWED_GROUPS and not in_list(gid, ALLOWED_GROUPS):
            return False
        return True

    # LID JIDs — phone number unknown, cannot match against list
    if is_lid(sender_jid):
        # blacklist: unknown = not blocked → reply
        # whitelist: unknown = not confirmed → skip
        return MODE == "blacklist"

    number = jid_number(sender_jid)

    if MODE == "whitelist":
        return in_list(number, ALLOWED)
    if MODE == "blacklist":
        return not in_list(number, BLOCKED)
    return True

# ── Client ────────────────────────────────────────────────────────────────────
client = NewClient(DB_FILE)

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

# ── Main (signal-safe reconnect loop) ────────────────────────────────────────
_stop = False

def _shutdown(sig, frame):
    global _stop
    _stop = True
    log.info("Shutting down...")
    sys.exit(0)

if __name__ == "__main__":
    signal.signal(signal.SIGINT,  _shutdown)
    signal.signal(signal.SIGTERM, _shutdown)

    log.info("🚀 WhatsApp AI Bot starting...")
    log.info(f"   Mode   : {MODE}")
    log.info(f"   Groups : {'on' if ALLOW_GROUPS else 'off'}")
    log.info(f"   Model  : {GROQ_MODEL}")
    log.info(f"   Log    : {LOG_FILE}")
    log.info("")
    log.info("👉 Scan QR: Phone → Linked Devices → Link Device")
    log.info("")

    while not _stop:
        try:
            client.connect()
        except SystemExit:
            break
        except Exception as e:
            if _stop:
                break
            log.error(f"Disconnected: {e} — reconnecting in 5s...")
            for _ in range(5):
                if _stop:
                    break
                time.sleep(1)

    log.info("Stopped.")
BOTEOF

# ── run.sh ─────────────────────────────────────────────────────────────────────
cat > run.sh << 'RUNEOF'
#!/bin/bash
# WhatsApp AI Bot — launcher
# Activates venv automatically. Never run bot.py directly.
# Usage:
#   ./run.sh                 start the bot
#   ./run.sh --list-models   list chat models on your Groq account

BOTDIR="$(cd "$(dirname "$0")" && pwd)"
VENV="$BOTDIR/venv"

if [[ ! -f "$VENV/bin/activate" ]]; then
    echo "❌ Virtualenv not found at $VENV — run setup.sh first."
    exit 1
fi

# shellcheck disable=SC1091
source "$VENV/bin/activate"

if [[ "${1:-}" == "--list-models" ]]; then
    KEY=$(python3 -c "import json; print(json.load(open('$BOTDIR/config.json'))['groq_api_key'])" 2>/dev/null)
    if [[ -z "$KEY" ]]; then
        echo "❌ Cannot read groq_api_key from config.json"
        exit 1
    fi
    echo ""
    echo "  Chat models available on your Groq account:"
    echo ""
    curl -sf https://api.groq.com/openai/v1/models \
        -H "Authorization: Bearer $KEY" \
    | python3 -c "
import json, sys, re
data = json.load(sys.stdin)
exclude = re.compile(r'whisper|tts|guard|safeguard|orpheus|allam|embed', re.I)
models = sorted([m['id'] for m in data.get('data',[]) if not exclude.search(m['id'])])
[print(f'  - {m}') for m in models]
"
    echo ""
    echo "  To change model:"
    echo "    nano $BOTDIR/config.json   # update groq_model"
    echo "    $BOTDIR/run.sh"
    echo ""
    exit 0
fi

cd "$BOTDIR"
exec python3 bot.py
RUNEOF
chmod +x run.sh

# ── remove.sh ──────────────────────────────────────────────────────────────────
cat > remove.sh << 'RMEOF'
#!/bin/bash
# WhatsApp AI Bot — uninstaller

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
BOTDIR="$HOME/wa"

echo ""
echo -e "${BOLD}${RED}  WhatsApp AI Bot — Uninstaller${NC}"
echo "  ─────────────────────────────────────────"
echo ""
echo -e "${YELLOW}  This will remove:${NC}"
echo "    • Systemd service  : wa-bot"
echo "    • Bot directory    : $BOTDIR"
echo ""
read -rp "  Are you sure? Type YES to confirm: " CONFIRM
[[ "$CONFIRM" != "YES" ]] && echo "  Cancelled." && exit 0
echo ""

if command -v systemctl &>/dev/null; then
    if systemctl list-unit-files wa-bot.service &>/dev/null 2>&1; then
        echo -e "${YELLOW}  Stopping service...${NC}"
        sudo systemctl stop    wa-bot 2>/dev/null || true
        sudo systemctl disable wa-bot 2>/dev/null || true
        sudo rm -f /etc/systemd/system/wa-bot.service
        sudo systemctl daemon-reload
        echo -e "${GREEN}  ✓ Service removed${NC}"
    fi
fi

pkill -f bot.py 2>/dev/null || true

if [[ -d "$BOTDIR" ]]; then
    rm -rf "$BOTDIR"
    echo -e "${GREEN}  ✓ Removed $BOTDIR${NC}"
fi

echo ""
echo -e "${GREEN}${BOLD}  ✅ Uninstall complete.${NC}"
echo ""
RMEOF
chmod +x remove.sh

# ── systemd service (uses run.sh so venv always active) ────────────────────────
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
ExecStart=$BOTDIR/run.sh
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

# ── Step 5: Virtualenv + packages ──────────────────────────────────────────────
echo -e "${YELLOW}[5/7] Creating virtualenv and installing packages...${NC}"
python -m venv venv || python3 -m venv venv || error "venv creation failed"
# shellcheck disable=SC1091
source venv/bin/activate
pip install --upgrade pip -q
pip install neonize requests -q
python -c "import neonize, requests" || error "Package import failed — check pip output"
success "Packages installed and verified"
echo ""

# ── Step 6: Systemd (optional) ─────────────────────────────────────────────────
echo -e "${YELLOW}[6/7] Auto-start service${NC}"
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
        warn "systemd not found — skipping"
    fi
else
    warn "Skipped. Start anytime with: ~/wa/run.sh"
fi
echo ""

# ── Step 7: Launch ─────────────────────────────────────────────────────────────
echo -e "${YELLOW}[7/7] Launching bot...${NC}"
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║   ✅  Setup complete — starting bot...   ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
info "Scan QR with WhatsApp:"
echo -e "  Phone → ⋮ Menu → Linked Devices → Link Device"
echo ""

if [[ "$INSTALL_SERVICE" == true ]]; then
    warn "After QR scan — press Ctrl+C once. Systemd will keep it running."
    echo -e "  Logs   : sudo journalctl -u wa-bot -f"
    echo -e "  Stop   : sudo systemctl stop wa-bot"
    echo -e "  Remove : bash ~/wa/remove.sh"
else
    warn "Press Ctrl+C to stop. Next time start with: ${BOLD}~/wa/run.sh${NC}"
fi
echo ""

cd "$BOTDIR"
./run.sh || true

if [[ "$INSTALL_SERVICE" == true ]]; then
    echo ""
    info "Handing off to systemd..."
    sudo systemctl start wa-bot || true
    success "Bot running in background"
    echo -e "  Logs   : sudo journalctl -u wa-bot -f"
    echo -e "  Stop   : sudo systemctl stop wa-bot"
    echo -e "  Remove : bash ~/wa/remove.sh"
fi
