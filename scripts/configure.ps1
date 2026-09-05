# ============================================================
#  TDB - Changer le mode de rafraichissement a chaud
#  Usage (depuis TDB\scripts\) :
#    powershell -ExecutionPolicy Bypass -File configure.ps1 -Mode manual
#    powershell -ExecutionPolicy Bypass -File configure.ps1 -Mode taskScheduler -IntervalMinutes 10
#    powershell -ExecutionPolicy Bypass -File configure.ps1 -Mode openclawCron
#    powershell -ExecutionPolicy Bypass -File configure.ps1 -Show
# ============================================================
param(
  [ValidateSet('manual', 'taskScheduler', 'openclawCron')]
  [string]$Mode,
  [int]$IntervalMinutes = 5,
  [switch]$Show
)
$ErrorActionPreference = 'Stop'
$ProjectDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'openclaw-tdb'
$cfgPath    = Join-Path $ProjectDir 'config.local.json'

if ($Show) {
  if (Test-Path $cfgPath) { Get-Content $cfgPath -Raw -Encoding UTF8 }
  else { Write-Output "config.local.json absent - valeurs par defaut : mode=manual, intervalle=5 min" }
  exit 0
}
if (-not $Mode) {
  Write-Output "Precisez -Mode manual | taskScheduler | openclawCron (ou -Show pour l'etat actuel)"
  exit 1
}

# conserve les autres reglages existants
$cfg = [ordered]@{
  refreshMode     = $Mode
  intervalMinutes = $IntervalMinutes
  cliPath         = $null
  cfgPath         = $null
  agentsRoot      = $null
  historyMaxDays  = 30
  journalMax      = 400
  journalDays     = 7
}
if (Test-Path $cfgPath) {
  try {
    $old = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($p in 'cliPath', 'cfgPath', 'agentsRoot', 'historyMaxDays', 'journalMax', 'journalDays') {
      if ($null -ne $old.$p) { $cfg[$p] = $old.$p }
    }
  } catch { Write-Warning "Ancienne config illisible - elle sera remplacee" }
}
$cfg | ConvertTo-Json | Set-Content -Path $cfgPath -Encoding UTF8

Write-Output ("config.local.json mis a jour : mode=" + $Mode + ", intervalle=" + $IntervalMinutes + " min")
Write-Output "La prochaine collecte (collect.bat / tache planifiee / cron) appliquera ce mode."
if ($Mode -eq 'taskScheduler') {
  Write-Output ("Pour (re)enregistrer la tache Windows : scripts\register-task.ps1 -IntervalMinutes " + $IntervalMinutes)
  Write-Output "Pour la supprimer : scripts\unregister-task.ps1"
}
if ($Mode -eq 'openclawCron') {
  Write-Output "Creez/editez le cron OpenClaw pointant vers collect.ps1 (voir docs\USAGE.md)."
}
