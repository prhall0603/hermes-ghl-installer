#!/usr/bin/env bash
#
# hermes-ghl-installer
# One-shot setup for a clean, headless Ubuntu server:
#   1. Tailscale       (mesh VPN)
#   2. Hermes agent    (NousResearch)
#   3. GoHighLevel CRM skill (contacts, social posting, calendar)
#
# Usage (one line, as the target user — NOT root):
#   curl -fsSL https://raw.githubusercontent.com/prhall0603/hermes-ghl-installer/main/install.sh | bash
#
# Idempotent: safe to re-run. Ships credential-free — you supply your own
# Tailscale auth and GoHighLevel token after install (see the printed steps).

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/prhall0603/hermes-ghl-installer/main"
REPO_GIT="https://github.com/prhall0603/hermes-ghl-installer.git"
SKILLS_SUBPATH="skills/productivity/gohighlevel-crm"
HERMES_SKILLS_DIR="${HOME}/.hermes/skills/productivity"

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] && die "Run as your normal user, not root. Hermes installs into \$HOME. Re-run without sudo."
command -v curl >/dev/null 2>&1 || die "curl is required. Install it: sudo apt-get update && sudo apt-get install -y curl"

# --- 0. base packages -------------------------------------------------------
log "Ensuring base packages (git, ca-certificates)…"
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update -y -qq || warn "apt-get update failed; continuing"
  sudo apt-get install -y -qq git ca-certificates || warn "apt-get install failed; continuing"
fi

# --- 1. Tailscale -----------------------------------------------------------
if command -v tailscale >/dev/null 2>&1; then
  log "Tailscale already installed ($(tailscale version | head -1)); skipping."
else
  log "Installing Tailscale…"
  curl -fsSL https://tailscale.com/install.sh | sh
fi
# TUN check: bare metal has /dev/net/tun; LXC/Docker containers often don't,
# and tailscaled crashes there with 'CreateTUN failed; /dev/net/tun does not
# exist'. Try to load the module; if still absent, fall back to userspace
# networking so the node still joins the tailnet.
if [ ! -c /dev/net/tun ]; then
  sudo modprobe tun 2>/dev/null || true
fi
if [ ! -c /dev/net/tun ]; then
  warn "No /dev/net/tun (container without TUN) — enabling Tailscale userspace networking."
  warn "  Tradeoff: no subnet-router/exit-node. For full mode, pass TUN into the container from the host."
  DEFAULTS="/etc/default/tailscaled"
  sudo touch "${DEFAULTS}"
  if grep -q '^FLAGS=' "${DEFAULTS}" 2>/dev/null; then
    grep -q -- '--tun=userspace-networking' "${DEFAULTS}" \
      || sudo sed -i 's|^FLAGS=.*|FLAGS="--tun=userspace-networking"|' "${DEFAULTS}"
  else
    echo 'FLAGS="--tun=userspace-networking"' | sudo tee -a "${DEFAULTS}" >/dev/null
  fi
fi

# Ensure the tailscaled daemon is running + enabled on boot (systemd hosts).
# The installer usually does this, but not on every image — `tailscale up`
# fails with "failed to connect to local tailscaled" if it isn't running.
if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files 2>/dev/null | grep -q '^tailscaled\.service'; then
  log "Enabling + (re)starting tailscaled daemon…"
  sudo systemctl enable tailscaled >/dev/null 2>&1 || true
  sudo systemctl restart tailscaled || warn "Could not start tailscaled; run: sudo systemctl restart tailscaled"
else
  warn "systemd/tailscaled service not detected — start the daemon manually before 'tailscale up'."
fi

# --- 1b. Node.js + npm ------------------------------------------------------
if command -v npm >/dev/null 2>&1; then
  log "npm already installed (npm $(npm -v), node $(node -v 2>/dev/null)); skipping."
else
  log "Installing Node.js LTS + npm…"
  if command -v apt-get >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
  else
    warn "apt-get not found; install Node.js/npm manually for your distro."
  fi
