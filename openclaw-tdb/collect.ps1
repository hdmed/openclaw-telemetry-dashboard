# ============================================================
#  TDB Collector v3 (portable) - OpenClaw Telemetry Dashboard
#  - Interroge la CLI OpenClaw (status --json) si disponible
#  - Extrait le journal des actions depuis les transcripts
#  - Maintient des statistiques cumulees (stats-aggregates)
#    qui survivent a la purge des journaux detailles
#  - Ecrit telemetry/{latest.js, journal.js, aggregates.js,
#    history.jsonl, stats-aggregates.json}
#  Portable : chemins auto-detectes, surchargeables via
#  config.local.json (jamais committe). Aucun appel LLM.
# ============================================================
$ErrorActionPreference = 'Stop'
$ScriptDir    = $PSScriptRoot
$TelemetryDir = Join-Path $ScriptDir 'telemetry'
$utf8NoBom    = New-Object System.Text.UTF8Encoding($false)

# ---------- config locale optionnelle ----------
$conf = @{
  cliPath        = $null
  cfgPath        = (Join-Path $env:USERPROFILE '.openclaw-autoclaw\openclaw.json')
  agentsRoot     = (Join-Path $env:USERPROFILE '.openclaw-autoclaw\agents')
  historyMaxDays = 30
  journalMax     = 400
  journalDays    = 7
  refreshMode    = 'manual'
  intervalMinutes = 5
}
$confLocalPath = Join-Path $ScriptDir 'config.local.json'
if (Test-Path $confLocalPath) {
  try {
    $lc = Get-Content $confLocalPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($lc.cliPath)        { $conf.cliPath        = [string]$lc.cliPath }
    if ($lc.cfgPath)        { $conf.cfgPath        = [string]$lc.cfgPath }
    if ($lc.agentsRoot)     { $conf.agentsRoot     = [string]$lc.agentsRoot }
    if ($lc.historyMaxDays) { $conf.historyMaxDays = [int]$lc.historyMaxDays }
    if ($lc.journalMax)     { $conf.journalMax     = [int]$lc.journalMax }
    if ($lc.journalDays)    { $conf.journalDays    = [int]$lc.journalDays }
    if ($lc.refreshMode)    { $conf.refreshMode    = [string]$lc.refreshMode }
    if ($lc.intervalMinutes){ $conf.intervalMinutes= [int]$lc.intervalMinutes }
  } catch { Write-Output ("TDB WARN config.local.json invalide : " + $_.Exception.Message) }
}

# ---------- resolution CLI OpenClaw ----------
$candidates = @()
if ($conf.cliPath) { $candidates += $conf.cliPath }
$candidates += @(
  "C:\Program Files\AutoClaw\resources\gateway\openclaw\openclaw.mjs",
  (Join-Path $env:USERPROFILE '.openclaw\openclaw.mjs')
)
$cli = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

$ts = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
$st = $null; $main = $null; $rec = @(); $agents = @(); $degraded = @()

# ---------- 1. statut gateway (si CLI disponible) ----------
if ($cli) {
  try {
    $st = (& node $cli status --json 2>$null | Out-String) | ConvertFrom-Json
    $rec  = @($st.sessions.recent | Where-Object { $_.key -notlike '*:cron:*' })
    $main = @($rec | Where-Object { $_.key -like 'agent:main:*' } | Select-Object -First 1)
    if (-not $main) { $main = $rec | Select-Object -First 1 }
  } catch { $degraded += 'status' }
} else { $degraded += 'cli-absente' }

# ---------- 2. agents + modeles (config locale) ----------
if (Test-Path $conf.cfgPath) {
  try {
    $cfg = Get-Content $conf.cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $defModel = $cfg.agents.defaults.model.primary
    $agents = @($cfg.agents.list | ForEach-Object {
      [pscustomobject]@{
        id     = $_.id
        name   = $_.name
        model  = $(if ($_.model) { $_.model } else { $defModel })
        active = $(if ($_.id -eq $st.agents.defaultId -or $_.default) { 1 } else { 0 })
      }
    })
  } catch { $degraded += 'config' }
}

