# hermes-ghl-installer

One command to stand up a **Hermes agent** with a **Twingate Connector** and a
**GoHighLevel CRM skill** on a clean, headless Ubuntu server.

Ships **credential-free** — designed to be handed to another operator who plugs
in their own Twingate tokens and GoHighLevel token. Nothing here is tied to any
existing account.

## What it installs

| Component | Source |
|---|---|
| **Twingate Connector** | `https://binaries.twingate.com/connector/setup.sh` |
| **Node.js LTS + npm** | NodeSource (`https://deb.nodesource.com/setup_lts.x`) |
| **Hermes agent** | `https://hermes-agent.nousresearch.com/install.sh` (NousResearch) |
| **GoHighLevel CRM skill** | `skills/productivity/gohighlevel-crm/` in this repo → `~/.hermes/skills/productivity/` |

## Quick start

Run as the **normal user** (not root) on the target Ubuntu box.

Get the Connector's three values from your Twingate Admin Console
(**Network → Connectors → add one → Deploy → Linux**), export them, then run the
installer — it provisions the connector automatically:

```bash
export TWINGATE_NETWORK="yourslug"        # the 'yourslug' in yourslug.twingate.com
export TWINGATE_ACCESS_TOKEN="..."
export TWINGATE_REFRESH_TOKEN="..."
curl -fsSL https://raw.githubusercontent.com/prhall0603/hermes-ghl-installer/main/install.sh | bash
```

No tokens exported? The installer still sets up Node, Hermes, and the GHL skill,
and prints how to finish the Twingate step by hand. Idempotent — re-running
skips anything already present.

## After install — 3 manual steps

1. **Twingate:** if you exported the tokens above, the connector is already
   live — verify with `sudo systemctl status twingate-connector`. Otherwise run
   the Linux Deploy command from your Twingate Admin Console.
2. **Hermes:** `hermes setup` — provide your own model / API key.
3. **GoHighLevel:** add your token to `~/.hermes/.env`:
   ```
   GHL_PIT=<your Private Integration Token>
   GHL_LOCATION_ID=<your sub-account/location id>
   GHL_WEBSITE=<your website (optional post CTA)>
   ```
   Required PIT scopes: `contacts.readonly`, `contacts.write`,
   `socialplanner/post.write`, `medias.write`, `calendars.readonly`
   (GoHighLevel → Settings → Private Integrations).

## Auto-start & power recovery

The installer registers a **systemd user service** (`hermes-gateway`) with
`Restart=always` and enables **linger**, so Hermes:

- starts automatically at boot (no login required),
- restarts automatically if it crashes.

Manage it:
```bash
systemctl --user status  hermes-gateway
systemctl --user restart hermes-gateway
journalctl --user -u hermes-gateway -f
```

**Powering the machine back on after an outage** is a firmware/host setting the
OS can't control:

- **Bare metal:** BIOS/UEFI → *Restore on AC Power Loss* = **On** (or *Last State*).
- **Proxmox / VM / LXC:** enable **Start at boot** for the guest.

With that set, the box powers up after an outage and the service brings Hermes
back on its own.

## The GoHighLevel skill

`skills/productivity/gohighlevel-crm/` teaches the agent to:

- Add/query contacts (incl. business-card → contact extraction)
- Post to connected social platforms via the Social Planner API
- Upload media to GHL storage and attach to posts
- List calendars and book/manage appointments

Plus battle-tested reference notes under `references/` covering API pitfalls
(header versioning, `summary` vs `caption`, `userId` requirement, Cloudflare
quirks), cron reliability, copywriting conventions, sub-account creation, and
SSH-over-VPN automation.

All account-specific IDs, tokens, and business details have been stripped and
replaced with placeholders (`$GHL_PIT`, `$GHL_LOCATION_ID`, `<YOUR_...>`).

## Requirements

- Ubuntu (headless is fine), `curl`, `sudo`, outbound internet.
- `git` (installed by the script if missing).

### Containers (LXC / Docker)

Works everywhere with no extra steps. The Twingate Connector runs entirely in
**userspace** and needs no `/dev/net/tun`, so bare metal, full VMs, and
unprivileged LXC/Docker containers are all fine — no host-side TUN passthrough
required (unlike a kernel-mode mesh VPN).

## Security

- No credentials are committed to this repo.
- Twingate tokens are passed via environment variables at install time and land
  only in `/etc/twingate/connector.conf` on the target machine — never in git.
- Add real GHL values only to `~/.hermes/.env` on the target machine (git-ignored
  by Hermes).
- Prefer SSH key auth for remote access; the password-PTY reference is for
  trusted LAN / VPN-tunnelled hosts only.

## License

MIT — see [LICENSE](LICENSE).
