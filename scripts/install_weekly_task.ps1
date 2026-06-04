# install_weekly_task.ps1
# ASCII-only comments to avoid PowerShell 5.1 encoding problems.
#
# Register a Scheduled Task that runs weekly_refresh_candidates.ps1 once a week
# to refresh the candidate IP pool. Runs as SYSTEM.
#
# Usage:
#   (elevated) powershell -ExecutionPolicy Bypass -File scripts\install_weekly_task.ps1
#   ... -DayOfWeek Sunday -At 04:00

[CmdletBinding()]
param(
    [ValidateSet('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')]
    [string] $DayOfWeek = 'Sunday',

    [string] $At = '04:00'
)

$ErrorActionPreference = 'Stop'

$TaskName  = 'v2rayn-cf-bestip-hosts - weekly refresh'
$ScriptDir = $PSScriptRoot
$Target    = Join-Path $ScriptDir 'weekly_refresh_candidates.ps1'

$principalCheck = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principalCheck.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Administrator rights are required to register a scheduled task. Re-run from an elevated PowerShell."
}

$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $Target)

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DayOfWeek -At $At

$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -DontStopOnIdleEnd `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2)

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings -Force | Out-Null

Write-Host "[task] registered '$TaskName' ($DayOfWeek at $At, as SYSTEM)."
Write-Host "[task] target: $Target"
