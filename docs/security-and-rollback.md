# Security & Rollback

## What this toolkit touches

| Resource              | How it is changed | Safety measure |
|-----------------------|-------------------|----------------|
| Windows `hosts`       | Only the lines between the BEGIN/END markers are rewritten | Timestamped `hosts.bak-*` written before every change; ASCII, no BOM |
| DNS resolver cache    | `ipconfig /flushdns` after each hosts edit | Read-only side effect, reversible by nature |
| Task Scheduler        | Registers/removes two clearly named tasks | Names are fixed and unique; `uninstall_*` removes them |
| `candidates.txt`      | Replaced by the weekly refresh **only** if enough good IPs were found | Previous list backed up to `candidates.txt.bak-*`; conservative `MinKeep` gate |

It does **not** touch the v2rayN database, your node config, the registry, or any
file outside the repo and the hosts file.

## Privilege model

- Interactive hosts updates require an **elevated** PowerShell (the script checks and
  refuses otherwise).
- Scheduled tasks run as the `SYSTEM` principal with highest run level so the
  unattended pick can edit hosts and flush DNS without UAC prompts.

## Secrets

Nothing in this repo contains real domains, IPs, UUIDs, paths, or config. Your real
values live only in:

- `scripts\config.ps1` (gitignored),
- `candidates.txt` / `result.csv` / `hosts.bak-*` (gitignored),
- your v2rayN custom node (built from the template, never committed).

Keep it that way: never commit `config.ps1` or any `*.bak*` / `result.csv`.

## Rollback

### Remove the scheduled tasks
```powershell
# elevated
powershell -ExecutionPolicy Bypass -File scripts\uninstall_task.ps1
powershell -ExecutionPolicy Bypass -File scripts\uninstall_weekly_task.ps1
```

### Revert the hosts file
Option A — delete just the managed block: open
`%SystemRoot%\System32\drivers\etc\hosts` (as admin) and remove everything from the
`# BEGIN v2rayn-cf-bestip-hosts ...` line through the `# END v2rayn-cf-bestip-hosts`
line.

Option B — restore a backup: copy the newest `hosts.bak-*` (next to the hosts file)
back over `hosts`, then flush DNS:
```powershell
# elevated, replace the timestamp with your newest backup
$h = "$env:SystemRoot\System32\drivers\etc\hosts"
Copy-Item "$h.bak-YYYYMMDD-HHMMSS" $h -Force
ipconfig /flushdns
```

### Verify it's clean
```powershell
powershell -ExecutionPolicy Bypass -File scripts\status.ps1
```
The managed-block section should report "no managed block found" once reverted.

## Full uninstall

1. Run both `uninstall_*` scripts.
2. Revert the hosts file (above).
3. Delete the repo folder. Optionally remove the custom node from v2rayN.
