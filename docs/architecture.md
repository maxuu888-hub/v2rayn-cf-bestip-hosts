# Architecture

## Problem

For a Cloudflare-fronted Xray node, the IP you dial (the Cloudflare edge) and the
identity you present (TLS SNI + HTTP Host) are logically independent. Cloudflare
has thousands of anycast IPs and their quality varies a lot by ISP, time of day,
and route. You want to keep dialing the *currently fastest* edge IP while keeping
the SNI/Host fixed to your domain.

The naive fix is to keep editing the node's `address` to the fastest IP. In v2rayN
that means editing the SQLite DB or re-importing the node. Both are error-prone and
annoying to automate.

## Solution: a hosts-file indirection layer

```
   Xray outbound                 Windows hosts                Cloudflare edge
   address=cf-up.example.local   cf-up.example.local -> A.B.C.D   A.B.C.D:443
   SNI/Host=up.example.com  ---------------------------------------> (your domain
                                                                      via SNI/Host)
```

- The Xray config references a **stable local alias** (`cf-up.example.local`) as the
  dial address. This is written once and never changes.
- The Windows **hosts** file maps that alias to an IP. This is the *only* thing the
  toolkit rewrites.
- TLS `serverName` and the HTTP `Host` header stay pinned to the real domain, so
  Cloudflare routes the request correctly and the TLS handshake matches your cert.

Because Xray resolves the alias through the OS resolver (which reads hosts), pointing
the alias at a new IP and flushing DNS is enough to change which edge you dial — with
no change to the node config and no v2rayN DB access.

## Components

| File                            | Role |
|---------------------------------|------|
| `config.example.ps1`            | Single source of paths, aliases, thresholds. Copied to `config.ps1`. |
| `run_once.ps1`                  | Drives CloudflareST, parses CSV, ranks, calls `update_hosts.ps1`. |
| `update_hosts.ps1`              | The only writer of the hosts file. Backed up, marker-scoped, ASCII. |
| `weekly_refresh_candidates.ps1` | Periodically rebuilds the candidate pool with a wide scan. |
| `install_*` / `uninstall_*`     | Manage Scheduled Tasks (run as SYSTEM). |
| `status.ps1`                    | Read-only state report. |

## Data flow

1. **Candidate pool** (`candidates.txt`) — IPs/CIDRs to probe. Refreshed weekly.
2. **Speed test** — `CloudflareST.exe -f candidates.txt -o result.csv` plus thresholds.
3. **Parse & rank** — `result.csv` rows are normalized; the winner is chosen by:
   1. lowest packet loss (0 preferred),
   2. then lowest latency,
   3. then highest download speed.
4. **Apply** — `update_hosts.ps1` rewrites the marked block to map the aliases to the
   winning IP, then `ipconfig /flushdns`.
5. **Reconnect** — Xray must open a new connection to use the new edge.

## Why a marked block

`update_hosts.ps1` only ever reads/writes the lines between
`# BEGIN v2rayn-cf-bestip-hosts ...` and `# END v2rayn-cf-bestip-hosts`. Everything
else in `hosts` is preserved verbatim, and a timestamped `hosts.bak-*` is written
before each change. This makes the edit auditable and trivially reversible.

## Why SYSTEM for the scheduled tasks

Editing `hosts` and flushing DNS need elevation. Running the task as the `SYSTEM`
principal with highest privileges lets the periodic pick run unattended without UAC
prompts. The interactive scripts instead just require an elevated PowerShell.
