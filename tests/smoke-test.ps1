# ============================================================
#  TDB - Test de fumee (smoke test)
#  Verifie que l'installation est complete et fonctionnelle.
#  Usage : powershell -ExecutionPolicy Bypass -File tests\smoke-test.ps1
# ============================================================
$ErrorActionPreference = 'Continue'
$Root      = Split-Path -Parent $PSScriptRoot
$Project   = Join-Path $Root 'openclaw-tdb'
$pass = 0; $fail = 0

function Check($name, $ok, $detail) {
  if ($ok) { $script:pass++; Write-Output ("  PASS  " + $name + ($(if ($detail) { " - " + $detail }))) }
  else     { $script:fail++; Write-Output ("  FAIL  " + $name + ($(if ($detail) { " - " + $detail }))) }
}

Write-Output "=== TDB smoke test (v0.2) ==="
Check "index.html present"            (Test-Path (Join-Path $Project 'index.html'))
Check "collect.ps1 present"           (Test-Path (Join-Path $Project 'collect.ps1'))
Check "collect.bat present"           (Test-Path (Join-Path $Project 'collect.bat'))
Check "config.example.json present"   (Test-Path (Join-Path $Project 'config.example.json'))
Check "scripts/configure.ps1 present" (Test-Path (Join-Path $Root 'scripts\configure.ps1'))
Check "docs/INSTALL.md present"       (Test-Path (Join-Path $Root 'docs\INSTALL.md'))

try { $v = & node --version 2>$null; Check "Node.js disponible" ($LASTEXITCODE -eq 0) $v }
catch { Check "Node.js disponible" $false "node introuvable dans le PATH" }

$tel = Join-Path $Project 'telemetry'
if (Test-Path $tel) {
  foreach ($f in @('latest.js','journal.js','aggregates.js','meta.js')) {
    $p = Join-Path $tel $f
    if (Test-Path $p) {
      try {
        $out = & node -e "global.window={};require(process.argv[1]);console.log('ok')" $p 2>$null
        Check "telemetry/$f parse JS" ($out -eq 'ok')
      } catch { Check "telemetry/$f parse JS" $false $_.Exception.Message }
    } else { Check "telemetry/$f present" $false "lancez collect.ps1 d'abord" }
  }
} else {
  Write-Output "  INFO  telemetry/ absent (aucune collecte effectuee) - mode demo possible via sample-data/"
  $sd = Join-Path $Project 'sample-data'
  Check "sample-data/latest.js present" (Test-Path (Join-Path $sd 'latest.js'))
  Check "sample-data/journal.js present" (Test-Path (Join-Path $sd 'journal.js'))
}

Write-Output ("=== resultat : " + $pass + " PASS / " + $fail + " FAIL ===")
exit ($(if ($fail -gt 0) { 1 } else { 0 }))
