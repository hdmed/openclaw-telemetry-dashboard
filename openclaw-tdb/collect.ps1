# ============================================================
#  TDB Collector v4 (portable) - OpenClaw Telemetry Dashboard
#  - Interroge la CLI OpenClaw (status --json) si disponible
#  - Extrait le journal des actions depuis les transcripts
#  - Suit input/output/cache separement (les providers muets
#    sont estimes par longueur de contenu, marques "estimated")
#  - Maintient des statistiques cumulees (stats-aggregates)
#  - Gestion d'erreurs exhaustive : chaque ecriture protegee,
#    resume des erreurs en fin d'execution
#  - Ecrit telemetry/{latest.js, journal.js, aggregates.js,
#    meta.js, hourly-history.js, hourly-history.jsonl,
#    history.jsonl, stats-aggregates.json}
#  Portable : chemins auto-detectes, surchargeables via
#  config.local.json (jamais committe). Aucun appel LLM.
# ============================================================
$ErrorActionPreference = 'Stop'
$ScriptDir    = $PSScriptRoot
$TelemetryDir = Join-Path $ScriptDir 'telemetry'
$utf8NoBom    = New-Object System.Text.UTF8Encoding($false)
$script:errors = [System.Collections.Generic.List[string]]::new()
function TryWrite($path, $content, $label) {
  try { [System.IO.File]::WriteAllText($path, $content, $utf8NoBom); return $true }
  catch { $script:errors.Add("$label : $($_.Exception.Message)"); return $false }
}
function SafeGet($path, $label) {
  try { if (Test-Path $path) { return [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) } } catch { $script:errors.Add("$label read : $($_.Exception.Message)") }
  return $null
}

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
    foreach ($k in 'cliPath','cfgPath','agentsRoot') { if ($lc.$k) { $conf.$k = [string]$lc.$k } }
    foreach ($k in 'historyMaxDays','journalMax','journalDays','intervalMinutes') { if ($null -ne $lc.$k) { $conf.$k = [int]$lc.$k } }
    if ($lc.refreshMode) { $conf.refreshMode = [string]$lc.refreshMode }
  } catch { $script:errors.Add("config.local.json : $($_.Exception.Message)") }
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
$st = $null; $main = $null; $rec = @(); $allRecent = @(); $agents = @(); $degraded = @()

# ---------- 1. statut gateway ----------
if ($cli) {
  try {
    $rawStatus = (& node $cli status --json 2>$null | Out-String)
    if ($rawStatus.Trim()) { $st = $rawStatus | ConvertFrom-Json }
    if (-not $st) { throw 'status vide' }
    $allRecent = @($st.sessions.recent)
    $rec       = @($allRecent | Where-Object { $_.key -notlike '*:cron:*' })
    # session principale : privilegier une session a compteurs frais
    # (sinon les KPI du snapshot passent a null selon la session sondee)
    $main = @($rec | Where-Object { $_.key -like 'agent:main:*' -and $_.totalTokensFresh -and $_.totalTokens } | Select-Object -First 1)
    if (-not $main) { $main = @($rec | Where-Object { $_.totalTokensFresh -and $_.totalTokens } | Select-Object -First 1) }
    if (-not $main) { $main = @($rec | Where-Object { $_.key -like 'agent:main:*' } | Select-Object -First 1) }
    if (-not $main) { $main = $rec | Select-Object -First 1 }
  } catch { $degraded += 'status'; $script:errors.Add("status --json : $($_.Exception.Message)") }
} else { $degraded += 'cli-absente' }

# ---------- 2. agents + modeles ----------
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
  } catch { $degraded += 'config'; $script:errors.Add("config : $($_.Exception.Message)") }
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
  runtimeVersion  = $(if ($st -and $st.runtimeVersion) { $st.runtimeVersion } else { $null })
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
  cronsTotal      = @($allRecent | Where-Object { $_.kind -eq 'cron' -or $_.key -like '*:cron:*' }).Count
  subagentsActive = 0
  channels        = $(if ($st -and $st.channelSummary) { (@($st.channelSummary | ForEach-Object { if ($_ -is [string]) { $_ } elseif ($_.channel) { [string]$_.channel } elseif ($_.name) { [string]$_.name } }) -join ', ') } else { '' })
  sessions        = $sessRows
  agents          = $agents
} | ConvertTo-Json -Depth 5 -Compress