# ---------- 3. lignes de sessions ----------
$sessRows = @($rec | ForEach-Object {
  [pscustomobject]@{
    key     = $_.key
    channel = $_.kind
    model   = $_.selectedModel
    tokens  = $_.totalTokens
    cost    = $null
    status  = $(if ($_.age -lt 3600000) { 'actif' } else { 'repos' })
  }
})

# ---------- 4. cache hit ----------
$hit = $null
if ($main -and $main.cacheRead -gt 0 -and ($main.cacheRead + $main.inputTokens) -gt 0) {
  $hit = [int][math]::Round(100 * $main.cacheRead / ($main.cacheRead + $main.inputTokens))
}

# ---------- 5. snapshot ----------
$json = [pscustomobject]@{
  ts              = $ts
  model           = $(if ($main) { $main.selectedModel } else { $null })
  provider        = $(if ($main -and $main.configuredModel) { ($main.configuredModel -split '/')[0] } else { $null })
  runIn           = $(if ($main) { $main.inputTokens } else { $null })
  runOut          = $(if ($main) { $main.outputTokens } else { $null })
  totalTokens     = $(if ($main) { $main.totalTokens } else { $null })
  costUsd         = $null
  cacheHitPct     = $hit
  cachedTokens    = $(if ($main) { $main.cacheRead } else { $null })
  contextTokens   = $(if ($main) { $main.totalTokens } else { $null })
  contextLimit    = $(if ($main) { $main.contextTokens } else { $null })
  compactions     = $null
  uptimeGateway   = $null
  sessionsActive  = @($rec | Where-Object { $_.age -lt 3600000 }).Count
  sessionsTotal   = $(if ($st) { $st.sessions.count } else { 0 })
  agentsTotal     = $(if ($st) { $st.agents.agents.Count } else { $agents.Count })
  cronsTotal      = @($rec | Where-Object { $_.kind -eq 'cron' }).Count
  subagentsActive = 0
  channels        = $(if ($st -and $st.channelSummary) { ($st.channelSummary.PSObject.Properties.Name -join ', ') } else { '' })
  sessions        = $sessRows
  agents          = $agents
} | ConvertTo-Json -Depth 5 -Compress

# ---------- 6. journal des actions (transcripts, fenetre journalDays) ----------
$journal = New-Object System.Collections.Generic.List[object]
$hourly  = @{}
$since   = (Get-Date).AddDays(-$conf.journalDays)

