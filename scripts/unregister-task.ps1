# ============================================================
#  TDB - Supprime la tache planifiee Windows
#  Usage :
#    powershell -ExecutionPolicy Bypass -File scripts\unregister-task.ps1
# ============================================================
schtasks /Delete /TN "AutCLW-TDB-Collect" /F
if ($LASTEXITCODE -eq 0) {
  Write-Output "Tache 'AutCLW-TDB-Collect' supprimee. Retour au mode manuel (collect.bat)."
} else {
  Write-Warning "Tache absente ou suppression impossible (droits ?)"
}