# ---------- 6. journal des actions ----------
$journal = New-Object System.Collections.Generic.List[object]
$hourly  = @{}
$since   = (Get-Date).AddDays(-$conf.journalDays)
$parseErrors = 0

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
        try { $o = $line | ConvertFrom-Json } catch { $parseErrors++; continue }
        if (-not $o.timestamp) { continue }
        $tsCur = [datetime]$o.timestamp
        $hKey = $tsCur.ToString("yyyy-MM-ddTHH:00")
        if (-not $hourly.ContainsKey($hKey)) {
          $hourly[$hKey] = [pscustomobject]@{ h = $hKey; events = 0; requests = 0; tokens = 0; reportedTokens = 0; inputTokens = 0; outputTokens = 0; unknownRequests = 0 }
        }
        $hourly[$hKey].events++

        $role = $o.message.role
        if ($role -eq 'user') {
          $txt = ''
          $c = $o.message.content
          if ($c -is [string]) { $txt = $c }
          else { foreach ($part in @($c)) { if ($part.type -eq 'text') { $txt += $part.text + ' ' } } }
          do { $prevLen = $txt.Length; $txt = $txt -replace '(?s)<system-reminder>.*?</system-reminder>', '' } while ($txt.Length -lt $prevLen -and $txt -match '<system-reminder>')
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

          # --- classification tokens : reported > estimated > unknown ---
          $tok = $null; $tokIn = $null; $tokOut = $null; $tokenStatus = "unknown"
          if ($u -and [long]$u.totalTokens -gt 0) {
            $tok = [long]$u.totalTokens
            $tokIn = [long]$u.input
            $tokOut = [long]$u.output
            $tokenStatus = "reported"
          } elseif ($u -and [long]$u.totalTokens -eq 0) {
            # provider muet : estimation par longueur de contenu
            $outLen = 0; $thinkLen = 0
            foreach ($part in @($o.message.content)) {
              if ($part.type -eq "text" -and $part.text) { $outLen += $part.text.Length }
              elseif ($part.type -eq "thinking" -and $part.thinking) { $thinkLen += $part.thinking.Length }
            }
            $tokOut = [long][math]::Ceiling($outLen / 3.5)
            $tok = $tokOut + [long][math]::Ceiling($thinkLen / 3.5)
            $tokenStatus = "estimated"
          }

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
            inputTokens  = $tokIn
            outputTokens = $tokOut
            tokenStatus = $tokenStatus
            state      = $(switch ($o.message.stopReason) {
                            'stop'    { '✅ terminé' }
                            'toolUse' { '🔧 outils' }
                            'abort'   { '⛔ interrompu' }
                            'error'   { '❌ erreur' }
                            default   { $o.message.stopReason } })
          })
          $hourly[$hKey].requests++
          if ($tok) { $hourly[$hKey].tokens += $tok }
          if ($tokenStatus -eq "reported") { $hourly[$hKey].reportedTokens += $tok }
          if ($tokIn) { $hourly[$hKey].inputTokens += $tokIn }
          if ($tokOut) { $hourly[$hKey].outputTokens += $tokOut }
          if ($tokenStatus -eq "unknown") { $hourly[$hKey].unknownRequests++ }
        }
        $lastTs = $tsCur
      }
    }
  }
}
if ($parseErrors -gt 0) { $script:errors.Add("transcript parse : $parseErrors lignes ignorees") }

$journalArr = @($journal | Sort-Object { [datetime]$_.ts })
$hourlyArr  = @($hourly.Values | Sort-Object h)