if (Test-Path $conf.agentsRoot) {
  foreach ($ad in (Get-ChildItem $conf.agentsRoot -Directory -ErrorAction SilentlyContinue)) {
    $agentId = $ad.Name
    $sdir = Join-Path $ad.FullName 'sessions'
    if (-not (Test-Path $sdir)) { continue }
    $files = Get-ChildItem $sdir -Filter *.jsonl -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -notmatch 'trajectory' -and $_.LastWriteTime -ge $since }
    foreach ($f in $files) {
      $lastTs = $null
      $task = ''
      foreach ($line in [System.IO.File]::ReadLines($f.FullName)) {
        if ($line.Length -lt 30) { continue }
        $o = $null
        try { $o = $line | ConvertFrom-Json } catch { continue }
        if (-not $o.timestamp) { continue }
        $tsCur = [datetime]$o.timestamp
        $hKey = $tsCur.ToString("yyyy-MM-ddTHH:00")
        if (-not $hourly.ContainsKey($hKey)) {
          $hourly[$hKey] = [pscustomobject]@{ h = $hKey; events = 0; requests = 0; tokens = 0; reportedTokens = 0; unknownRequests = 0 }
        }
        $hourly[$hKey].events++

        $role = $o.message.role
        if ($role -eq 'user') {
          $txt = ''
          $c = $o.message.content
          if ($c -is [string]) { $txt = $c }
          else { foreach ($part in @($c)) { if ($part.type -eq 'text') { $txt += $part.text + ' ' } } }
          while ($txt -match '<system-reminder>') { $txt = $txt -replace '(?s)<system-reminder>.*?</system-reminder>', '' }
          $txt = $txt -replace '<<<AUTOCLAW_USER_AUTHORED_REQUEST_START>>>', ' '
          $txt = $txt -replace '<<<AUTOCLAW_USER_AUTHORED_REQUEST_END>>>', ' '
          $txt = ($txt -replace '\s+', ' ').Trim()
          if ($txt -notmatch 'AUTOCLAW_' -and $txt -notmatch 'OPENCLAW_' -and $txt.Length -gt 2) {
            $task = if ($txt.Length -gt 90) { $txt.Substring(0, 90) + '…' } else { $txt }
          }
        }
        elseif ($role -eq 'assistant') {
          $u = $o.message.usage
          $tools = @($o.message.content | Where-Object { $_.type -eq 'toolCall' } | ForEach-Object { $_.name })
          $action = if ($tools.Count) { (($tools | Select-Object -Unique) -join ', ') } else { 'réponse' }
          $dur = $null
          if ($lastTs) { $dur = [int]($tsCur - $lastTs).TotalMilliseconds; if ($dur -lt 0) { $dur = $null } }
          $tok = $null
          $tokenStatus = "unknown"
          if ($u -and $null -ne $u.totalTokens -and [long]$u.totalTokens -gt 0) { $tok = [long]$u.totalTokens; $tokenStatus = "reported" }
          $journal.Add([pscustomobject]@{
            ts         = $tsCur.ToString("yyyy-MM-ddTHH:mm:sszzz")
            agent      = $agentId
            session    = $f.BaseName.Substring(0, [Math]::Min(8, $f.BaseName.Length))
            task       = $task
            action     = $action
            provider   = $o.message.provider
            model      = $o.message.model
            durationMs = $dur
            tokens     = $tok
            tokenStatus = $tokenStatus
            state      = $(switch ($o.message.stopReason) {
                            'stop'    { '✅ terminé' }
                            'toolUse' { '🔧 outils' }
                            'abort'   { '⛔ interrompu' }
                            'error'   { '❌ erreur' }
                            default   { $o.message.stopReason } })
          })
          $hourly[$hKey].requests++
          if ($tokenStatus -eq "reported") { $hourly[$hKey].tokens += $tok; $hourly[$hKey].reportedTokens += $tok } else { $hourly[$hKey].unknownRequests++ }
        }
        $lastTs = $tsCur
      }
    }
  }
}

$journalArr = @($journal | Sort-Object { [datetime]$_.ts })
$hourlyArr  = @($hourly.Values | Sort-Object h)

# ---------- 7. statistiques cumulees (purge-proof) ----------
New-Item -ItemType Directory -Force -Path $TelemetryDir | Out-Null
$aggPath = Join-Path $TelemetryDir 'stats-aggregates.json'
$agg = @{ firstTs = $null; lastTs = $null; tokensTotal = 0; requestsTotal = 0; unknownRequestsTotal = 0; eventsTotal = 0; byModel = @{}; hours = @{}; lastAggregatedTs = $null }
if (Test-Path $aggPath) {
  try {
    $a0 = Get-Content $aggPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $agg.firstTs          = $a0.firstTs
    $agg.lastTs           = $a0.lastTs
    $agg.tokensTotal      = [long]$a0.tokensTotal
    $agg.requestsTotal    = [long]$a0.requestsTotal
    $agg.unknownRequestsTotal = [long]$(if ($null -ne $a0.unknownRequestsTotal) { $a0.unknownRequestsTotal } else { 0 })
    $agg.eventsTotal      = [long]$a0.eventsTotal
    $agg.lastAggregatedTs = $a0.lastAggregatedTs
    if ($a0.byModel) { foreach ($p in $a0.byModel.PSObject.Properties) { $agg.byModel[$p.Name] = [long]$p.Value } }
    if ($a0.hours)   { foreach ($p in $a0.hours.PSObject.Properties)   { $agg.hours[$p.Name]   = [long]$p.Value } }
  } catch { Write-Output ("TDB WARN aggregates illisibles, reprise a zero : " + $_.Exception.Message) }
}

