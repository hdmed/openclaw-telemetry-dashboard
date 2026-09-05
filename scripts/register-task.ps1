# ============================================================
#  TDB - Enregistre la tache planifiee Windows (mode taskScheduler)
#  Usage :
#    powershell -ExecutionPolicy Bypass -File scripts\register-task.ps1 [-IntervalMinutes 5] [-ProjectDir <chemin>]
# ============================================================
param(
  [int]$IntervalMinutes = 5,
  [string]$ProjectDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'openclaw-tdb')
)
$ErrorActionPreference = 'Stop'
$ps = Join-Path $ProjectDir 'collect.ps1'
if (-not (Test-Path $ps)) { Write-Error "collect.ps1 introuvable : $ps"; exit 1 }

schtasks /Create /F /TN "AutCLW-TDB-Collect" /SC MINUTE /MO $IntervalMinutes /TR "powershell -NoProfile -ExecutionPolicy Bypass -File `"$ps`""

if ($LASTEXITCODE -eq 0) {
  Write-Output ("Tache 'AutCLW-TDB-Collect' creee : collecte toutes les " + $IntervalMinutes + " minute(s).")
  Write-Output "Visualiser : Planificateur de taches Windows > AutCLW-TDB-Collect"
  Write-Output "Supprimer   : scripts\unregister-task.ps1"
} else {
  Write-Error "Echec de creation de la tache planifiee (droits administrateur requis ?)"
  exit 1
}
