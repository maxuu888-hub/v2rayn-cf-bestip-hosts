# install_all_tasks.ps1
# ASCII-only comments to avoid PowerShell 5.1 encoding problems.
#
# Convenience wrapper: install both scheduled tasks (periodic best-IP pick and
# weekly candidate refresh). Pass-through parameters are forwarded.
#
# Usage:
#   (elevated) powershell -ExecutionPolicy Bypass -File scripts\install_all_tasks.ps1

[CmdletBinding()]
param(
    [int]    $IntervalHours = 6,
    [string] $DayOfWeek     = 'Sunday',
    [string] $At            = '04:00'
)

$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot

& (Join-Path $ScriptDir 'install_task.ps1')        -IntervalHours $IntervalHours
& (Join-Path $ScriptDir 'install_weekly_task.ps1') -DayOfWeek $DayOfWeek -At $At

Write-Host "[done] both scheduled tasks installed."
