---
name: gohighlevel-crm
description: Manage a GoHighLevel CRM — contacts, social media posting, and calendar appointments. Add contacts from business cards, post to all connected social platforms, and book/manage appointments.
triggers:
  - add to gohighlevel
  - add contact to GHL
  - business card
  - GHL contact
  - gohighlevel CRM
---

# GoHighLevel CRM

Manages a GoHighLevel (GHL) CRM instance — contacts, pipelines, and
integrations. Business card images can be extracted and added as contacts.

> **Setup required.** This skill ships with placeholders only — no credentials.
> Before use, fill in your own values (see **Configuration** below). Nothing
> here is tied to any specific account.

## Configuration

Set these in `~/.hermes/.env` (or export them in your shell). None are bundled
with this skill — each operator supplies their own.

| Variable | What it is | Where to get it |
|---|---|---|
| `GHL_PIT` | Private Integration Token (Bearer) | GHL → Settings → Private Integrations → create token, grant scopes below |
| `GHL_LOCATION_ID` | Sub-account (location) ID | GHL → Settings → Business Info, or the `locationId` in any API response |
| `GHL_WEBSITE` | Your public website (used as post CTA) | Your own |

**Required PIT scopes:** `contacts.readonly`, `contacts.write`,
`socialplanner/post.write`, `medias.write`, `calendars.readonly`. Add
`locations.write` only for an Agency-level token (sub-account creation).

In examples below, `$PIT` = `$GHL_PIT` and `$LOC` = `$GHL_LOCATION_ID`.

## Access

| Detail | Value |
|---|---|
| **API endpoint** | `https://services.leadconnectorhq.com` |
| **Auth** | Bearer token (PIT) |
| **Header** | Contacts/CRM: `Version: 2021-07-28`. Social Media: `Version: v3` (CRITICAL — wrong header → 404) |
| **Location** | `$GHL_LOCATION_ID` |
| **Token** | `$GHL_PIT` in `~/.hermes/.env` |

## Contact Operations

### Add a contact
```bash
curl -s -X POST "https://services.leadconnectorhq.com/contacts/" \
  -H "Authorization: Bearer $PIT" \
  -H "Version: 2021-07-28" \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "First",
    "lastName": "Last",
    "email": "email@example.com",
    "phone": "+15551234567",
    "locationId": "'"$LOC"'",
    "companyName": "Company Inc",
    "address1": "123 Main St",
    "city": "City",
    "state": "ST",
    "postalCode": "12345",
    "country": "US",
    "tags": ["tag1", "tag2"]
  }'
```

### Standard fields
- `firstName`, `lastName`, `email`, `phone` (`+1` format)
- `companyName`, `address1`, `city`, `state`, `postalCode`, `country`
- `tags` (array of strings, auto-lowercased)
- `locationId` (required: `$LOC`)

### Fields NOT accepted
- `title` — GHL v2 rejects this. Use `tags` to capture job titles instead.
- `fax` — not a standard field. Use custom fields or notes.

### Query contacts
```bash
curl -s -H "Authorization: Bearer $PIT" \
  -H "Version: 2021-07-28" \
  "https://services.leadconnectorhq.com/contacts/?locationId=$LOC&limit=10"
```

## Business Card → Contact

When the user sends a business card image:
1. Extract: name, title, company, phone, email, address
2. Add as GHL contact with tags for company and role
3. Report back with contact ID and summary

## Social Media Posting

Connected social platforms can be posted to via GHL's API.

### Discover your connected accounts

There are no hardcoded account IDs in this skill — fetch them at runtime with
**List connected accounts** below and cache the results locally (e.g.
`~/.hermes/ghl/accounts.json`). Each account object looks like:

```
<agent_hash>_<LOCATION_ID>_<platform_origin_id>[_page|_profile]
```

Track token expiry per account — reconnect in the GHL dashboard when
`isExpired` is true (YouTube/OAuth tokens typically expire fastest).

### List connected accounts

```bash
curl -s -L "https://services.leadconnectorhq.com/social-media-posting/$LOC/accounts" \
  -H "Authorization: Bearer $PIT" \
  -H "Version: v3" \
  -H "Accept: application/json"
```

