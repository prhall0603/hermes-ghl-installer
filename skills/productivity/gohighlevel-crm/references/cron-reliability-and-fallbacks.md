# GHL Social Media Posting — Cron Reliability & Fallbacks

## Problem

Cron jobs scheduled to generate social media drafts can fail silently. You
expect a draft for review in the morning but never receive it. The job may have:
- Run and auto-deleted (one-shot jobs disappear after execution)
- Failed with an error that wasn't surfaced to the user
- Succeeded but the output got lost in message delivery

## Root Cause

One-shot cron jobs (`repeat: once`) execute at the scheduled time and then
auto-remove themselves. If the job output gets lost (delivery failure, message
not read, platform issue), the content is gone. There's no record of what
happened.

## Mitigation Strategies

### 1. Prefer recurring jobs with `repeat: forever`

Instead of:
```
schedule: "once at 2026-01-10 08:00"
repeat: once
```

Use:
```
schedule: "0 8 * * 5"   # Every Friday at 8 AM
repeat: forever
```

With `enabled: false` initially, then enable for the specific week:
```bash
hermes cron update --job-id <id> --enabled
```

This keeps the job visible in `cronjob list` and preserves history.

### 2. Deliver to `origin` (not `local`)

`deliver: local` means the job runs silently with no message to the user.
Always use `deliver: origin` for draft posts so the user sees them.

### 3. Include a manual generation command in the skill

Every social post skill should have a quick manual fallback:

```python
# Manual draft generation — run this if the cron fails
import os

post_name = "example_post"
base = os.path.expanduser("~/.hermes/images/posts")
html_path = f"{base}/{post_name}.html"
png_path = f"{base}/{post_name}.png"

if os.path.exists(html_path):
    with open(html_path) as f:
        print(f"=== {post_name} ===")
        print(f.read())
    print(f"\nImage: {png_path} (exists: {os.path.exists(png_path)})")
else:
    print(f"No local draft found for {post_name}")
```

### 4. Keep draft assets in predictable paths

All post assets should live in:
```
~/.hermes/images/posts/w{N}_{topic}.html
~/.hermes/images/posts/w{N}_{topic}.png
```

This lets the agent quickly find and present drafts even if the cron failed.

### 5. Pre-generate all drafts

Instead of generating content at post time, create all drafts ahead of time.
Store them locally. The cron job just presents the pre-made draft — no
generation risk, no API calls, no token usage.

```bash
# Pre-generate all drafts
for topic in topic_a topic_b topic_c topic_d; do
    python3 generate_post.py --topic $topic --week 2
done
```

Then cron jobs become simple:
```
"Read and present ~/.hermes/images/posts/w2_topic_a.html + .png"
```

## Image Generation Fallback

When local image generation fails (missing API key, no credits), fall back to a
manual tool such as Canva Magic Studio:

1. Save the image prompt to a text file
2. Give the user the tool instructions (e.g. Canva → Apps → Magic Studio →
   Text to Image)
3. Paste the prompt, generate, pick a favorite, add text overlays
4. User uploads the final image
5. Agent saves it to `~/.hermes/images/posts/`
6. Schedule the post with the saved image
