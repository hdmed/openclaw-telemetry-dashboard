<div align="center">

[![🇫🇷 Français](https://img.shields.io/badge/langue-Français-ff7a45)](../INSTALL.md)
[![🇬🇧 English](https://img.shields.io/badge/lang-English-38bdf8)](INSTALL.md)

# Installation

</div>

## Requirements

| Component | Required? | Role |
|---|---|---|
| Windows 10/11 + PowerShell 5.1+ | Yes | Run `collect.ps1` |
| Modern browser | Yes | Display `index.html` |
| [OpenClaw / AutoClaw](https://docs.openclaw.ai) installed | Recommended | Provides real metrics (`status --json`, transcripts) |
| Node.js ≥ 18 | Recommended | Used by the OpenClaw CLI (bundled with AutoClaw) |
| Internet connection | Occasional | Load Chart.js from CDN (otherwise KPIs remain readable, without charts) |

## Steps

1. **Get the project**: clone the repo (or copy the `TDB/` folder)
   ```powershell
   git clone https://github.com/hdmed/openclaw-telemetry-dashboard.git
   cd openclaw-telemetry-dashboard
   ```

2. **Run the interactive installer** (copies files, creates `telemetry/`,
   asks for the refresh mode, writes `config.local.json`):
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\install.ps1 -Destination "C:\Tools\AutCLW-TDB"
   ```
   Proposed menu:
   ```text
   Refresh mode:
     1. Manual only (recommended, 0 LLM tokens)      ← default
     2. Windows Task Scheduler (0 tokens, automatic)
     3. OpenClaw cron (flexible, ~24k tokens/cycle)
   ```
   The mode can be changed at any time afterwards:
   `scripts\configure.ps1 -Mode manual|taskScheduler|openclawCron`
   (details in [USAGE.md](USAGE.md)).

3. **Verify the installation**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tests\smoke-test.ps1
   ```
   All tests must show `PASS`.

4. **First collection**: double-click `openclaw-tdb\collect.bat`.
   - With OpenClaw installed → real metrics
   - Without OpenClaw → the TDB stays empty; switch to demo mode (below)

## Demo mode (without OpenClaw)

```powershell
Copy-Item openclaw-tdb\sample-data\* openclaw-tdb\telemetry\ -Force
```
Then open `openclaw-tdb\index.html`. Displayed data is fictional.

## Non-standard paths

If your OpenClaw installation is not at the default location, fill in
`openclaw-tdb\config.local.json` (never committed) — see
`config.example.json` for all keys:

```json
{
  "cliPath": "D:\\Tools\\openclaw\\openclaw.mjs",
  "cfgPath": "C:\\Users\\me\\.openclaw-autoclaw\\openclaw.json",
  "agentsRoot": "C:\\Users\\me\\.openclaw-autoclaw\\agents"
}
```

On macOS/Linux, adapt `collect.ps1` (the logic is identical; CLI paths
change) and replace Task Scheduler with launchd/systemd (not shipped in v0.2).