# ---------- 7. statistiques cumulees ----------
New-Item -ItemType Directory -Force -Path $TelemetryDir | Out-Null
$aggPath = Join-Path $TelemetryDir 'stats-aggregates.json'
$agg = @{ firstTs = $null; lastTs = $null; tokensTotal = 0; inputTokensTotal = 0; outputTokensTotal = 0; requestsTotal = 0; unknownRequestsTotal = 0; eventsTotal = 0; byModel = @{}; lastAggregatedTs = $null }
$aggRaw = SafeGet $aggPath 'aggregates'
if ($aggRaw) {
  try {
    $a0 = $aggRaw | ConvertFrom-Json
    $agg.firstTs          = $a0.firstTs
    $agg.lastTs           = $a0.lastTs
    $agg.tokensTotal      = [long]$a0.tokensTotal
    $agg.requestsTotal    = [long]$a0.requestsTotal
    $agg.unknownRequestsTotal = [long]$(if ($null -ne $a0.unknownRequestsTotal) { $a0.unknownRequestsTotal } else { 0 })
    $agg.inputTokensTotal  = [long]$(if ($null -ne $a0.inputTokensTotal) { $a0.inputTokensTotal } else { 0 })
    $agg.outputTokensTotal = [long]$(if ($null -ne $a0.outputTokensTotal) { $a0.outputTokensTotal } else { 0 })
    $agg.eventsTotal      = [long]$a0.eventsTotal
    $agg.lastAggregatedTs = $a0.lastAggregatedTs
    if ($a0.byModel) { foreach ($p in $a0.byModel.PSObject.Properties) { $agg.byModel[$p.Name] = [long]$p.Value } }
  } catch { $script:errors.Add("aggregates load : $($_.Exception.Message)") }
}

# Historique horaire IMMORTEL
$hourlyHistPath = Join-Path $TelemetryDir 'hourly-history.jsonl'
$hourlyHist     = @{}
$persisted      = @{}
$histRaw = SafeGet $hourlyHistPath 'hourly-history'
if ($histRaw) {
  foreach ($line in ($histRaw -split "`r?`n")) {
    if (-not $line -or $line.Length -lt 10) { continue }
    $line = $line.TrimStart([char]0xFEFF)
    $r = $null
    try { $r = $line | ConvertFrom-Json } catch { continue }
    if ($r.h) {
      $hourlyHist[$r.h] = [pscustomobject]@{
        h         = $r.h
        events    = [long]$r.events
        requests  = [long]$r.requests
        tokens    = [long]$r.tokens
        inputTokens  = [long]$(if ($null -ne $r.inputTokens) { $r.inputTokens } else { 0 })
        outputTokens = [long]$(if ($null -ne $r.outputTokens) { $r.outputTokens } else { 0 })
        reportedTokens = [long]$(if ($null -ne $r.reportedTokens) { $r.reportedTokens } else { $r.tokens })
        unknownRequests = [long]$(if ($null -ne $r.unknownRequests) { $r.unknownRequests } else { 0 })
        firstSeen = $r.firstSeen
      }
      $persisted[$r.h] = [long]$r.events
    }
  }
}

# 7a. actions nouvelles
$lastAgg = $null
if ($agg.lastAggregatedTs) { $lastAgg = [datetime]$agg.lastAggregatedTs }
$newEntries = @($journalArr | Where-Object { -not $lastAgg -or ([datetime]$_.ts) -gt $lastAgg })
foreach ($e in $newEntries) {
  $t = [datetime]$e.ts
  if ($e.tokens) { $agg.tokensTotal += [long]$e.tokens }
  if ($e.inputTokens) { $agg.inputTokensTotal += [long]$e.inputTokens }
  if ($e.outputTokens) { $agg.outputTokensTotal += [long]$e.outputTokens }
  $agg.requestsTotal++
  if ($e.tokenStatus -eq "unknown") { $agg.unknownRequestsTotal++ }
  if (-not $agg.firstTs -or $t -lt [datetime]$agg.firstTs) { $agg.firstTs = $e.ts }
  if (-not $agg.lastTs  -or $t -gt [datetime]$agg.lastTs)  { $agg.lastTs  = $e.ts }
  $m = $(if ($e.model) { $e.model } else { 'unknown' })
  if ($agg.byModel.ContainsKey($m)) { $agg.byModel[$m] += $(if ($e.tokens) { [long]$e.tokens } else { 0 }) }
  else { $agg.byModel[$m] = $(if ($e.tokens) { [long]$e.tokens } else { 0 }) }
  if (-not $agg.lastAggregatedTs -or $t -gt [datetime]$agg.lastAggregatedTs) { $agg.lastAggregatedTs = $e.ts }
}

