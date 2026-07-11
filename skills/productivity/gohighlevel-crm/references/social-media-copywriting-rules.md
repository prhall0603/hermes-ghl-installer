# Social Media Copywriting Rules

Conventions for writing personal, local-business social posts that avoid generic
"AI marketing speak." Adapt the placeholders to your own brand and region.

## Tone Rules

1. **Lead with a hook** — relatable pain point or question
2. **First person** — "I walked into a client's office..."
3. **Specific details** — dollar amounts, brand names, locations
4. **Active voice** — "I fixed it" not "It was fixed"
5. **One CTA** — message me, visit site, save post
6. **Local anchor** — reference your city / region (`<YOUR_CITY>`, `<YOUR_REGION>`)
7. **No AI-speak** — ban "leverage," "optimize," "synergize"
8. **No generic tech-bro branding** — no "disrupt," "scale," empty buzzwords
9. **No assistant/bot name in client-facing posts** — position around the
   business and location, not the tooling behind it

## Post Structure (Pain-Agitate-Solve)

```
[HOOK] "I got a call at 6 PM on a Friday..."
[AGITATE] "He thought he was fine. He wasn't."
[SOLUTION] "Here's what I set up..."
[CTA] "Message me or visit the site."
🌐 <YOUR_WEBSITE>
```

## Image Handling

- Convert PNG to JPEG before GHL upload
- Upload to GHL Media Storage: `POST /medias/upload-file`
- Save CDN URLs to `~/.hermes/images/posts/ghl_cdn_urls.json`
- Reference CDN URL in cron prompts
- Match image to post topic

## Website CTA (if adopted)

- Every post ends with: `\n\n🌐 <YOUR_WEBSITE>`
- Optionally include a followers hashtag before the URL
- Audit every draft before approval

## Example Hooks by Topic (adapt to your industry)

| Topic | Hook |
|---|---|
| Security Audit | "I spent the morning doing a security audit for a local business..." |
| Storage/NAS | "I walked into a client's office and saw 15 years of files on one hard drive." |
| Backup | "I got a call at 6 PM on a Friday. A server had died." |
| 3-2-1 Rule | "He pointed to a USB drive in his desk drawer. That was it." |
| Connectivity | "Zoom dropped three times in 20 minutes. Internet 'worked fine' — until it didn't." |
| Smart Home | "I installed smart locks for a local business. Now they just send a code." |
| Hardware | "$40 router from a big-box store handling 20 devices. Owner wondered why cameras went offline." |
| Automation | "An owner told me: 'I spend 3 hours every Sunday scheduling posts.'" |

## Guiding Principle

Authentic, distinct voice > polished corporate speak.