fi

# --- 2. Hermes agent --------------------------------------------------------
if [ -d "${HOME}/.hermes/hermes-agent/.git" ] || command -v hermes >/dev/null 2>&1; then
  log "Hermes already installed; skipping installer."
else
  log "Installing Hermes agent…"
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
fi

# --- 3. GoHighLevel CRM skill ----------------------------------------------
log "Installing GoHighLevel CRM skill…"
mkdir -p "${HERMES_SKILLS_DIR}"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

if git clone --depth 1 "${REPO_GIT}" "${TMP}/repo" >/dev/null 2>&1; then
  cp -R "${TMP}/repo/${SKILLS_SUBPATH}" "${HERMES_SKILLS_DIR}/"
else
  warn "git clone failed (private repo without creds?). Falling back to raw download."
  DEST="${HERMES_SKILLS_DIR}/gohighlevel-crm"
  mkdir -p "${DEST}/references"
  curl -fsSL "${REPO_RAW}/${SKILLS_SUBPATH}/SKILL.md" -o "${DEST}/SKILL.md"
  for f in appointment-reminders sub-account-creation social-media-copywriting-rules \
           cron-reliability-and-fallbacks openrouter-resale-pricing ssh-password-pty; do
    curl -fsSL "${REPO_RAW}/${SKILLS_SUBPATH}/references/${f}.md" -o "${DEST}/references/${f}.md"
  done
fi
log "Skill installed at ${HERMES_SKILLS_DIR}/gohighlevel-crm"

# --- 4. Ensure ~/.local/bin on PATH -----------------------------------------
# Hermes drops its launcher in ~/.local/bin. Ubuntu only adds that dir to PATH
# at login, and only if it already existed — so a fresh install in this session
# leaves `hermes` off PATH until the guard below is in the shell rc.
LOCAL_BIN="${HOME}/.local/bin"
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
for rc in "${HOME}/.bashrc" "${HOME}/.profile"; do
  [ -f "${rc}" ] || touch "${rc}"
  if ! grep -qF '.local/bin' "${rc}"; then
    printf '\n# Added by hermes-ghl-installer\n%s\n' "${PATH_LINE}" >> "${rc}"
    log "Added ~/.local/bin to PATH in ${rc}"
  fi
done
# Make hermes usable in THIS shell too (harmless if already present).
case ":${PATH}:" in
  *":${LOCAL_BIN}:"*) : ;;
  *) export PATH="${LOCAL_BIN}:${PATH}" ;;
esac
command -v hermes >/dev/null 2>&1 && log "hermes on PATH: $(command -v hermes)" \
  || warn "hermes not found on PATH — open a new shell or run: source ~/.bashrc"

# --- done -------------------------------------------------------------------
cat <<'EOF'

============================================================
  Install complete. Reload your shell first, then 3 steps:
============================================================

0) Pick up the updated PATH (or just open a new shell):
     source ~/.bashrc
   Verify:  command -v hermes

1) Connect this machine to your Tailscale network:
     sudo tailscale up
   (opens a login URL — authorize it in your Tailscale account)
   If it says "failed to connect to local tailscaled":
     sudo systemctl enable --now tailscaled && sudo tailscale up

2) Configure the Hermes agent:
     hermes setup            # or: hermes --help
   Provide your own model / API key here.

3) Add your GoHighLevel credentials to ~/.hermes/.env :
     GHL_PIT=<your Private Integration Token>
     GHL_LOCATION_ID=<your sub-account/location id>
     GHL_WEBSITE=<your website, optional post CTA>

   PIT scopes needed: contacts.readonly, contacts.write,
   socialplanner/post.write, medias.write, calendars.readonly
   (Settings -> Private Integrations in GoHighLevel.)

The GHL skill ships with NO credentials — it reads the values above
at runtime. See the skill's SKILL.md for full API usage.
============================================================
EOF
