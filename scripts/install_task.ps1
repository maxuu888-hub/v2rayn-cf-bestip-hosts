# install_task.ps1
# ASCII-only comments to avoid PowerShell 5.1 encoding problems.
#
# Register a Scheduled Task that periodically runs run_once.ps1 to re-pick the
# best Cloudflare IP and update the hosts file. Runs as SYSTEM (highest
# privileges) so the hosts edit and DNS flush succeed unattended.
#
# Usage:
#   (elevated) powershell -ExecutionPolicy Bypass -File scripts\install_task.ps1
#   ... -IntervalHours 24

[CmdletBinding()]
param(
    [int] $IntervalHours = 24
)

$ErrorActionPreference = 'Stop'

$TaskName  = 'v2rayn-cf-bestip-hosts - pick best IP'
$ScriptDir = $PSScriptRoot
$Target    = Join-Path $ScriptDir 'run_once.ps1'

# Require admin to register a SYSTEM task.
$principalCheck = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principalCheck.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Administrator rights are required to register a scheduled task. Re-run from an elevated PowerShell."
}

$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $Target)

# Repeat forever at the chosen interval, starting shortly after registration.
$trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(2)) `
    -RepetitionInterval (New-TimeSpan -Hours $IntervalHours)

$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -DontStopOnIdleEnd `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1)

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings -Force | Out-Null

Write-Host "[task] registered '$TaskName' (every $IntervalHours h, as SYSTEM)."
Write-Host "[task] target: $Target"
