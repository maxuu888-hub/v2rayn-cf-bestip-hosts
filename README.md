# v2rayn-cf-bestip-hosts

## 一句话介绍 🚀

还在为「优选 IP」手动改 v2rayN、删了又重新导入、改完还得记得改回来吗？😮‍💨
这个小工具帮你把这件烦心事**全自动化**了：

- 🏎️ 用 [CloudflareSpeedTest](https://github.com/XIU2/CloudflareSpeedTest) 自动跑一遍，挑出当下**最快的 Cloudflare 入口 IP**。
- 🧩 给 **v2rayN / Xray** 节点填一个**固定的本地别名**（例如 `cf-up.example.local`），从此节点配置**写一次就不用再动**。
- 🪟 真正变化的只有 **Windows hosts** 里那一行别名映射，工具自动维护，**绝不碰 v2rayN 的数据库**。
- 🙅 不用再**手动反复导入节点**，SNI / Host 保持不变，TLS 与 CDN 路由稳稳的。
- ⏰ 支持**定时任务自动切换**最优 IP，躺着就能一直用上快线路。
- 🛟 每次更新 hosts 都会**自动带时间戳备份**，只改 `# BEGIN` / `# END` 标记之间的内容，**随时安全回滚**，不慌。

> 如果它帮你省下了时间、也保住了头发 🧑‍🦲➡️🧑‍🦱，欢迎点个 ⭐ Star 支持一下，让更多人少走弯路！

---

Automatically pick the **best Cloudflare entry IP** for v2rayN / Xray on Windows,
without ever touching the v2rayN database and without re-importing your node by hand.

## The core idea (read this first)

A typical CDN-fronted Xray node (VLESS/VMess over WebSocket, gRPC, or XHTTP through
Cloudflare) has three independent pieces:

| Piece            | What it is                                   | Should it change often? |
|------------------|----------------------------------------------|--------------------------|
| **address**      | The IP/host Xray dials (the Cloudflare edge) | Yes — pick the fastest   |
| **SNI / Host**   | TLS SNI and HTTP `Host` header (your domain) | No — must stay constant  |
| **path / UUID**  | XHTTP path, user id, etc.                    | No                       |

Most "best IP" guides tell you to keep editing the node's `address` field to the
fastest Cloudflare IP. In v2rayN that means editing the SQLite DB or deleting and
re-importing the node every time the best IP changes. That is fragile and easy to
get wrong.

**This toolkit decouples the address from the SNI/Host using the Windows `hosts`
file.** You point Xray's `address` at a *stable local alias* such as
`cf-up.example.local`, and the toolkit keeps a `hosts` entry mapping that alias to
whatever Cloudflare IP is currently fastest:

```
# Xray custom JSON (never changes):
"address": "cf-up.example.local",   "serverName": "up.example.com"

# Windows hosts (the only thing that changes, managed automatically):
104.16.0.1   cf-up.example.local
```

So:

- **No v2rayN DB hacking.** The node config is written once and never edited again.
- **No manual re-import.** Only the `hosts` file changes, between clearly marked
  `# BEGIN`/`# END` markers, with an automatic timestamped backup each run.
- **SNI/Host stay fixed**, so TLS and CDN routing keep working while only the entry
  IP is optimized.

The speed test itself is done by [XIU2/CloudflareSpeedTest](https://github.com/XIU2/CloudflareSpeedTest)
(`CloudflareST.exe`), which this toolkit drives and parses.

## What it does, concretely

1. `run_once.ps1` runs `CloudflareST.exe` against your candidate IP list.
2. It parses the result CSV (English **or** Chinese headers, with a column fallback)
   and chooses the best IP: zero packet loss first, then lowest latency, then
   highest download speed.
3. `update_hosts.ps1` (Admin) backs up `hosts`, rewrites only the marked block to
   map `cf-up.example.local` / `cf-down.example.local` to the chosen IP(s), then
   flushes the DNS cache.
4. Optional scheduled tasks re-run the pick on a timer and refresh the candidate
   pool weekly.

## Quick start

```powershell
# 1. Get CloudflareSpeedTest and put CloudflareST.exe somewhere stable.
#    https://github.com/XIU2/CloudflareSpeedTest/releases

# 2. Copy the example config and edit it for your setup.
Copy-Item scripts\config.example.ps1 scripts\config.ps1
notepad scripts\config.ps1

# 3. Copy the candidate template and (optionally) refresh it.
Copy-Item templates\candidates.example.txt candidates.txt

# 4. Build your Xray custom JSON from the template, using the LOCAL ALIASES
#    cf-up.example.local / cf-down.example.local as the address fields, and
#    paste it into v2rayN as a custom config node (one time only).

# 5. Run once (an elevated PowerShell is required for the hosts update step).
powershell -ExecutionPolicy Bypass -File scripts\run_once.ps1

# 6. (Optional) install scheduled tasks.
powershell -ExecutionPolicy Bypass -File scripts\install_all_tasks.ps1
```

Then in v2rayN: connect to your custom node as usual. To pick up a freshly chosen
IP on an existing connection, reconnect (see Limitations).

## Repo layout

```
scripts/
  config.example.ps1            # copy to config.ps1 and edit
  run_once.ps1                  # speed test -> pick best IP -> update hosts
  update_hosts.ps1             # safe, marked, backed-up hosts update (Admin)
  weekly_refresh_candidates.ps1 # refresh candidate pool (full scan)
  install_task.ps1              # scheduled task: periodic best-IP pick
  install_weekly_task.ps1       # scheduled task: weekly candidate refresh
  install_all_tasks.ps1         # install both
  uninstall_task.ps1            # remove the best-IP task
  uninstall_weekly_task.ps1     # remove the weekly task
  status.ps1                    # show task status + current hosts block + last result
templates/
  candidates.example.txt        # example Cloudflare IP/CIDR candidate list
  v2rayn-custom-xhttp-template.json  # Xray custom JSON using local aliases
docs/
  architecture.md
  troubleshooting.md
  security-and-rollback.md
  shadowrocket-limitations.md
```

## Limitations (please read)

- This optimizes the **Cloudflare entry IP** you connect to. It does **not** change
  your final exit IP or geo-location — that is decided by your node/server.
- Already-established long-lived connections keep using the old IP; **reconnect** to
  use a newly chosen one.
- **Admin rights are required** to edit `hosts` and flush DNS.
- **Shadowrocket cannot import a full Xray JSON config**, so the local-alias trick
  does not transfer there. See [docs/shadowrocket-limitations.md](docs/shadowrocket-limitations.md).
- **XHTTP `downloadSettings` client support varies** by core version.
- **Reality nodes cannot be fronted by Cloudflare's orange-cloud proxy**, so this
  best-IP approach does not apply to Reality.

See [docs/troubleshooting.md](docs/troubleshooting.md) and
[docs/security-and-rollback.md](docs/security-and-rollback.md) for more.

## License

MIT — see [LICENSE](LICENSE).
