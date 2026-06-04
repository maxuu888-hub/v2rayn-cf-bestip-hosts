# uninstall_task.ps1
# ASCII-only comments to avoid PowerShell 5.1 encoding problems.
#
# Remove the periodic best-IP Scheduled Task. This does NOT revert the hosts
# file; see the manual rollback note printed below and docs\security-and-rollback.md.
#
# Usage:
#   (elevated) powershell -ExecutionPolicy Bypass -File scripts\uninstall_task.ps1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$TaskName = 'v2rayn-cf-bestip-hosts - pick best IP'

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "[task] removed '$TaskName'."
} else {
    Write-Host "[task] '$TaskName' not found; nothing to remove."
}

Write-Host ""
Write-Host "NOTE: the hosts file was NOT changed. To roll back the managed entries:"
Write-Host "  - run scripts\status.ps1 to view the current managed block, or"
Write-Host "  - manually delete the lines between the BEGIN / END markers in"
Write-Host "    $env:SystemRoot\System32\drivers\etc\hosts, or"
Write-Host "  - restore the newest hosts.bak-* backup next to the hosts file."
