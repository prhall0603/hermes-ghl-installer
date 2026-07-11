# OpenRouter Resale Pricing & Per-Key Credit Limits

> All figures below are **illustrative examples** to show the method — measure
> your own usage before setting prices. No account-specific data here.

## Cost Analysis (example)

### Example API Costs (6-day sample)

| Metric | Value | Monthly Estimate |
|---|---|---|
| Sessions | 42 | ~210 |
| Messages | 1,297 | ~6,485 |
| Tool calls | 579 | ~2,895 |
| Input tokens | 15.4M | ~77M |
| Output tokens | 418K | ~2.1M |
| API cost (deepseek-v4-pro @ $0.435/$0.87 per M) | ~$7.07 | **~$35/month** |
| Active hours | 20.6h | ~103h |

### Lifetime vs Sample Discrepancy

- Hermes insights: $5.88 for 6 days → ~$35/month
- OpenRouter dashboard: **$102.26 lifetime** in ~9-14 days
- Real daily burn: **$8-11/day** because cached prefix tokens are billed at reduced rates but NOT counted in the input/output metrics
- **Bottom line:** Budget ~$100-150/month per heavy user, not $35

### OpenRouter Balance API

```bash
curl -s https://openrouter.ai/api/v1/credits \
  -H "Authorization: Bearer $OPENROUTER_API_KEY"
```

Returns:
```json
{
  "data": {
    "total_credits": 114.00,
    "total_usage": 102.26,
    "limit": 100,
    "limit_remaining": 74.5,
    "limit_reset": "monthly",
    "usage_daily": 25.5,
    "usage_monthly": 25.5,
    "is_free_tier": false
  }
}
```

### Per-Key Usage API

```bash
curl -s https://openrouter.ai/api/v1/key \
  -H "Authorization: Bearer $KEY"
```

Returns per-key:
```json
{
  "data": {
    "label": "sk-or-v1-...",
    "limit": 100,
    "limit_remaining": 74.5,
    "limit_reset": "monthly",
    "usage": 25.5,
    "usage_daily": 25.5,
    "usage_monthly": 25.5,
    "usage_weekly": 25.5,
    "is_free_tier": false
  }
}
```

## Per-Key Credit Limits (Client Isolation)

### Manual (OpenRouter Dashboard)

1. Go to **openrouter.ai/keys**
2. Create/edit a key
3. Set **Credit Limit** (e.g. $150)
4. Set **Limit Reset** to `monthly`
5. Set **Expires At** date

### Programmatic (Management API)

```bash
# Create key with limit
curl -s -X POST https://openrouter.ai/api/v1/keys \
  -H "Authorization: Bearer $MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "Client A - Starter",
    "limit": 150,
    "limit_reset": "monthly"
  }'

# Monitor usage
curl -s https://openrouter.ai/api/v1/key \
  -H "Authorization: Bearer $CLIENT_KEY"
```

### Hermes Profile Setup (Per-Client Isolation)

```bash
# Create isolated profile per client
hermes profile create client-a
hermes config set --profile client-a openrouter.api_key "sk-or-v1-..."
```

Each profile gets its own `.env`, `skills/`, `cron/`, `memories/`. Clients can't see each other's data.

## Resale Pricing Tiers

| Tier | Monthly | Includes | Est. Cost | Margin |
|---|---|---|---|---|
| **Starter** | **$149** | 1 user, 100 sessions/mo, basic tools | ~$30 API + $10 infra | ~70% |
| **Pro** | **$299** | 1 user, unlimited sessions, all tools + cron + skills | ~$100 API + $20 infra | ~60% |
| **Agency** | **$499** | 5 users, GHL integration, multi-platform, priority | ~$150 API + $30 infra | ~64% |
| **White-label** | **$997** | Unlimited users, rebrand, dedicated instance | ~$300 API + $50 infra | ~65% |

### Competitive Positioning

- Claude Code: $200/mo (coding only)
- ChatGPT Pro: $200/mo (chat only)
- Cursor Pro: $20/mo (IDE only)
- **Hermes:** $299/mo (social + CRM + calendar + automation + coding + memory + cron)

Value prop: Replaces VA ($500-2000/mo), social scheduler ($50-150/mo), CRM helper ($200-500/mo), and developer tools ($50-200/mo) — all in one.

## Key Management for Resale

```
Your Master Key ($500/mo pool)
├── Client A Key  → $150/mo limit (Starter tier)
├── Client B Key  → $300/mo limit (Pro tier)
├── Client C Key  → $500/mo limit (Agency tier)
└── Client D Key  → $1000/mo limit (White-label)
```

**Auto-shutoff:** When `limit_remaining` hits 0, OpenRouter returns `402 Payment Required`. Client can't overspend. You get alerted before they hit the cap.

**Monitoring script:** See `scripts/monitor_openrouter_usage.py` for automated credit checks across all client keys.

## Hermes Insights vs OpenRouter Credits Reconciliation

Hermes `insights --days 30` reports token counts but NOT billed cost. The gap:
- Cached prefix tokens: billed at ~50% rate but not counted as "input"
- Model switching: cheaper models used for some tasks
- Free tier requests: not counted in "usage"
- BYOK (Bring Your Own Key): tracked separately (`byok_usage_*` fields)

**Rule of thumb:** Multiply Hermes "estimated cost" by **3x** to get actual OpenRouter spend.
