<div align="center">

[![🇫🇷 Français](https://img.shields.io/badge/langue-Français-ff7a45)](README.md)
[![🇬🇧 English](https://img.shields.io/badge/lang-English-38bdf8)](README.en.md)

# 🦞 TDB — OpenClaw Telemetry Dashboard

**Self-updating HTML dashboard for OpenClaw — tokens, cost, cache, agents, action journal**

![Licence](https://img.shields.io/badge/license-MIT-2dd4bf)
![Platform](https://img.shields.io/badge/platform-Windows-38bdf8)
![For](https://img.shields.io/badge/for-OpenClaw-ff7a45)
![Charts](https://img.shields.io/badge/charts-Chart.js-a78bfa)
![Mode](https://img.shields.io/badge/100%25-local-telemetry-34d399)

![Dashboard preview](docs/preview.png)

*One HTML file · one deterministic PowerShell script · your data stays on your machine*

</div>

---

## Features

- **⟳ Sync button + help panel** at the top of the page (collapsible help)
- **Totals cards** with period filter: 1 h / 6 h / 24 h / 7 d / all
- **3 refresh modes to choose from**: manual (default, 0 tokens),
  Windows Task Scheduler (0 tokens, automatic), OpenClaw cron — hot-swappable
- **Session KPIs**: cumulative tokens, cost, cache hit, context used, active sessions
- **Charts** (Chart.js): tokens over time, token distribution by model,
  events + requests + tokens per hour (**immortal** hourly history)
- **Action journal** paginated (50 per page): task, called tools,
  agent, provider/model, duration, tokens, completion state (✅ 🔧 ⛔ ❌)
- **Cumulative statistics**: "since forever" totals survive journal purges
  (`stats-aggregates.json`)
- **Auto-refresh**: data reloaded every 60 s
- **i18n**: interface available in 🇫🇷 French · 🇬🇧 English · 🇪🇸 Spanish · 🇨🇳 Chinese (selector in the header)

## Quick start

```text
1. powershell -File scripts\install.ps1     → installs + asks for the refresh mode
2. Double-click collect.bat                 → collects + opens the TDB
3. Read the dashboard                       → filters, charts, journal
```

Detailed requirements: [docs/en/INSTALL.md](docs/en/INSTALL.md) ·
Usage: [docs/en/USAGE.md](docs/en/USAGE.md) ·
Internals: [docs/en/ARCHITECTURE.md](docs/en/ARCHITECTURE.md)

## Refresh modes

| Mode | Trigger | LLM tokens |
|---|---|---|
| `manual` (default) | double-click `collect.bat` | 0 |
| `taskScheduler` | Windows Task Scheduler | 0 |
| `openclawCron` | OpenClaw cron (can target a local Ollama model) | ~24k/cycle |

Hot-switch: `scripts\configure.ps1 -Mode <manual|taskScheduler|openclawCron>`.

## Where does the data come from?

- **With OpenClaw installed**: `collect.ps1` queries the OpenClaw CLI
  (`status --json`) and session transcripts → real metrics
- **Without OpenClaw**: copy the contents of [`openclaw-tdb/sample-data/`](openclaw-tdb/sample-data/)
  into `openclaw-tdb/telemetry/` then open `index.html` — the TDB runs in
  demo mode

## Privacy

- The `openclaw-tdb/telemetry/` folder (your real data) is **gitignored**:
  nothing personal goes into the repo
- `sample-data/` contains **fictional** demo data
- `config.local.json` (mode + machine-specific paths) is also gitignored

## Licence

[MIT](LICENSE)
