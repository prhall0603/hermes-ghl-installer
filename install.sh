#!/usr/bin/env bash
#
# hermes-ghl-installer
# One-shot setup for a clean, headless Ubuntu server:
#   1. Twingate Connector  (zero-trust remote access gateway)
#   2. Hermes agent        (NousResearch)
#   3. GoHighLevel CRM skill (contacts, social posting, calendar)
#
# Usage (one line, as the target user — NOT root):
#   curl -fsSL https://raw.githubusercontent.com/prhall0603/hermes-ghl-installer/main/install.sh | bash
#
# The Twingate Connector needs three values from your Twingate Admin Console
# (Network -> Connectors -> Deploy -> Linux). Export them BEFORE running to have
# the installer wire it up automatically; otherwise the connector package is
# installed and you finish setup by hand:
#   export TWINGATE_NETWORK="yourslug"          # the 'yourslug' in yourslug.twingate.com
#   export TWINGATE_ACCESS_TOKEN="..."
#   export TWINGATE_REFRESH_TOKEN="..."
#   curl -fsSL https://raw.githubusercontent.com/prhall0603/hermes-ghl-installer/main/install.sh | bash
#
# Idempotent: safe to re-run. Ships credential-free — you supply your own
# Twingate tokens and GoHighLevel token (see the printed steps).

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

# --- 1. Twingate Connector --------------------------------------------------
# The Connector is a zero-trust gateway: it runs entirely in USERSPACE and needs
# NO /dev/net/tun, so it works in LXC/Docker containers with no host changes.
# Its Linux install is a script from binaries.twingate.com that also expects the
# three per-connector values generated in the Twingate Admin Console.
TG_CONF="/etc/twingate/connector.conf"
if systemctl list-unit-files 2>/dev/null | grep -q '^twingate-connector\.service' || [ -f "${TG_CONF}" ]; then
  log "Twingate Connector already installed; skipping."
elif [ -n "${TWINGATE_NETWORK:-}" ] && [ -n "${TWINGATE_ACCESS_TOKEN:-}" ] && [ -n "${TWINGATE_REFRESH_TOKEN:-}" ]; then
  log "Installing + provisioning Twingate Connector (network: ${TWINGATE_NETWORK})…"
  curl -fsSL "https://binaries.twingate.com/connector/setup.sh" \
    | sudo TWINGATE_NETWORK="${TWINGATE_NETWORK}" \
           TWINGATE_ACCESS_TOKEN="${TWINGATE_ACCESS_TOKEN}" \
           TWINGATE_REFRESH_TOKEN="${TWINGATE_REFRESH_TOKEN}" \
           TWINGATE_LABEL_DEPLOYED_BY="hermes-ghl-installer" bash \
    || warn "Twingate setup script failed — verify tokens and network slug."
else
  warn "No Twingate tokens in env — installing nothing for Twingate yet."
  warn "  Finish setup from your Twingate Admin Console:"
  warn "    Network -> Connectors -> (add) -> Deploy -> Linux, then run that command here."
  warn "  Or re-run this installer with these exported first:"
  warn "    TWINGATE_NETWORK / TWINGATE_ACCESS_TOKEN / TWINGATE_REFRESH_TOKEN"
fi
# Safety net: make sure the connector service is enabled + running on boot.
if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files 2>/dev/null | grep -q '^twingate-connector\.service'; then
  sudo systemctl enable --now twingate-connector 2>/dev/null \
    || warn "Could not start twingate-connector; check: sudo systemctl status twingate-connector"
  log "Twingate Connector service enabled (starts on boot)."
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

# --- 5. Auto-start Hermes on boot (survives reboot / power loss) -------------
# Installs a systemd *user* service that runs the Hermes gateway with
# Restart=always, and enables linger so it starts at boot WITHOUT a login.
HERMES_HOME="${HOME}/.hermes"
VENV="${HERMES_HOME}/hermes-agent/venv"
UNIT_DIR="${HOME}/.config/systemd/user"
if command -v systemctl >/dev/null 2>&1 && [ -x "${VENV}/bin/python" ]; then
  log "Installing hermes-gateway systemd user service…"
  mkdir -p "${UNIT_DIR}"
  cat > "${UNIT_DIR}/hermes-gateway.service" <<EOF
[Unit]
Description=Hermes Agent Gateway - Messaging Platform Integration
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStart=${VENV}/bin/python -m hermes_cli.main gateway run
WorkingDirectory=${HERMES_HOME}
Environment="PATH=${VENV}/bin:${HERMES_HOME}/hermes-agent/node_modules/.bin:${HERMES_HOME}/node/bin:${HOME}/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="VIRTUAL_ENV=${VENV}"
Environment="HERMES_HOME=${HERMES_HOME}"
Restart=always
RestartSec=5
RestartForceExitStatus=75
KillMode=mixed
KillSignal=SIGTERM
ExecReload=/bin/kill -USR1 \$MAINPID
ExecStopPost=-${VENV}/bin/python -m gateway.cgroup_cleanup
TimeoutStopSec=210
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable --now hermes-gateway 2>/dev/null \
    || warn "Could not enable hermes-gateway user service; check: systemctl --user status hermes-gateway"
  # Linger = user services start at boot without an interactive login.
  sudo loginctl enable-linger "${USER}" 2>/dev/null \
    || warn "Could not enable linger; run: sudo loginctl enable-linger ${USER}"
  log "Hermes will auto-start on boot and restart on crash."
else
  warn "Skipped Hermes autostart (no systemd or venv missing). Configure a service manually."
fi

# --- done -------------------------------------------------------------------
cat <<'EOF'

============================================================
  Install complete. Reload your shell first, then 3 steps:
============================================================

0) Pick up the updated PATH (or just open a new shell):
     source ~/.bashrc
   Verify:  command -v hermes

1) Twingate Connector remote access:
   - If you exported TWINGATE_NETWORK / ACCESS / REFRESH tokens, it is
     already provisioned. Check it:
       sudo systemctl status twingate-connector
   - If not, open your Twingate Admin Console -> Network -> Connectors ->
     Deploy -> Linux, and run that generated command here (or re-run this
     installer with the three TWINGATE_* vars exported).

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

------------------------------------------------------------
  Auto-start on boot: ENABLED (systemd user service +
  linger). Manage it with:
     systemctl --user status  hermes-gateway
     systemctl --user restart hermes-gateway
     journalctl --user -u hermes-gateway -f

  POWER-LOSS AUTO-POWER-ON is a firmware/host setting the OS
  cannot set for you:
   * Bare metal: BIOS/UEFI -> "Restore on AC Power Loss" =
     On (or Last State).
   * Proxmox/VM/LXC: enable "Start at boot" for this guest.
  With that set, the box powers up after an outage and this
  service brings Hermes back automatically.
------------------------------------------------------------
EOF