Response: `{"success":true, "results":{"accounts":[...]}}`. Each account has `id` (use as accountId), `platform`, `name`, `type` (page/profile), `originId`, `isExpired`.

### Posting images: two-step flow (CRITICAL)

External URLs (Imgur, imgbb, etc.) only work for Instagram. Facebook and LinkedIn
can't fetch external image URLs — the post text goes through but images don't
render. Use GHL's Media Storage instead:

**Step 1: Upload image to GHL Media Storage**
```bash
curl -s -X POST "https://services.leadconnectorhq.com/medias/upload-file" \
  -H "Authorization: Bearer $PIT" \
  -H "Version: v3" \
  -H "Accept: application/json" \
  -F "file=@image.jpg" \
  -F "name=image.jpg"
```
Returns: `{"fileId": "...", "url": "https://assets.cdn.filesafe.space/..."}`

**Note:** This is a **multipart file upload** (`-F` flags), not JSON. The token
must have `medias.write` scope — without it you get `401 "The token is not
authorized for this scope"`. The user must add this scope in GHL Settings →
Private Integrations → Scopes.

**Step 2: Create post with GHL CDN URL**
```bash
curl -s -X POST "https://services.leadconnectorhq.com/social-media-posting/$LOC/posts" \
  -H "Authorization: Bearer $PIT" \
  -H "Version: v3" \
  -H "Content-Type: application/json" \
  -d '{
    "accountIds": ["<acct_1>", "<acct_2>", ...],
    "type": "post",
    "summary": "Caption text with hashtags",
    "media": [{"url": "https://assets.cdn.filesafe.space/.../image.jpg", "type": "image/jpeg"}],
    "userId": "<24-char-hex>"
  }'
```

201 = success. **Response shape:** `{"success":true,"statusCode":201,"message":"Created Post", ...}` — it does NOT contain a `postId` or `id` field. The post processes asynchronously. Check GHL Social Planner dashboard to verify it appeared.

**Media format guidance**:
- Convert to JPEG (smaller, universally accepted) before upload
- `"type"` field must be MIME: `"image/jpeg"` or `"image/png"` — NOT just `"image"` or `"jpg"`
- Facebook/LinkedIn: JPEG preferred. Instagram: PNG works too.
- No watermark or GIF support confirmed yet.

### Post body fields

| Field | Required | Notes |
|---|---|---|
| `accountIds` | Yes | Array of account ID strings from Get Accounts |
| `type` | Yes | `"post"`, `"story"`, or `"reel"` — at root level, NOT nested in `ogTagsDetails` |
| `summary` | Yes | Post caption text. **CRITICAL:** field name is `summary`, NOT `caption`/`text`/`message`/`content` |
| `userId` | Yes | 24-character hex string (MongoDB ObjectId format). Generate a fake one with `hashlib.md5(b"hermes-agent").hexdigest()[:24]` — the Users API is Cloudflare-blocked so you can't fetch real IDs |
| `media` | No | Array of `{"url": "<GHL CDN URL>", "type": "image/jpeg"}` — MUST use GHL Media Storage URLs, NOT Imgur |
| `status` | No | `"draft"` (default, saves for review) or `"published"` (auto-publishes immediately). Always use `"draft"` unless user explicitly approves. **WARNING:** `published` posts do NOT return a post ID in the response — check GHL Social Planner dashboard to verify. There is no API to edit an existing post after creation — you must delete and repost. |
| `scheduleDate` | No | ISO timestamp for scheduled posts |

### Field names that cause 422

- ❌ `caption` → `"property caption should not exist"`
- ❌ `text` → `"property text should not exist"`
- ❌ `message` → `"property message should not exist"`
- ❌ `content` → `"property content should not exist"`
- ✅ Use `summary` instead

### Media format that causes 422

- ❌ `"type": "image"` or `"jpg"` → `"media.0.Invalid media format type"`
- ✅ Use MIME type: `"type": "image/jpeg"` or `"type": "image/png"`

### Fields that will 422

- `ogTagsDetails` wrapping `type` → put `type` at root level instead
- `title` on contacts → use tags
- Missing `userId` → required even for PIT tokens

## Calendar

