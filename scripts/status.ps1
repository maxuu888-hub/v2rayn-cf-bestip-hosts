# status.ps1
# ASCII-only comments to avoid PowerShell 5.1 encoding problems.
#
# Report current state: scheduled task status, the managed hosts block, and a
# summary of the last result CSV. Read-only; safe to run without admin.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\status.ps1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ---- Load config -------------------------------------------------------------
$ScriptDir  = $PSScriptRoot
$ConfigPath = Join-Path $ScriptDir 'config.ps1'
if (-not (Test-Path $ConfigPath)) {
    $ConfigPath = Join-Path $ScriptDir 'config.example.ps1'
    Write-Warning "config.ps1 not found; falling back to config.example.ps1."
}
$Config = & $ConfigPath

Write-Host "==== Scheduled tasks ===="
$taskNames = @(
    'v2rayn-cf-bestip-hosts - pick best IP',
    'v2rayn-cf-bestip-hosts - weekly refresh'
)
foreach ($tn in $taskNames) {
    $t = Get-ScheduledTask -TaskName $tn -ErrorAction SilentlyContinue
    if ($t) {
        $info = Get-ScheduledTaskInfo -TaskName $tn -ErrorAction SilentlyContinue
        Write-Host ("  [{0}] {1}" -f $t.State, $tn)
        if ($info) {
            Write-Host ("       last run : {0} (result 0x{1:X})" -f $info.LastRunTime, $info.LastTaskResult)
            Write-Host ("       next run : {0}" -f $info.NextRunTime)
        }
    } else {
        Write-Host ("  [not installed] {0}" -f $tn)
    }
}

Write-Host ""
Write-Host "==== Managed hosts block ===="
$hostsPath = $Config.HostsPath
if (Test-Path $hostsPath) {
    $lines    = @(Get-Content -LiteralPath $hostsPath -Encoding ASCII)
    $inBlock  = $false
    $printed  = $false
    foreach ($line in $lines) {
        if ($line.Trim() -eq $Config.BeginMarker) { $inBlock = $true }
        if ($inBlock) { Write-Host "  $line"; $printed = $true }
        if ($inBlock -and $line.Trim() -eq $Config.EndMarker) { $inBlock = $false }
    }
    if (-not $printed) { Write-Host "  (no managed block found in $hostsPath)" }
} else {
    Write-Host "  hosts file not found at $hostsPath"
}

Write-Host ""
Write-Host "==== Last result ===="
if (Test-Path $Config.ResultPath) {
    $item = Get-Item -LiteralPath $Config.ResultPath
    Write-Host ("  file     : {0}" -f $item.FullName)
    Write-Host ("  modified : {0}" -f $item.LastWriteTime)
    $rows = Import-Csv -LiteralPath $Config.ResultPath -ErrorAction SilentlyContinue
    if ($rows -and $rows.Count -gt 0) {
        Write-Host ("  rows     : {0}" -f $rows.Count)
        Write-Host "  top entries:"
        $rows | Select-Object -First 5 | Format-Table | Out-String | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host "  (result file present but empty / unparseable)"
    }
} else {
    Write-Host ("  no result file at {0}" -f $Config.ResultPath)
}

Write-Host ""
Write-Host "==== History ===="
if ($Config.ContainsKey('HistoryPath') -and (Test-Path $Config.HistoryPath)) {
    $historyItem = Get-Item -LiteralPath $Config.HistoryPath
    Write-Host ("  file     : {0}" -f $historyItem.FullName)
    Write-Host ("  modified : {0}" -f $historyItem.LastWriteTime)
    $historyLines = @(Get-Content -LiteralPath $Config.HistoryPath -Encoding UTF8)
    if ($historyLines.Count -gt 0) {
        $historyLines | Select-Object -Last 5 | ForEach-Object { Write-Host ("  {0}" -f $_) }
    } else {
        Write-Host "  (history file is empty)"
    }
} else {
    Write-Host "  (no history file configured yet)"
}