# 7b. miroir historique immortel (eventsTotal est recalcule plus bas
#     comme somme autoritaire de cet historique)
foreach ($b in $hourlyArr) {
  $existed = $hourlyHist.ContainsKey($b.h)
  $hPrev = $(if ($existed) { $hourlyHist[$b.h] } else { $null })
  $hourlyHist[$b.h] = [pscustomobject]@{
    h         = $b.h
    events    = if ($hPrev) { [math]::Max([long]$hPrev.events, [long]$b.events) } else { [long]$b.events }
    requests  = if ($hPrev) { [math]::Max([long]$hPrev.requests, [long]$b.requests) } else { [long]$b.requests }
    tokens    = if ($hPrev) { [math]::Max([long]$hPrev.tokens, [long]$b.tokens) } else { [long]$b.tokens }
    inputTokens  = if ($hPrev) { [math]::Max([long]$hPrev.inputTokens, [long]$b.inputTokens) } else { [long]$b.inputTokens }
    outputTokens = if ($hPrev) { [math]::Max([long]$hPrev.outputTokens, [long]$b.outputTokens) } else { [long]$b.outputTokens }
    reportedTokens = if ($hPrev) { [math]::Max([long]$hPrev.reportedTokens, [long]$b.reportedTokens) } else { [long]$b.reportedTokens }
    unknownRequests = if ($hPrev) { [math]::Max([long]$hPrev.unknownRequests, [long]$b.unknownRequests) } else { [long]$b.unknownRequests }
    firstSeen = if ($hPrev) { $hPrev.firstSeen } else { $ts }
  }
}

# 7c. ecriture historique immortel
$histLines = foreach ($k in ($hourlyHist.Keys | Sort-Object)) {
  $h = $hourlyHist[$k]
  "{`"h`":`"" + $h.h + "`",`"events`":" + $h.events + ",`"requests`":" + $h.requests + ",`"tokens`":" + $h.tokens + ",`"inputTokens`":" + $h.inputTokens + ",`"outputTokens`":" + $h.outputTokens + ",`"reportedTokens`":" + $h.reportedTokens + ",`"unknownRequests`":" + $h.unknownRequests + ",`"firstSeen`":`"" + $h.firstSeen + "`"}"
}
$histContent = (($histLines -join "`r`n") + "`r`n")
if (-not (TryWrite $hourlyHistPath $histContent 'hourly-history.jsonl')) { $script:errors.Add('hourly-history.jsonl : ecriture echouee') }
# eventsTotal : somme de l'historique horaire immortel. Auto-reparation des
# anciens cumuls corrompus par la logique delta non persistee.
$agg.eventsTotal = [long](($hourlyHist.Values | Measure-Object -Property events -Sum).Sum)
$hourlyHistCount = $hourlyHist.Count

$aggObj = [pscustomobject]@{
  firstTs = $agg.firstTs; lastTs = $agg.lastTs
  tokensTotal = $agg.tokensTotal; inputTokensTotal = $agg.inputTokensTotal; outputTokensTotal = $agg.outputTokensTotal
  requestsTotal = $agg.requestsTotal; unknownRequestsTotal = $agg.unknownRequestsTotal; eventsTotal = $agg.eventsTotal
  byModel = $agg.byModel; lastAggregatedTs = $agg.lastAggregatedTs
  hourlyHistoryCount = $hourlyHistCount
}