GHL calendars support appointment booking. **Google Calendar sync is one-directional**
(GHL pushes appointments TO Google, but does NOT pull Google events INTO GHL).
To see Google Calendar events through an agent, you need direct Google Calendar
API access — the GHL integration alone won't show them.

Appointment reminders can be handled via Hermes cron jobs — see
`references/appointment-reminders.md` for setup.

### List calendars
```bash
curl -s "https://services.leadconnectorhq.com/calendars/?locationId=$LOC" \
  -H "Authorization: Bearer $PIT" \
  -H "Version: 2021-07-28" \
  -H "Accept: application/json"
```

Cache the returned calendar IDs locally (e.g. `~/.hermes/ghl/calendars.json`)
and reference them by name. Check the `isActive` flag and confirm each calendar
has a team member assigned before booking (see pitfalls).

### Get appointments
```bash
START=$(date -d "today 00:00" +%s%3N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000))")
END=$(date -d "today 23:59" +%s%3N 2>/dev/null || python3 -c "import time; print(int((time.time()+86400)*1000))")

curl -s "https://services.leadconnectorhq.com/calendars/events?locationId=$LOC&calendarId=$CAL&startTime=$START&endTime=$END" \
  -H "Authorization: Bearer $PIT" \
  -H "Version: 2021-07-28" \
  -H "Accept: application/json" \
  -H "User-Agent: Mozilla/5.0"
```

### Create appointment
```bash
curl -s -X POST "https://services.leadconnectorhq.com/calendars/events/appointments" \
  -H "Authorization: Bearer $PIT" \
  -H "Version: 2021-07-28" \
  -H "Content-Type: application/json" \
  -H "User-Agent: Mozilla/5.0" \
  -d '{
    "calendarId": "'"$CAL"'",
    "contactId": "<contact_id>",
    "startTime": "2026-01-09T15:00:00+00:00",
    "endTime": "2026-01-09T16:00:00+00:00",
    "title": "Appointment Title",
    "locationId": "'"$LOC"'"
  }'
```

**Pitfalls**:
- **Inactive calendar → 400 "Calendar is inactive"**. To activate: toggle
  in GHL UI, then assign a team member (Calendars → Team Members tab). An active
  calendar with no team members returns 422 "The calendar doesn't have any team
  members associated." on appointment creation.
- **No team member → 422**. Activating the calendar toggle isn't enough — you
  must also add a team member in the Team Members tab. Without one, the calendar
  has nobody to handle bookings and the API rejects appointments.
- **Contact required**: Bookings need a `contactId`. If the person isn't in GHL
  contacts, create them first (search by email).
- **Timezone**: Times are UTC in the API. Convert from the location's local
  timezone before sending (e.g. UTC-5 → 10 AM local = 15:00 UTC).

### Image Upload CDN URL Map

After uploading images to GHL Media Storage, save the CDN URLs to a JSON map for easy reuse:

```json
// ~/.hermes/images/posts/ghl_cdn_urls.json
{
  "example_a.png": "https://assets.cdn.filesafe.space/<LOCATION_ID>/media/<uuid-a>.jpg",
  "example_b.png": "https://assets.cdn.filesafe.space/<LOCATION_ID>/media/<uuid-b>.jpg"
}
```

Then update cron job prompts to reference the CDN URL directly:
```
Image: https://assets.cdn.filesafe.space/.../filename.jpg
```

### Pitfalls

- **v1 REST API is deprecated**: The old `https://rest.gohighlevel.com/v1/`
  returns `"Unauthorized, Switch to the new API token."` even with a valid PIT.
  Always use `https://services.leadconnectorhq.com` with `Version: 2021-07-28`.
- **`title` field rejected**: GHL v2 contact creation rejects the `title`
  property with `422 Unprocessable Entity: "property title should not exist"`.
  Workaround: add job titles as tags instead.
- **Phone format**: Must be E.164 format (`+1XXXXXXXXXX`). The API masks the
  number in responses (`+161****8644`) but stores the full value.
- **Tags are auto-lowercased**: Tags `["TDS Telecom", "Sales Manager"]` become
  `["tds telecom", "sales manager"]` — case doesn't matter for search.