# Historique horaire IMMORTEL (append-only, jamais purge) - source de verite
$hourlyHistPath = Join-Path $TelemetryDir 'hourly-history.jsonl'
$hourlyHist     = @{}
$persisted      = @{}   # etat tel qu'il etait sur disque avant cette collecte
if (Test-Path $hourlyHistPath) {
  $histRaw = [System.IO.File]::ReadAllLines($hourlyHistPath)
  foreach ($line in $histRaw) {
    if (-not $line) { continue }
    $line = $line.TrimStart([char]0xFEFF)   # immunise contre le BOM
    if ($line.Length -lt 10) { continue }
    $r = $null
    try { $r = $line | ConvertFrom-Json } catch { continue }
    if ($r.h) {
      $hourlyHist[$r.h] = [pscustomobject]@{
        h         = $r.h
        events    = [long]$r.events
        requests  = [long]$r.requests
        tokens    = [long]$r.tokens
        firstSeen = $r.firstSeen
      }
      $persisted[$r.h] = [long]$r.events
    }
  }
}

# 7a. actions nouvelles seulement (strictement posterieures au dernier agrégé)
$lastAgg = $null
if ($agg.lastAggregatedTs) { $lastAgg = [datetime]$agg.lastAggregatedTs }
$newEntries = @($journalArr | Where-Object { -not $lastAgg -or ([datetime]$_.ts) -gt $lastAgg })
foreach ($e in $newEntries) {
  $t = [datetime]$e.ts
  if ($e.tokens) { $agg.tokensTotal += [long]$e.tokens }
  $agg.requestsTotal++
  if (-not $agg.firstTs -or $t -lt [datetime]$agg.firstTs) { $agg.firstTs = $e.ts }
  if (-not $agg.lastTs  -or $t -gt [datetime]$agg.lastTs)  { $agg.lastTs  = $e.ts }
  $m = $(if ($e.model) { $e.model } else { 'unknown' })
  if ($agg.byModel.ContainsKey($m)) { $agg.byModel[$m] += $(if ($e.tokens) { [long]$e.tokens } else { 0 }) }
  else { $agg.byModel[$m] = $(if ($e.tokens) { [long]$e.tokens } else { 0 }) }
  if (-not $agg.lastAggregatedTs -or $t -gt [datetime]$agg.lastAggregatedTs) { $agg.lastAggregatedTs = $e.ts }
}

# 7b. evenements : deltas positifs par bucket horaire
foreach ($b in $hourlyArr) {
  $prev = 0
  if ($agg.hours.ContainsKey($b.h)) { $prev = [long]$agg.hours[$b.h] }
  if ($b.events -gt $prev) { $agg.eventsTotal += ([long]$b.events - $prev) }
  $agg.hours[$b.h] = [long]$b.events
  # miroir dans l'historique immortel (max par champ, jamais perdu)
  $existed = $hourlyHist.ContainsKey($b.h)
  $hPrev = $(if ($existed) { $hourlyHist[$b.h] } else { $null })
  $hourlyHist[$b.h] = [pscustomobject]@{
    h         = $b.h
    events    = if ($hPrev) { [math]::Max([long]$hPrev.events, [long]$b.events) } else { [long]$b.events }
    requests  = if ($hPrev) { [math]::Max([long]$hPrev.requests, [long]$b.requests) } else { [long]$b.requests }
    tokens    = if ($hPrev) { [math]::Max([long]$hPrev.tokens, [long]$b.tokens) } else { [long]$b.tokens }
    reportedTokens = if ($hPrev) { [math]::Max([long]$hPrev.reportedTokens, [long]$b.reportedTokens) } else { [long]$b.reportedTokens }
    unknownRequests = if ($hPrev) { [math]::Max([long]$hPrev.unknownRequests, [long]$b.unknownRequests) } else { [long]$b.unknownRequests }
    firstSeen = if ($hPrev) { $hPrev.firstSeen } else { $ts }
  }
}