# ---------- 8. ecriture des fichiers (chaque ecriture protegee) ----------
# publication du journal : plafond journalMax applique ici, apres l'agregation
# des totaux (qui reste calculee sur le journal complet)
$jOut = $journalArr
if ($jOut.Count -gt $conf.journalMax) { $jOut = @($jOut | Select-Object -Last $conf.journalMax) }
$jJson = ($jOut | ConvertTo-Json -Depth 4 -Compress); if (-not $jJson) { $jJson = '[]' }
if ($jOut.Count -eq 1) { $jJson = '[' + $jJson + ']' }
$hJson = ($hourlyArr  | ConvertTo-Json -Depth 4 -Compress); if (-not $hJson) { $hJson = '[]' }
if ($hourlyArr.Count  -eq 1) { $hJson = '[' + $hJson + ']' }
$aJson = ($aggObj | ConvertTo-Json -Depth 5 -Compress)

TryWrite (Join-Path $TelemetryDir 'latest.js')     ("window.TDB_REMOTE="  + $json  + ";") 'latest.js'     | Out-Null
TryWrite (Join-Path $TelemetryDir 'journal.js')    ("window.TDB_JOURNAL=" + $jJson + ";window.TDB_HOURLY=" + $hJson + ";") 'journal.js' | Out-Null
TryWrite (Join-Path $TelemetryDir 'aggregates.js') ("window.TDB_AGGR="    + $aJson + ";") 'aggregates.js' | Out-Null
$metaObj = [pscustomobject]@{ refreshMode = $conf.refreshMode; intervalMinutes = [int]$conf.intervalMinutes; generated = $ts }
TryWrite (Join-Path $TelemetryDir 'meta.js') ("window.TDB_META=" + ($metaObj | ConvertTo-Json -Compress) + ";") 'meta.js' | Out-Null
$histArr = @($hourlyHist.Values | Sort-Object h)
$hJson2 = ($histArr | ConvertTo-Json -Depth 3 -Compress); if (-not $hJson2) { $hJson2 = '[]' }
if ($histArr.Count -eq 1) { $hJson2 = '[' + $hJson2 + ']' }
TryWrite (Join-Path $TelemetryDir 'hourly-history.js') ("window.TDB_HIST=" + $hJson2 + ";") 'hourly-history.js' | Out-Null
TryWrite $aggPath ($aggObj | ConvertTo-Json -Depth 5) 'stats-aggregates.json' | Out-Null

try { Add-Content -Path (Join-Path $TelemetryDir 'history.jsonl') -Value $json -Encoding UTF8 } catch { $script:errors.Add("history.jsonl append : $($_.Exception.Message)") }
$histPath = Join-Path $TelemetryDir 'history.jsonl'
try {
  $histCut  = (Get-Date).AddDays(-$conf.historyMaxDays)
  $lines = @(Get-Content $histPath -Encoding UTF8 -ErrorAction SilentlyContinue | Where-Object {
    $_.Trim() -and $(if ($_ -match '"ts":"([^"]+)"') { [datetime]$Matches[1] -ge $histCut } else { $true })
  })
  if ($lines.Count -gt 0) { $lines | Set-Content -Path $histPath -Encoding UTF8 }
} catch { $script:errors.Add("history.jsonl purge : $($_.Exception.Message)") }

# ---------- resume ----------
$deg = ''
if ($degraded.Count) { $deg = ' (degrade : ' + ($degraded -join ', ') + ')' }
$errSummary = ''
if ($script:errors.Count) { $errSummary = ' - ERREURS: ' + $script:errors.Count + ' [' + ($script:errors[0]) + ']' }
Write-Output ("TDB OK $ts - journal=" + $jOut.Count + " - aggTok=" + $agg.tokensTotal + " (in=" + $agg.inputTokensTotal + " out=" + $agg.outputTokensTotal + ") - evt=" + $agg.eventsTotal + " - unk=" + $agg.unknownRequestsTotal + " - hours=" + $hourlyHistCount + $deg + $errSummary)