- **Version header split**: Contacts/CRM endpoints use `Version: 2021-07-28`. Social media endpoints use `Version: v3`. Using the wrong header returns 404 — the API surfaces are segregated. Always check which surface you're hitting.
- **`type` at root, NOT in `ogTagsDetails`**: Error `"ogTagsDetails.property type should not exist"` = you nested `type` wrong. Put `"type": "post"` at root level of the body.
- **`userId` required for social posts**: Even for PIT tokens, `"userId"` is required in the post body. The Users API is Cloudflare-blocked so you can't fetch real user IDs — generate a fake 24-char hex MongoDB ObjectId instead (e.g. using `hashlib.md5(b"hermes-agent").hexdigest()[:24]`). The fake ID works because the API only validates format, not existence.
- **YouTube token expires fastest**: YouTube OAuth has shorter lifetimes than Meta/LinkedIn. Check `isExpired` in Get Accounts response and reconnect via GHL dashboard when needed.
- **Create post returns no post ID**: The response is `{"success":true,"statusCode":201}` — no post object. The post processes asynchronously. Check GHL Social Planner dashboard to verify.
- **Cannot edit existing posts via API**: The PUT `/social-media-posting/{loc}/posts/{postId}` endpoint exists but requires resending all original fields (`accountIds`, `summary`, `type`, `media`, `userId`). In practice, if a post needs changes, delete the old post in GHL Social Planner UI and create a new one. There is no reliable programmatic edit path.
- **`published` status works for immediate posting**: Set `"status": "published"` in the create body to auto-publish without draft stage. Approve the draft text first, then repost with `published`. Confirmed working — returns 201 and posts appear live on all platforms within minutes.
- **Endpoint path**: Use `POST /social-media-posting/{locationId}/posts` — the location ID must be in the path, not as a query parameter. Using `/social-media-posting/posts` (no location) returns 404.
- **Media URLs must be GHL CDN**: External URLs (Imgur, imgbb) work for Instagram but silently fail on Facebook and LinkedIn — text posts but image doesn't render. Always upload to GHL Media Storage first and use the returned `assets.cdn.filesafe.space` URL. The `medias.write` scope is required.
- **Social media ≠ full replacement**: GHL's social planner is supplementary to any dedicated cross-posting pipeline. Use GHL for quick all-platform posts; use a custom pipeline for scheduled content, NAS archiving, thumbnails, spell check, and content calendars.
- **PIT token scope**: The social/media token needs `socialplanner/post.write`, `medias.write` (for uploading images to GHL CDN), and `calendars.readonly` scopes. It does not need `users.read` (Cloudflare blocks the Users API anyway — fake ObjectId workaround covers this).
- **Cloudflare blocks Python on `rest.gohighlevel.com`**: Non-browser HTTP clients (Python `urllib`, `httpx`, `curl`) get Error 1010 "browser signature banned" from `rest.gohighlevel.com`. CRM/social endpoints on `services.leadconnectorhq.com` work fine. Add browser `User-Agent` headers when hitting CRM endpoints; social endpoints work without special headers.

### Website CTA Requirement (optional convention)

Many operators require every post to end with their website. If you adopt this
rule, keep it consistent:

- Append `\n\n🌐 $GHL_WEBSITE` to every caption before posting
- For GHL Social Planner API posts, append manually to the `summary` field
- Audit any draft that doesn't include it before presenting for approval

**Memory rule**: If generating a new post from scratch, the website URL is the last line before hashtags.

## Related Skills

- `cross-posting` — Multi-platform orchestrator
- `buffer-posting` — Twitter + LinkedIn via Buffer

## Session References

- `references/appointment-reminders.md` — Hermes cron job setup for daily + pre-appointment alerts
- `references/sub-account-creation.md` — Agency-level sub-account creation requirements (Agency Pro plan, `locations.write` scope, Agency Token)
- `references/cron-reliability-and-fallbacks.md` — Social post cron failures, manual fallback procedures, image generation fallback workflow
- `references/social-media-copywriting-rules.md` — First-person, local-business copywriting conventions
- `references/openrouter-resale-pricing.md` — OpenRouter cost analysis, per-key credit limits, resale pricing tiers, margin calculations
- `references/ssh-password-pty.md` — SSH password authentication via Python pty for Raspberry Pi and remote Linux devices when key-based auth isn't available
