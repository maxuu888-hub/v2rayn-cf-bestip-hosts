# Troubleshooting

## The pick runs but my connection is still slow / unchanged

- **Reconnect the node.** Existing connections keep using the old edge IP. Disconnect
  and reconnect in v2rayN so Xray re-resolves the alias.
- Confirm the alias actually resolves to the new IP:
  ```powershell
  Resolve-DnsName cf-up.example.local
  # or
  ping cf-up.example.local
  ```
- Run `scripts\status.ps1` and check the managed hosts block shows the expected IP.

## "Administrator rights are required"

`update_hosts.ps1` and the `install_*` scripts must run from an **elevated**
PowerShell. Right-click PowerShell -> "Run as administrator", then re-run.

## CloudflareST produces no usable IPs / empty result.csv

- Your thresholds may be too strict. In `config.ps1`, raise `LatencyMaxMs` and/or
  lower `SpeedMinMBps` (set it to `0` to disable the speed filter).
- If the speed filter is on, `TestUrl` must point at a real, reasonably large file
  served through *your* Cloudflare domain. A 404 or tiny file makes every IP fail
  the speed gate.
- Try a smaller candidate pool first to confirm the binary runs at all.

## Column parsing picked the wrong field

`run_once.ps1` matches CSV columns by keyword (English and Chinese) and falls back to
the first column for the IP. If your CloudflareST build uses unusual headers, the
parse line it prints (`[parse] columns -> ...`) tells you what it chose. Open
`result.csv`, check the header row, and if needed adjust the keyword lists in
`run_once.ps1` (function `Find-Column`).

## PowerShell script encoding / garbled characters

All scripts use ASCII-only comments specifically to avoid Windows PowerShell 5.1
mangling non-ASCII text. If you edit a script, save it as ANSI/ASCII or UTF-8
**without BOM**, and keep comments ASCII to stay safe on 5.1.

## Execution policy blocks the script

Run with an explicit bypass for that process only:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\run_once.ps1
```

## Scheduled task shows a non-zero last result

Open Task Scheduler -> find `v2rayn-cf-bestip-hosts - pick best IP` -> History, or run
`scripts\status.ps1`. Common causes: CloudflareST path wrong in `config.ps1`, no
candidates file, or thresholds too strict. The task runs as SYSTEM, so paths must be
absolute/resolvable for that account (the config derives them from the repo root,
which is fine as long as the repo location is stable).

## I want to undo everything

See [security-and-rollback.md](security-and-rollback.md).
