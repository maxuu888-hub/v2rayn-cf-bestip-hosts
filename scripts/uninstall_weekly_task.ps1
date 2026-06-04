# uninstall_weekly_task.ps1
# ASCII-only comments to avoid PowerShell 5.1 encoding problems.
#
# Remove the weekly candidate-refresh Scheduled Task. Does NOT touch hosts or
# candidates.txt.
#
# Usage:
#   (elevated) powershell -ExecutionPolicy Bypass -File scripts\uninstall_weekly_task.ps1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$TaskName = 'v2rayn-cf-bestip-hosts - weekly refresh'

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "[task] removed '$TaskName'."
} else {
    Write-Host "[task] '$TaskName' not found; nothing to remove."
}
