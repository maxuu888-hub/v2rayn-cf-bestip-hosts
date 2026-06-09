# config.example.ps1
# ASCII-only comments to avoid PowerShell 5.1 encoding problems.
#
# HOW TO USE:
#   1. Copy this file to scripts\config.ps1
#   2. Edit the values below for your environment.
#   3. Never commit scripts\config.ps1 (it is in .gitignore).
#
# This file is dot-sourced by the other scripts. It must only DEFINE the
# $Config hashtable; it must not perform any side effects.

# Resolve the repo root from this script's own location, so the toolkit works
# no matter where the repo is cloned. $PSScriptRoot is the scripts\ folder.
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$RepoRoot  = Split-Path -Parent $ScriptDir

$Config = @{

    # ---- Working directory ----------------------------------------------
    # Where candidates / results / backups live. Defaults to the repo root.
    WorkDir = $RepoRoot

    # ---- CloudflareSpeedTest --------------------------------------------
    # Full path to CloudflareST.exe (XIU2/CloudflareSpeedTest).
    # Download: https://github.com/XIU2/CloudflareSpeedTest/releases
    CloudflareSTExe = Join-Path $RepoRoot 'CloudflareST.exe'

    # Candidate IP / CIDR list fed to CloudflareST (the -f input file).
    CandidatesPath  = Join-Path $RepoRoot 'candidates.txt'

    # CSV result file written by CloudflareST (the -o output file).
    ResultPath      = Join-Path $RepoRoot 'result.csv'

    # Append-only history of chosen best IPs. Useful when status.ps1, live hosts,
    # and scheduled-task timing need to be correlated.
    HistoryPath     = Join-Path $RepoRoot 'output\history.csv'

    # ---- Stable local aliases -------------------------------------------
    # These are the addresses you put in your Xray custom JSON. In the common
    # split-XHTTP design, only UpAlias is used by default; the downlink stays on
    # its real fixed host/CDN domain unless you intentionally manage DownAlias.
    # Keep aliases as .local or any name you will never use for real DNS.
    UpAlias   = 'cf-up.example.local'
    DownAlias = 'cf-down.example.local'

    # In the common XHTTP split design, only the uplink alias should be managed
    # here and the downlink should stay on its real fixed host/CDN domain.
    # Enable a separate down alias only if you intentionally manage that path.
    UseSeparateUpDown = $false

    # ---- Windows hosts file ---------------------------------------------
    HostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'

    # Marker tags. update_hosts.ps1 only ever touches lines between these.
    BeginMarker = '# BEGIN v2rayn-cf-bestip-hosts (managed - do not edit)'
    EndMarker   = '# END v2rayn-cf-bestip-hosts'

    # ---- Speed-test parameters ------------------------------------------
    # TestUrl: a download-test URL behind your own Cloudflare domain.
    # Use a real file on YOUR domain in config.ps1; placeholder shown here.
    TestUrl = 'https://down.example.com/your-200mb-test-file'

    # Latency timeout in milliseconds: candidates slower than this are dropped.
    LatencyMaxMs = 300

    # Minimum acceptable download speed in MB/s (0 disables the speed filter).
    SpeedMinMBps = 5

    # Connection / handshake timeout in seconds for each probe.
    TimeoutSec = 10

    # How many top results to consider when picking (1 = strictly the best).
    TopN = 1

    # Extra raw args passed straight to CloudflareST.exe for run_once.
    # Example: '-n 200 -t 4 -dn 10'
    ExtraArgsQuick = '-dd'

    # Optional safety timeout for run_once.ps1. If CloudflareST has already
    # produced result.csv but fails to exit cleanly, the script will stop the
    # process after this many seconds and still parse the partial result.
    QuickTimeoutSec = 45

    # Extra raw args for the weekly full-scan refresh.
    ExtraArgsWeekly = '-n 500 -t 4 -dn 20'
}

# Expose $Config to the dot-sourcing caller.
$Config
