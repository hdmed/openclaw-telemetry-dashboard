<div align="center">

[![🇫🇷 Français](https://img.shields.io/badge/langue-Français-ff7a45)](../USAGE.md)
[![🇬🇧 English](https://img.shields.io/badge/lang-English-38bdf8)](USAGE.md)

# Usage

</div>

## The 3 refresh modes

The TDB is a **file passer** : `collect.ps1` writes `telemetry/`, the page
re-reads those files every 60 s while open. Only the **trigger** changes
depending on the mode:

| Mode | Trigger | LLM tokens | For whom |
|---|---|---|---|
| `manual` (default) | double-click `collect.bat` | 0 | Full control |
| `taskScheduler` | Windows Task Scheduler, every N min | 0 | Full transparency |
| `openclawCron` | OpenClaw cron `agentTurn` | ~24k/cycle (0 $ on free models) | OpenClaw ecosystem |

### Switch mode at runtime

```powershell
# in TDB\scripts\
powershell -ExecutionPolicy Bypass -File configure.ps1 -Mode manual
powershell -ExecutionPolicy Bypass -File configure.ps1 -Mode taskScheduler -IntervalMinutes 10
powershell -ExecutionPolicy Bypass -File configure.ps1 -Mode openclawCron
powershell -ExecutionPolicy Bypass -File configure.ps1 -Show        # current state
```

`configure.ps1` writes `openclaw-tdb\config.local.json` (never committed).
The next collection applies the mode and the badge at the top of the TDB
displays it.

### taskScheduler mode

```powershell
powershell -ExecutionPolicy Bypass -File scripts\register-task.ps1 -IntervalMinutes 5
powershell -ExecutionPolicy Bypass -File scripts\unregister-task.ps1   # removal
```
Task created: `AutCLW-TDB-Collect` (visible in the Windows Task Scheduler).

### openclawCron mode

Create a job `sessionTarget: "isolated"`, `schedule` = every N min,
`delivery: { mode: "none" }`, and a `payload.message` like:

```
Run via exec exactly this command:
powershell -NoProfile -ExecutionPolicy Bypass -File "<path>\collect.ps1"
Reply only: TDB OK <ts> (or TDB PARTIAL <output>).
```

A `payload.model` can target a local Ollama model (e.g.
`ollama/qwen3.5:0.8b` with `params.thinking: false` and `num_ctx` aligned —
small Qwen "thinking" models otherwise spend their budget on hidden
reasoning). See the OpenClaw docs (`automation/cron-jobs`,
`providers/ollama`) and `gateway/local-models.md`.

## Manual collection

Double-click **`openclaw-tdb\collect.bat`** : collects then opens the TDB.
The **⟳ Synchronise** button (top of the page) re-reads the `telemetry/`
files immediately and watches for a new snapshot (60 s) if a collection is
running elsewhere.

## Reading the dashboard

- **Help panel** (top): reminder of modes, purge and privacy — collapsible,
  state remembered.
- **Period filter** (1 h / 6 h / 24 h / 7 d / all): applies to the totals
  cards, the "by model" and "per hour" charts, and the journal. In "all"
  mode, cards show **cumulative statistics** (`stats-aggregates.json`),
  which survive journal purges.
- **Action journal**: navigation in batches of 50 (⏮ ◀ ▶ ⏭). Each row
  describes a model response: original task, called tools, agent,
  provider/model, duration, tokens, state (✅ done · 🔧 tools · ⛔ aborted ·
  ❌ error).

## Purge rules (applied at each collection)

| Data | Retention | Purge effect |
|---|---|---|
| `journal.js` (detailed actions) | 7 rolling days, 400-action cap | Only the detailed list shrinks |
| `history.jsonl` (session snapshots) | 30 days | Fine-grained session token history |
| `stats-aggregates.json` | **never purged** | Global totals intact (tokens, requests, events, per model) |

Aggregate values are incremented **before** any purge: global totals never
decrease. Settings: keys `journalMax`, `journalDays`, `historyMaxDays` in
`config.local.json`.

## Uninstall

`taskScheduler` mode: `scripts\unregister-task.ps1`, then delete the project
folder. OpenClaw and its data are not modified.
