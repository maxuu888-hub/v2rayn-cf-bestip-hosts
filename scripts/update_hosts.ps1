# update_hosts.ps1
# ASCII-only comments to avoid PowerShell 5.1 encoding problems.
#
# Safely update the Windows hosts file so the stable local alias(es) point at the
# chosen IP(s). This script:
#   - requires Administrator,
#   - backs up hosts with a timestamp before changing anything,
#   - rewrites ONLY the block between the BEGIN / END markers,
#   - flushes the DNS resolver cache.
#
# Usage:
#   .\update_hosts.ps1 -UpIp <ip> [-DownIp <ip>]
# If -DownIp is omitted, only the up alias is updated unless you intentionally
# pass a separate downlink IP.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $UpIp,

    [Parameter(Mandatory = $false)]
    [string] $DownIp
)

$ErrorActionPreference = 'Stop'

# ---- Load config -------------------------------------------------------------
$ScriptDir = $PSScriptRoot
$ConfigPath = Join-Path $ScriptDir 'config.ps1'
if (-not (Test-Path $ConfigPath)) {
    $ConfigPath = Join-Path $ScriptDir 'config.example.ps1'
    Write-Warning "config.ps1 not found; falling back to config.example.ps1."
}
$Config = & $ConfigPath

# ---- Require Administrator ---------------------------------------------------
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin   = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    throw "Administrator rights are required to edit the hosts file. Re-run from an elevated PowerShell."
}

# ---- Validate inputs ---------------------------------------------------------
function Test-IsIp([string] $value) {
    $tmp = $null
    return [System.Net.IPAddress]::TryParse($value, [ref] $tmp)
}
if (-not (Test-IsIp $UpIp)) { throw "UpIp '$UpIp' is not a valid IP address." }
if ($DownIp -and -not (Test-IsIp $DownIp)) { throw "DownIp '$DownIp' is not a valid IP address." }

$hostsPath   = $Config.HostsPath
$beginMarker = $Config.BeginMarker
$endMarker   = $Config.EndMarker

if (-not (Test-Path $hostsPath)) { throw "Hosts file not found at $hostsPath." }

# ---- Backup hosts with timestamp --------------------------------------------
$stamp      = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupPath = "$hostsPath.bak-$stamp"
Copy-Item -LiteralPath $hostsPath -Destination $backupPath -Force
Write-Host "[backup] hosts -> $backupPath"

# ---- Build the managed block -------------------------------------------------
$managedLines = New-Object System.Collections.Generic.List[string]
$managedLines.Add($beginMarker)
$managedLines.Add("# Updated: $stamp")
$managedLines.Add(("{0}`t{1}" -f $UpIp, $Config.UpAlias))
if ($Config.UseSeparateUpDown -and $DownIp) {
    $managedLines.Add(("{0}`t{1}" -f $DownIp, $Config.DownAlias))
}
$managedLines.Add($endMarker)

# ---- Read existing hosts and strip any previous managed block ----------------
# Read as raw lines, preserving everything outside the markers untouched.
$existing = @(Get-Content -LiteralPath $hostsPath -Encoding ASCII)

$result   = New-Object System.Collections.Generic.List[string]
$inBlock  = $false
$found    = $false
foreach ($line in $existing) {
    if ($line.Trim() -eq $beginMarker) { $inBlock = $true; $found = $true; continue }
    if ($inBlock -and $line.Trim() -eq $endMarker) { $inBlock = $false; continue }
    if (-not $inBlock) { $result.Add($line) }
}

# Drop trailing blank lines so we append cleanly.
while ($result.Count -gt 0 -and [string]::IsNullOrWhiteSpace($result[$result.Count - 1])) {
    $result.RemoveAt($result.Count - 1)
}

# Append the freshly built managed block.
$result.Add('')
foreach ($l in $managedLines) { $result.Add($l) }

# ---- Write back (ASCII, no BOM) ---------------------------------------------
Set-Content -LiteralPath $hostsPath -Value $result -Encoding ASCII
if ($found) {
    Write-Host "[hosts] replaced existing managed block."
} else {
    Write-Host "[hosts] added new managed block."
}
Write-Host "[hosts] $($Config.UpAlias) -> $UpIp"
if ($Config.UseSeparateUpDown -and $DownIp) {
    Write-Host "[hosts] $($Config.DownAlias) -> $DownIp"
} elseif ($Config.UseSeparateUpDown -and -not $DownIp) {
    Write-Warning "UseSeparateUpDown is enabled but no DownIp was provided; only the uplink alias was updated."
}

# ---- Flush DNS ---------------------------------------------------------------
try {
    ipconfig /flushdns | Out-Null
    Write-Host "[dns] resolver cache flushed."
} catch {
    Write-Warning "Could not flush DNS automatically: $($_.Exception.Message)"
}

Write-Host "[done] hosts updated. Reconnect your node to use the new IP."