# 7c. ecriture de l'historique immortel : REWRITE fusionnel trie (upsert max).
#     Rien ne se perd (toutes les valeurs maximales conservees), pas de doublon,
#     immunise contre BOM et chargements partiels.
$histLines = foreach ($k in ($hourlyHist.Keys | Sort-Object)) {
  $h = $hourlyHist[$k]
  "{`"h`":`"" + $h.h + "`",`"events`":" + $h.events + ",`"requests`":" + $h.requests + ",`"tokens`":" + $h.tokens + ",`"reportedTokens`":" + $h.reportedTokens + ",`"unknownRequests`":" + $h.unknownRequests + ",`"firstSeen`":`"" + $h.firstSeen + "`"}"
}
[System.IO.File]::WriteAllText($hourlyHistPath, (($histLines -join "
") + "
"), $utf8NoBom)
$hourlyHistCount = $hourlyHist.Count

# 7d. memoire buckets en JSON (72 h suffisent pour les deltas)
$horizon = (Get-Date).AddHours(-72).ToString("yyyy-MM-ddTHH:00")
@($agg.hours.Keys) | Where-Object { $_ -lt $horizon } | ForEach-Object { $agg.hours.Remove($_) }

$aggObj = [pscustomobject]@{
  firstTs = $agg.firstTs; lastTs = $agg.lastTs
  tokensTotal = $agg.tokensTotal; requestsTotal = $agg.requestsTotal; unknownRequestsTotal = $agg.unknownRequestsTotal; eventsTotal = $agg.eventsTotal
  byModel = $agg.byModel; lastAggregatedTs = $agg.lastAggregatedTs
  hourlyHistoryCount = $hourlyHistCount
}

# ---------- 8. ecriture des fichiers ----------
$jJson = ($journalArr | ConvertTo-Json -Depth 4 -Compress); if (-not $jJson) { $jJson = '[]' }
if ($journalArr.Count -eq 1) { $jJson = '[' + $jJson + ']' }
$hJson = ($hourlyArr  | ConvertTo-Json -Depth 4 -Compress); if (-not $hJson) { $hJson = '[]' }
if ($hourlyArr.Count  -eq 1) { $hJson = '[' + $hJson + ']' }
$aJson = ($aggObj | ConvertTo-Json -Depth 5 -Compress)

[System.IO.File]::WriteAllText((Join-Path $TelemetryDir 'latest.js'),     ("window.TDB_REMOTE="  + $json  + ";"), $utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $TelemetryDir 'journal.js'),    ("window.TDB_JOURNAL=" + $jJson + ";window.TDB_HOURLY=" + $hJson + ";"), $utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $TelemetryDir 'aggregates.js'), ("window.TDB_AGGR="    + $aJson + ";"), $utf8NoBom)
$metaObj = [pscustomobject]@{ refreshMode = $conf.refreshMode; intervalMinutes = [int]$conf.intervalMinutes; generated = $ts }
[System.IO.File]::WriteAllText((Join-Path $TelemetryDir 'meta.js'), ("window.TDB_META=" + ($metaObj | ConvertTo-Json -Compress) + ";"), $utf8NoBom)
$histArr = @($hourlyHist.Values | Sort-Object h)
$hJson = ($histArr | ConvertTo-Json -Depth 3 -Compress); if (-not $hJson) { $hJson = '[]' }
if ($histArr.Count -eq 1) { $hJson = '[' + $hJson + ']' }
[System.IO.File]::WriteAllText((Join-Path $TelemetryDir 'hourly-history.js'), ("window.TDB_HIST=" + $hJson + ";"), $utf8NoBom)
[System.IO.File]::WriteAllText($aggPath, ($aggObj | ConvertTo-Json -Depth 5), $utf8NoBom)

Add-Content -Path (Join-Path $TelemetryDir 'history.jsonl') -Value $json -Encoding UTF8
$histPath = Join-Path $TelemetryDir 'history.jsonl'
$histCut  = (Get-Date).AddDays(-$conf.historyMaxDays)
$lines = @(Get-Content $histPath -Encoding UTF8 | Where-Object {
  $_.Trim() -and $(if ($_ -match '"ts":"([^"]+)"') { [datetime]$Matches[1] -ge $histCut } else { $true })
})
if ($lines.Count -gt 0) { $lines | Set-Content -Path $histPath -Encoding UTF8 }

$deg = ''
if ($degraded.Count) { $deg = ' (mode degrade : ' + ($degraded -join ', ') + ')' }
Write-Output ("TDB OK $ts - journal=" + $journalArr.Count + " actions - aggTokens=" + $agg.tokensTotal + " - evt=" + $agg.eventsTotal + " - hoursPersisted=" + $hourlyHistCount + $deg)
