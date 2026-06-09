# run_once.ps1
# ASCII-only comments to avoid PowerShell 5.1 encoding problems.
#
# One-shot: run CloudflareST against the candidate list, parse the result CSV,
# choose the best IP (zero loss first, then lowest latency, then highest speed),
# append a history row, and hand the uplink result to update_hosts.ps1.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\run_once.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\run_once.ps1 -SkipTest
#       (reuse an existing result.csv instead of re-running the speed test)

[CmdletBinding()]
param(
    [switch] $SkipTest,
    [switch] $WhatIfHosts   # parse + pick but do not modify hosts
)

$ErrorActionPreference = 'Stop'

# ---- Load config -------------------------------------------------------------
$ScriptDir  = $PSScriptRoot
$ConfigPath = Join-Path $ScriptDir 'config.ps1'
if (-not (Test-Path $ConfigPath)) {
    $ConfigPath = Join-Path $ScriptDir 'config.example.ps1'
    Write-Warning "config.ps1 not found; falling back to config.example.ps1."
}
$Config = & $ConfigPath

# ---- Run CloudflareST --------------------------------------------------------
if (-not $SkipTest) {
    if (-not (Test-Path $Config.CloudflareSTExe)) {
        throw "CloudflareST.exe not found at '$($Config.CloudflareSTExe)'. Download it from https://github.com/XIU2/CloudflareSpeedTest/releases and set CloudflareSTExe in config.ps1."
    }
    if (-not (Test-Path $Config.CandidatesPath)) {
        throw "Candidate file not found at '$($Config.CandidatesPath)'. Copy templates\candidates.example.txt or run weekly_refresh_candidates.ps1."
    }

    # Build the argument list. -f input, -o output, plus thresholds.
    $cfArgs = @(
        '-f', $Config.CandidatesPath,
        '-o', $Config.ResultPath,
        '-tl', [string] $Config.LatencyMaxMs,
        '-timeout', [string] $Config.TimeoutSec
    )
    if ($Config.SpeedMinMBps -gt 0) {
        $cfArgs += @('-sl', [string] $Config.SpeedMinMBps)
        if ($Config.TestUrl) { $cfArgs += @('-url', $Config.TestUrl) }
    }
    if ($Config.ExtraArgsQuick) {
        # Split extra args on whitespace into individual tokens.
        $cfArgs += ($Config.ExtraArgsQuick -split '\s+' | Where-Object { $_ -ne '' })
    }

    Write-Host "[test] running CloudflareST..."
    Write-Host "[test] $($Config.CloudflareSTExe) $($cfArgs -join ' ')"

    $argList = @()
    foreach ($arg in $cfArgs) {
        if ($arg -match '\s') {
            $argList += ('"{0}"' -f $arg.Replace('"', '""'))
        } else {
            $argList += $arg
        }
    }

    $p = Start-Process -FilePath $Config.CloudflareSTExe -ArgumentList $argList -PassThru -NoNewWindow
    $timeoutSec = 0
    if ($Config.ContainsKey('QuickTimeoutSec') -and $Config.QuickTimeoutSec) {
        $timeoutSec = [int] $Config.QuickTimeoutSec
    }

    if ($timeoutSec -gt 0) {
        $finished = $p.WaitForExit($timeoutSec * 1000)
        if (-not $finished) {
            Write-Warning "CloudflareST timed out after $timeoutSec seconds; stopping the process and parsing any partial result CSV."
            try {
                Stop-Process -Id $p.Id -Force -ErrorAction Stop
            } catch {
                Write-Warning "Could not stop CloudflareST cleanly: $($_.Exception.Message)"
            }
        } else {
            $LASTEXITCODE = $p.ExitCode
        }
    } else {
        $p.WaitForExit()
        $LASTEXITCODE = $p.ExitCode
    }

    if ($p.HasExited -and $p.ExitCode -ne 0) {
        Write-Warning "CloudflareST exited with code $($p.ExitCode); will still try to parse $($Config.ResultPath)."
    }
}

if (-not (Test-Path $Config.ResultPath)) {
    throw "Result CSV not found at '$($Config.ResultPath)'. The speed test may have produced no usable IPs (try loosening LatencyMaxMs / SpeedMinMBps)."
}

# ---- Parse the result CSV ----------------------------------------------------
# CloudflareST headers differ by build/language. We match columns by keyword and
# fall back to the first column for the IP if nothing matches.
$rows = Import-Csv -LiteralPath $Config.ResultPath
if (-not $rows -or $rows.Count -eq 0) {
    throw "Result CSV '$($Config.ResultPath)' has no rows. No IP met the thresholds."
}

$columns = $rows[0].PSObject.Properties.Name

