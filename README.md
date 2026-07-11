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

## Security

- No credentials are committed to this repo.
- Add real values only to `~/.hermes/.env` on the target machine (git-ignored by
  Hermes).
- Prefer SSH key auth for remote access; the password-PTY reference is for
  trusted LAN / Tailscale-tunnelled hosts only.

## License

MIT — see [LICENSE](LICENSE).
