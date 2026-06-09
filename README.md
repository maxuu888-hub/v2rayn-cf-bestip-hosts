# v2rayn-cf-bestip-hosts

Automatically pick the **best Cloudflare entry IP** for v2rayN / Xray on Windows,
without touching the v2rayN database and without re-importing your node every time.

## 一句话介绍

这个仓库解决的是一个很具体、也很常见的桌面场景：

- **上行**：Xray / XHTTP 通过 Cloudflare 橙云入口，适合做 **best IP 自动优选**
- **下行**：保持真实固定域名 / CDN（例如 CloudFront），**不跟着 Cloudflare best IP 一起改**
- **客户端**：v2rayN 只在第一次导入自定义 JSON；后续自动化只改 Windows `hosts`

核心目标不是“反复生成新节点”，而是：

- 节点配置写一次
- `address` 固定为本地 alias（如 `cf-up.example.local`）
- 后台只更新 alias -> best IP 的 hosts 映射
- 新连接自然吃到新的 Cloudflare 入口 IP

## What this toolkit actually automates

This repo is the **hosts-mode** approach.

It keeps the Xray node config stable and only rewrites the managed block in the
Windows `hosts` file.

```text
Xray outbound address:  cf-up.example.local
TLS serverName / Host:  up.example.com
Windows hosts:          198.41.x.x  cf-up.example.local
```

So:

- **No v2rayN DB hacking**
- **No repeated node import**
- **SNI / Host stay fixed**
- **Only the dialed Cloudflare edge IP changes**

## Important boundary: what it does NOT do

This repo does **not** hot-reload v2rayN itself.

That means:

- **new connections** will use the newly chosen IP
- **already-established long-lived connections** may keep using the old IP
- if you want immediate pickup, **reconnect the node**

So the honest description is:

- **fully automatic hosts maintenance**
- **not** a magical hot-reload of every already-open connection

## v6 JSON-rewrite vs current hosts-mode

Older “best IP” bundles often did this:

- re-run CloudflareSpeedTest
- rewrite `current-client.json`
- rewrite `current-vless-*.txt`
- expect the user or client to somehow pick up the change

That is only **semi-automatic**.

This repo is the newer **hosts-mode** design:

- import the custom JSON **once**
- keep `address` stable as a local alias
- let scheduled automation update only the Windows `hosts` mapping

See [docs/upgrade-from-json-rewrite.md](docs/upgrade-from-json-rewrite.md).

## Target scenario: XHTTP split uplink / downlink

The most important scenario for this repo is:

```text
uplink   -> Cloudflare domain / best IP optimized
           up.example.com  +  cf-up.example.local -> best Cloudflare IP

downlink -> fixed real host / CDN
           down.example.com (for example CloudFront)
```

**Do not assume the downlink should follow the Cloudflare best IP.**

In many real XHTTP split deployments, only the uplink is Cloudflare-optimized.
The downlink should stay pinned to its own real fixed host.

## Quick start

```powershell
# 1. Get CloudflareSpeedTest and put CloudflareST.exe in the repo root.
#    https://github.com/XIU2/CloudflareSpeedTest/releases

# 2. Copy the example config and edit it for your setup.
Copy-Item scripts\config.example.ps1 scripts\config.ps1
notepad scripts\config.ps1

# 3. Copy the candidate template.
Copy-Item templates\candidates.example.txt candidates.txt

# 4. Build your Xray custom JSON from the template and import it into v2rayN ONCE.
#    For the common split design:
#    - uplink address = cf-up.example.local
#    - downlink address = your real fixed down host (for example down.example.com)

# 5. Run once (Admin PowerShell required for hosts update).
powershell -ExecutionPolicy Bypass -File scripts\run_once.ps1

# 6. Optional: install scheduled tasks.
powershell -ExecutionPolicy Bypass -File scripts\install_all_tasks.ps1
```

Recommended desktop schedule:

- daily pick: **every 24 hours**
- weekly candidate refresh: **Sunday 04:00**

## Verification / acceptance

Do not rely on a single bare `curl.exe` test.

The practical verification order is:

1. `powershell -ExecutionPolicy Bypass -File scripts\status.ps1`
2. inspect the live hosts block
3. confirm alias resolution with PowerShell
4. test the exit IP through an **explicit proxy**

Recommended exit-IP check (replace `10809` if your local **HTTP** proxy port differs):

```powershell
curl.exe -4 -x http://127.0.0.1:10809 https://api.ipify.org
```

If that returns your node's real exit IP, the chain is working.

Important: on some Windows setups, this may fail even when system proxy is enabled:

```powershell
curl.exe -4 https://api.ipify.org
curl: (35) Recv failure: Connection was aborted
```

That **does not automatically mean the node is broken**.
Use the explicit HTTP-proxy form first, for example:

```powershell
curl.exe -4 -x http://127.0.0.1:10809 https://api.ipify.org
```

See [docs/verification.md](docs/verification.md).

## Repo layout

```text
scripts/
  config.example.ps1
  run_once.ps1
  update_hosts.ps1
  weekly_refresh_candidates.ps1
  install_task.ps1
  install_weekly_task.ps1
  install_all_tasks.ps1
  uninstall_task.ps1
  uninstall_weekly_task.ps1
  status.ps1

templates/
  candidates.example.txt
  v2rayn-custom-xhttp-template.json

docs/
  architecture.md
  verification.md
  troubleshooting.md
  security-and-rollback.md
  shadowrocket-limitations.md
  upgrade-from-json-rewrite.md
```

## Troubleshooting highlights

A few real-world pitfalls worth calling out explicitly:

- **CloudflareST timeout is not always fatal.** If `result.csv` has already been
  written, a timeout-kill + later parse may still produce a valid best IP. If no
  CSV was written yet, the run can still fail.
- **PowerShell mojibake / garbled Chinese output does not automatically invalidate
  the result.** Check `result.csv`, the hosts block, and history instead.
- **`status.ps1` is a snapshot, not the only source of truth.** If it disagrees with
  live hosts, check `output/history.csv` and `Get-ScheduledTaskInfo` as well.
- **Xray `wsasend ... aborted` is not automatically a node failure** if real traffic is
  still flowing and latency is normal.

See [docs/troubleshooting.md](docs/troubleshooting.md).

## Limitations

- This optimizes the **Cloudflare entry IP** you dial. It does **not** change your
  final exit IP or geo-location.
- **Admin rights are required** to edit `hosts` and flush DNS.
- **Shadowrocket cannot import a full Xray JSON config**, so the local-alias trick is
  not portable there. See [docs/shadowrocket-limitations.md](docs/shadowrocket-limitations.md).
- **XHTTP `downloadSettings` client support varies** by core version.
- **Reality cannot be fronted by Cloudflare orange-cloud**, so this approach does not
  apply to Reality nodes.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT — see [LICENSE](LICENSE).