function Find-Column {
    param([string[]] $Names, [string[]] $Keywords)
    foreach ($kw in $Keywords) {
        foreach ($n in $Names) {
            if ($n -and ($n -match $kw)) { return $n }
        }
    }
    return $null
}

# Keyword sets cover English and Chinese CloudflareST headers.
$ipCol    = Find-Column -Names $columns -Keywords @('IP ?Address', 'IP', 'IP 地址', '地址')
$lossCol  = Find-Column -Names $columns -Keywords @('Loss', '丢包')
$latCol   = Find-Column -Names $columns -Keywords @('Latency', 'Avg', 'RTT', '延迟', '平均延迟')
$speedCol = Find-Column -Names $columns -Keywords @('Speed', 'Download', '下载', '速度')

# Fallback: first column is almost always the IP.
if (-not $ipCol) { $ipCol = $columns[0] }

Write-Host "[parse] columns -> ip='$ipCol' loss='$lossCol' latency='$latCol' speed='$speedCol'"

function ConvertTo-Double([object] $v) {
    if ($null -eq $v) { return $null }
    $s = ([string] $v).Trim()
    if ($s -eq '') { return $null }
    # Strip any non-numeric trailing units, keep digits / dot / minus.
    $s = ($s -replace '[^0-9\.\-]', '')
    $d = 0.0
    if ([double]::TryParse($s, [ref] $d)) { return $d }
    return $null
}

$candidates = foreach ($r in $rows) {
    $ip = ([string] $r.$ipCol).Trim()
    $tmp = $null
    if (-not [System.Net.IPAddress]::TryParse($ip, [ref] $tmp)) { continue }
    [PSCustomObject]@{
        Ip      = $ip
        Loss    = if ($lossCol)  { ConvertTo-Double $r.$lossCol }  else { $null }
        Latency = if ($latCol)   { ConvertTo-Double $r.$latCol }   else { $null }
        Speed   = if ($speedCol) { ConvertTo-Double $r.$speedCol } else { $null }
    }
}
$candidates = @($candidates)
if ($candidates.Count -eq 0) {
    throw "No valid IP rows parsed from '$($Config.ResultPath)'."
}

# ---- Pick the best IP --------------------------------------------------------
# Priority: zero packet loss, then lowest latency, then highest download speed.
# Missing loss is treated as 0; missing latency as +inf; missing speed as 0.
$ranked = $candidates | Sort-Object `
    @{ Expression = { if ($null -eq $_.Loss) { 0 } else { $_.Loss } };    Ascending = $true }, `
    @{ Expression = { if ($null -eq $_.Latency) { [double]::PositiveInfinity } else { $_.Latency } }; Ascending = $true }, `
    @{ Expression = { if ($null -eq $_.Speed) { 0 } else { $_.Speed } };  Ascending = $false }

$top = @($ranked | Select-Object -First ([math]::Max(1, [int] $Config.TopN)))
$best = $top[0]

Write-Host "[pick] best IP: $($best.Ip) (loss=$($best.Loss) latency=$($best.Latency)ms speed=$($best.Speed)MB/s)"
if ($top.Count -gt 1) {
    Write-Host "[pick] runners-up:"
    $top | Select-Object -Skip 1 | ForEach-Object {
        Write-Host "         $($_.Ip) (loss=$($_.Loss) latency=$($_.Latency)ms speed=$($_.Speed)MB/s)"
    }
}

# ---- Append history ----------------------------------------------------------
if ($Config.ContainsKey('HistoryPath') -and $Config.HistoryPath) {
    $historyPath = $Config.HistoryPath
    $historyDir = Split-Path -Parent $historyPath
    if ($historyDir -and -not (Test-Path $historyDir)) {
        New-Item -ItemType Directory -Path $historyDir -Force | Out-Null
    }
    if (-not (Test-Path $historyPath)) {
        'time,best_ip,raw_row' | Set-Content -LiteralPath $historyPath -Encoding UTF8
    }
    $rawRow = ('{0},{1},{2},{3}' -f $best.Ip, $best.Loss, $best.Latency, $best.Speed)
    $line = '{0},{1},"{2}"' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $best.Ip, $rawRow
    Add-Content -LiteralPath $historyPath -Value $line -Encoding UTF8
    Write-Host "[history] appended -> $historyPath"
}

# ---- Update hosts ------------------------------------------------------------
if ($WhatIfHosts) {
    Write-Host "[whatif] would map uplink alias $($Config.UpAlias) -> $($best.Ip); hosts not modified."
    return
}

$updateScript = Join-Path $ScriptDir 'update_hosts.ps1'
& $updateScript -UpIp $best.Ip
