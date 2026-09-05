<div align="center">

[![🇫🇷 Français](https://img.shields.io/badge/langue-Français-ff7a45)](../ARCHITECTURE.md)
[![🇬🇧 English](https://img.shields.io/badge/lang-English-38bdf8)](ARCHITECTURE.md)

# Architecture

</div>

## Overview

```text
┌────────────────────────────┐
│  OpenClaw Gateway (local)  │
│  - CLI status --json       │
│  - session transcripts     │
└──────────┬─────────────────┘
           │ (read-only)
           ▼
┌────────────────────────────┐        every 5 min (cron) or
│  collect.ps1 (deterministic)│        collect.bat double-click
│  1. status --json          │
│  2. parse transcripts      │
│  3. aggregate stats        │
│  4. purge old data         │
└──────────┬─────────────────┘
           │ writes
           ▼
┌────────────────────────────┐
│  openclaw-tdb/telemetry/   │
│  latest.js                 │  session snapshot (tokens, cache…)
│  journal.js                │  detailed actions + hourly buckets
│  aggregates.js             │  cumulative totals (purge-proof)
│  hourly-history.js         │  immortal hourly history
│  history.jsonl             │  fine-grained history (30 d)
│  stats-aggregates.json     │  same object, raw JSON format
└──────────┬─────────────────┘
           │ <script src> reload
           ▼
┌────────────────────────────┐
│  index.html (TDB)          │
│  - localStorage (trend)    │
│  - re-read every 60 s      │
└────────────────────────────┘
```

## Why `.js` data files?

The page is opened via `file://` : the browser forbids `fetch()` on local
files (CORS). However, dynamically injecting `<script
src="telemetry/latest.js?ts=…">` tags works: each data file is a simple
global assignment (`window.TDB_REMOTE = {…}`). Cache-busting (`?ts=`)
forces a disk re-read.

## Cumulative statistics accounting

"Since forever" totals must survive purges. Principle:

- the journal is **rebuilt** at each collection from transcripts
  (7-day window, 400-action cap) → the same entries reappear;
- `stats-aggregates.json` keeps `lastAggregatedTs` : at each collection,
  only **strictly newer** entries are added to the totals
  (tokens, requests, per-model distribution, first/last action);
- for "events" (transcript messages, including user/tools), hourly buckets
  are compared with the already-counted value for the same bucket → only
  **positive deltas** are added (`eventsTotal` is monotonic).

Result: purging `journal.js` / `history.jsonl` never lowers global totals.

## i18n architecture

- `i18n/{lang}.js` files assign `window.TDB_I18N = {…}` (same `<script>`
  injection pattern as telemetry files — works over `file://`).
- `fr.js` is the reference dictionary (~116 keys). `en`, `es`, `zh` mirror
  it key-for-key (checked by `tests/smoke-test.ps1` via `check-i18n.js`).
- Static HTML strings carry `data-i18n="key"` (textContent) or
  `data-i18n-html="key"` (innerHTML) attributes; `tApply()` swaps them.
- The `t(key, vars)` helper replaces `{placeholders}` at runtime (journal
  counters, sub-titles).
- Language choice is persisted in `localStorage` (`tdb_lang`), defaulting
  to `navigator.language` (fallback `fr`).
- Journal `task` texts stay in their original language (they are user
  content, not UI strings).

## Small local model compatibility

The collector performs **no** LLM call: it is a pure script. If you
automate via an OpenClaw cron `agentTurn`, the chosen model only needs to
"run the script and reply TDB OK". Small local models (Ollama type
qwen3.5:0.8b) fit, with `params.thinking: false` and `num_ctx` aligned to
the cron prompt window (~24k tokens of system context + overhead). The
OpenClaw docs also recommend
`agents.defaults.experimental.localModelLean: true` for small models.

## Files

| File | Role |
|---|---|
| `openclaw-tdb/index.html` | The dashboard (self-contained, Chart.js via CDN) |
| `openclaw-tdb/collect.ps1` | Deterministic collector |
| `openclaw-tdb/collect.bat` | Double-click launcher (collect + open) |
| `openclaw-tdb/i18n/{lang}.js` | UI translations (fr, en, es, zh) |
| `openclaw-tdb/telemetry/` | Runtime data (gitignored) |
| `openclaw-tdb/sample-data/` | Fictional demo dataset |
| `scripts/install.ps1` | Install on a new machine |
| `scripts/configure.ps1` | Hot-switch refresh mode |
| `scripts/register-task.ps1` / `unregister-task.ps1` | Windows scheduled task |
| `tests/smoke-test.ps1` | Post-install verification |
