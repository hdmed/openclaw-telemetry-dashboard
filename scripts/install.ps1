# ============================================================
#  TDB - Installeur pour une nouvelle machine (v0.2)
#  Menu interactif : choix du mode de rafraichissement.
#  Usage :
#    powershell -ExecutionPolicy Bypass -File scripts\install.ps1 [-Destination "C:\Tools\AutCLW-TDB"]
# ============================================================
param(
  [string]$Destination = "C:\Tools\AutCLW-TDB"
)
$ErrorActionPreference = 'Stop'
$Source = Join-Path (Split-Path -Parent $PSScriptRoot) 'openclaw-tdb'

Write-Output "=== Installation du TDB (v0.2) ==="
if (-not (Test-Path $Source)) { Write-Error "Dossier source introuvable : $Source"; exit 1 }

# --- 1. Copie du projet ---
New-Item -ItemType Directory -Force -Path $Destination | Out-Null
Copy-Item (Join-Path $Source '*') $Destination -Recurse -Force
New-Item -ItemType Directory -Force -Path (Join-Path $Destination 'telemetry') | Out-Null
Write-Output ("  projet copie vers : " + $Destination)

# --- 2. Prerequis ---
try { $v = & node --version 2>$null; Write-Output ("  Node.js : " + $v + " (OK)") }
catch { Write-Warning "  Node.js introuvable - la CLI OpenClaw ne fonctionnera pas sans lui" }

$cli = "C:\Program Files\AutoClaw\resources\gateway\openclaw\openclaw.mjs"
if (Test-Path $cli) { Write-Output "  OpenClaw (AutoClaw) detecte - metriques reelles disponibles" }
else { Write-Warning "  OpenClaw non detecte a l'emplacement standard - mode demo possible (sample-data)" }

# --- 3. Choix du mode de rafraichissement ---
Write-Output ""
Write-Output "Mode de rafraichissement :"
Write-Output "  1. Manuel uniquement (recommande, 0 token LLM)"
Write-Output "  2. Task Scheduler Windows (0 token, automatique)"
Write-Output "  3. Cron OpenClaw (flexible, ~24k tokens/cycle)"
$choice = Read-Host "Votre choix [1]"
if (-not $choice) { $choice = '1' }

$modeMap = @{ '1' = 'manual'; '2' = 'taskScheduler'; '3' = 'openclawCron' }
$mode = $modeMap[$choice]
if (-not $mode) { $mode = 'manual' }
$interval = 5
if ($mode -ne 'manual') {
  $i = Read-Host "Intervalle en minutes [5]"
  if ($i -match '^\d+$' -and [int]$i -gt 0) { $interval = [int]$i }
}

# --- 4. config.local.json (jamais committe) ---
$cfgPath = Join-Path $Destination 'config.local.json'
$cfg = [ordered]@{
  refreshMode     = $mode
  intervalMinutes = $interval
  cliPath         = $null
  cfgPath         = $null
  agentsRoot      = $null
  historyMaxDays  = 30
  journalMax      = 400
  journalDays     = 7
}
$cfg | ConvertTo-Json | Set-Content -Path $cfgPath -Encoding UTF8
Write-Output ("  config.local.json ecrit (mode=" + $mode + ", intervalle=" + $interval + " min)")

# --- 5. Actions selon le mode ---
$scriptsDir = $PSScriptRoot
if ($mode -eq 'taskScheduler') {
  $r = Read-Host "Creer la tache planifiee Windows maintenant ? (O/n)"
  if ($r -notmatch '^[nN]') {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir 'register-task.ps1') -ProjectDir $Destination -IntervalMinutes $interval
  } else {
    Write-Output "  Plus tard : scripts\register-task.ps1 -IntervalMinutes $interval"
  }
}
if ($mode -eq 'openclawCron') {
  Write-Output "  Cron OpenClaw : creez un job agentTurn isole (schedule every $interval min, delivery none)"
  Write-Output "  dont payload.message est :"
  Write-Output ("    Executer via exec : powershell -NoProfile -ExecutionPolicy Bypass -File \"" + (Join-Path $Destination 'collect.ps1') + "\"")
  Write-Output "  Details : docs\USAGE.md, section mode cron OpenClaw."
}

# --- 6. Final ---
Write-Output ""
Write-Output "Prochaines etapes :"
Write-Output ("  1. Double-cliquer " + (Join-Path $Destination 'collect.bat'))
Write-Output "  2. Verifier : tests\smoke-test.ps1"
Write-Output "  3. Changer de mode a tout moment : scripts\configure.ps1 -Mode manual|taskScheduler|openclawCron"
Write-Output ""
Write-Output "Installation terminee."
