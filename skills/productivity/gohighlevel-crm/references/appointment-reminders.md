# GHL Appointment Reminders via Cron

Two cron jobs provide appointment awareness: a daily summary in the morning and
a mid-day check.

## Cron Job 1: Daily Summary (e.g. 7 AM local)

Schedule: `0 7 * * *`

Checks all of your GHL calendars for today's events and delivers a summary.
If no appointments, sends a brief "no appointments" note.

## Cron Job 2: Mid-Day Check (e.g. noon local)

Schedule: `0 12 * * *`

Checks for any appointments still upcoming today. Complements the morning daily
summary by catching appointments booked during the morning.

- Lists any appointments with start times still in the future
- If all appointments have passed or none exist: reply "ok" (one word — silent)
- Start/end window: today midnight to today 23:59:59 UTC

### Design rationale

A tight `*/30 8-18 * * *` pre-appointment alert tends to be too noisy. Prefer
reminders that naturally stop after the date passes. The noon check is one daily
nudge — enough to catch new bookings without being intrusive.

## Calendar IDs

Fetch your calendar IDs at runtime with **List calendars** (see `SKILL.md`) and
cache them locally (e.g. `~/.hermes/ghl/calendars.json`). Reference them by name
in the cron prompt so the job stays readable, for example:

```
- <CAL_ID_1> — Schedule an Appointment
- <CAL_ID_2> — Consultation
```

Endpoint: `GET /calendars/events?locationId=$LOC&calendarId=$CAL&startTime=MS&endTime=MS`
Headers: `Version: 2021-07-28`, `User-Agent: Mozilla/5.0`

## Trigger conditions

These are HERMES cron jobs, not GHL-native reminders. They run as the Hermes
agent and deliver results to the origin chat. Create them via the `cronjob`
tool with `deliver=origin`. Toolsets: `["terminal", "file"]`. The prompt must be
self-contained — the cron runs in a fresh session with no current-chat context.
