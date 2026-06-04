# weekly_refresh_candidates.ps1
# ASCII-only comments to avoid PowerShell 5.1 encoding problems.
#
# Refresh the candidate pool with a broader CloudflareST scan, conservatively:
#   - scan into a temporary result file,
#   - only overwrite candidates.txt if we got a healthy number of good IPs,
#   - keep a timestamped backup of the previous candidate list.
#
# This does NOT update hosts. Run run_once.ps1 (or wait for its scheduled task)
# to actually pick and apply an IP from the refreshed pool.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\weekly_refresh_candidates.ps1

[CmdletBinding()]
param(
    [int] $MinKeep = 10   # require at least this many good IPs before replacing
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

if (-not (Test-Path $Config.CloudflareSTExe)) {
    throw "CloudflareST.exe not found at '$($Config.CloudflareSTExe)'."
}

# The full-scan input pool. Reuse candidates.txt if present, otherwise the
# CloudflareST built-in ip.txt (when run from its own folder).
$inputPool = $Config.CandidatesPath
if (-not (Test-Path $inputPool)) {
    Write-Warning "No existing candidates.txt; CloudflareST will use its built-in pool."
    $inputPool = $null
}

$tmpResult = Join-Path $Config.WorkDir ("refresh-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

# ---- Build args --------------------------------------------------------------
$cfArgs = @('-o', $tmpResult, '-tl', [string] $Config.LatencyMaxMs, '-timeout', [string] $Config.TimeoutSec)
if ($inputPool) { $cfArgs += @('-f', $inputPool) }
if ($Config.SpeedMinMBps -gt 0) {
    $cfArgs += @('-sl', [string] $Config.SpeedMinMBps)
    if ($Config.TestUrl) { $cfArgs += @('-url', $Config.TestUrl) }
}
if ($Config.ExtraArgsWeekly) {
    $cfArgs += ($Config.ExtraArgsWeekly -split '\s+' | Where-Object { $_ -ne '' })
}

Write-Host "[refresh] running full CloudflareST scan..."
Write-Host "[refresh] $($Config.CloudflareSTExe) $($cfArgs -join ' ')"
& $Config.CloudflareSTExe @cfArgs | Out-Null

if (-not (Test-Path $tmpResult)) {
    throw "Refresh scan produced no result file; keeping existing candidates unchanged."
}

# ---- Extract good IPs --------------------------------------------------------
$rows = Import-Csv -LiteralPath $tmpResult
$cols = if ($rows -and $rows.Count -gt 0) { $rows[0].PSObject.Properties.Name } else { @() }
$ipCol = $null
foreach ($n in $cols) { if ($n -match 'IP' -or $n -match '地址') { $ipCol = $n; break } }
if (-not $ipCol -and $cols.Count -gt 0) { $ipCol = $cols[0] }

$ips = @()
foreach ($r in $rows) {
    $ip = ([string] $r.$ipCol).Trim()
    $tmp = $null
    if ([System.Net.IPAddress]::TryParse($ip, [ref] $tmp)) { $ips += $ip }
}
$ips = @($ips | Select-Object -Unique)

Write-Host "[refresh] scan returned $($ips.Count) usable IP(s)."
if ($ips.Count -lt $MinKeep) {
    Write-Warning "Only $($ips.Count) good IP(s) (< MinKeep=$MinKeep). Keeping existing candidates.txt unchanged."
    Remove-Item -LiteralPath $tmpResult -Force -ErrorAction SilentlyContinue
    return
}

# ---- Backup old candidates and write the new pool ----------------------------
if (Test-Path $Config.CandidatesPath) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    Copy-Item -LiteralPath $Config.CandidatesPath -Destination "$($Config.CandidatesPath).bak-$stamp" -Force
    Write-Host "[refresh] backed up previous candidates -> $($Config.CandidatesPath).bak-$stamp"
}
Set-Content -LiteralPath $Config.CandidatesPath -Value $ips -Encoding ASCII
Write-Host "[refresh] wrote $($ips.Count) IP(s) to $($Config.CandidatesPath)."

Remove-Item -LiteralPath $tmpResult -Force -ErrorAction SilentlyContinue
Write-Host "[done] candidate pool refreshed. Run run_once.ps1 to apply a pick."
