# Architecture

## Problem

For a Cloudflare-fronted Xray node, the IP you dial and the identity you present
(TLS SNI + HTTP Host) are logically independent.

- the **dialed IP** can change often
- the **real hostname / SNI / Host** should stay fixed

The naive workflow is to keep editing the node's `address` to the latest “best IP”.
In v2rayN that usually means re-importing or re-editing the node over and over.
That is fragile and easy to get wrong.

## Solution: hosts-file indirection

```text
Xray outbound address      Windows hosts                      Cloudflare edge
cf-up.example.local   ->   cf-up.example.local -> A.B.C.D ->  A.B.C.D:443
SNI / Host            ->   up.example.com                    real routed hostname
```

The node config stays stable:

- `address = cf-up.example.local`
- `serverName = up.example.com`
- `Host = up.example.com`

The toolkit only rewrites the managed `hosts` block so the local alias points to
a different Cloudflare IP.

## Split XHTTP topology: optimize only the uplink

This repo now treats the following as the primary design:

```text
uplink   : Cloudflare best-IP optimized
           address    = cf-up.example.local
           serverName = up.example.com

downlink : fixed real host / CDN
           address    = down.example.com
           serverName = down.example.com
```

That means:

- the **uplink** alias is automatically remapped to the chosen Cloudflare IP
- the **downlink** should usually remain on its own fixed host
- the downlink should **not** blindly follow the Cloudflare best IP unless you are
  intentionally managing a separate compatible path

## Why this is different from old JSON-rewrite bundles

Older bundles often re-generated:

- `current-client.json`
- `current-vless-*.txt`

But that did not guarantee the running client had actually switched.

Hosts-mode is different:

- import your custom JSON once
- keep the node config stable
- update only the alias mapping in `hosts`
- new connections automatically dial the new edge IP

So this repo's automation is about **runtime address indirection**, not repeated
JSON regeneration.

## Data flow

1. `candidates.txt` provides the current probe pool.
2. `run_once.ps1` runs CloudflareST.
3. `result.csv` is parsed and ranked by:
   1. lowest packet loss
   2. then lowest latency
   3. then highest speed when a speed column is present
4. the winning uplink IP is appended to `output/history.csv`
5. `update_hosts.ps1` rewrites only the managed hosts block
6. reconnect if you need immediate pickup for already-open long-lived connections

## Why history matters

`status.ps1` is a useful read-only snapshot, but real-world timing can look like this:

- manual run picks IP A at 01:58
- scheduled task runs at 02:00
- live hosts is already updated to IP B at 02:01

So when investigating state drift, use:

- live hosts block
- `output/history.csv`
- `Get-ScheduledTaskInfo`

instead of relying on a single snapshot alone.

## Scheduled-task defaults

For desktop use, the safer default is:

- daily pick: every **24 hours**
- weekly refresh: **once per week**

This reduces user-visible disturbance while still keeping the candidate pool fresh.
