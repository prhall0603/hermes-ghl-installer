# hermes-ghl-installer

One command to stand up a **Hermes agent** with **Tailscale** and a
**GoHighLevel CRM skill** on a clean, headless Ubuntu server.

Ships **credential-free** — designed to be handed to another operator who plugs
in their own Tailscale login and GoHighLevel token. Nothing here is tied to any
existing account.

## What it installs

| Component | Source |
|---|---|
| **Tailscale** | `https://tailscale.com/install.sh` |
| **Node.js LTS + npm** | NodeSource (`https://deb.nodesource.com/setup_lts.x`) |
| **Hermes agent** | `https://hermes-agent.nousresearch.com/install.sh` (NousResearch) |
| **GoHighLevel CRM skill** | `skills/productivity/gohighlevel-crm/` in this repo → `~/.hermes/skills/productivity/` |

## Quick start

Run as the **normal user** (not root) on the target Ubuntu box:

```bash
curl -fsSL https://raw.githubusercontent.com/prhall0603/hermes-ghl-installer/main/install.sh | bash
```

The script is idempotent — re-running skips anything already present.

> **Private repo note.** This repo is private, so the raw one-liner and
> `git clone` need GitHub credentials on the target machine (a
> [fine-grained PAT](https://github.com/settings/tokens) with read access, or an
> SSH deploy key). Options:
> - Configure `gh auth login` / a PAT on the box first, **or**
> - Download `install.sh` + the `skills/` folder manually and run locally, **or**
> - Make the repo public if the skill content is safe to share.

## After install — 3 manual steps

1. **Tailscale:** `sudo tailscale up` (authorize the printed URL).
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
SSH-over-Tailscale automation.

All account-specific IDs, tokens, and business details have been stripped and
replaced with placeholders (`$GHL_PIT`, `$GHL_LOCATION_ID`, `<YOUR_...>`).

## Requirements

- Ubuntu (headless is fine), `curl`, `sudo`, outbound internet.
- `git` (installed by the script if missing).

### Containers (LXC / Docker)

Bare metal and full VMs work with no extra steps. Containers often lack
`/dev/net/tun`, which normally crashes `tailscaled`. The installer detects this
and falls back to **Tailscale userspace networking** so the node still joins the
tailnet — at the cost of subnet-router / exit-node ability. For full kernel
mode, pass TUN into the container from the host (e.g. Proxmox LXC):

```
# /etc/pve/lxc/<CTID>.conf
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file 0 0
```
then restart the container and re-run the installer.

## Security

- No credentials are committed to this repo.
- Add real values only to `~/.hermes/.env` on the target machine (git-ignored by
  Hermes).
- Prefer SSH key auth for remote access; the password-PTY reference is for
  trusted LAN / Tailscale-tunnelled hosts only.

## License

MIT — see [LICENSE](LICENSE).
