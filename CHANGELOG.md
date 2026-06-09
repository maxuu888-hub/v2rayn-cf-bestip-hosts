# Changelog

## v0.2.0

### Chinese
- 明确仓库主目标场景：**XHTTP 上下行分离**。
- 修正默认思路：**只自动优选上行 Cloudflare 入口**；下行应默认保持真实固定 host / CDN，而不是跟着 Cloudflare best IP 一起改。
- `run_once.ps1` 现在只把 **uplink best IP** 交给 `update_hosts.ps1`。
- `update_hosts.ps1` 不再在未显式提供 `DownIp` 时默认把 down alias 绑定到与 uplink 相同的 IP。
- 新增 `HistoryPath` / `output/history.csv`，便于结合 live hosts 与计划任务时间排查“为什么 IP 又变了”。
- `status.ps1` 新增 history 展示。
- 新增 CloudflareST 安全超时参数 `QuickTimeoutSec`。若 `result.csv` 已经写出，超时后仍可继续解析；若 CSV 尚未落盘，该轮仍可能失败。
- 默认日常任务周期从 **6h 调整为 24h**，更适合桌面用户。
- README / docs 新增：
  - 验收口径（显式代理 `curl.exe -4 -x ...`）
  - `(35) Recv failure` 误判说明
  - `status.ps1` 只是快照的说明
  - PowerShell 中文乱码无害说明
  - Xray `wsasend ... aborted` 良性场景说明
  - 从旧 JSON-rewrite 半自动方案迁移到 hosts-mode 的差异说明

### English
- Clarified the primary target scenario: **split XHTTP uplink/downlink**.
- Fixed the default model: **only the uplink Cloudflare entry IP is auto-optimized**; the downlink should usually remain on its real fixed host / CDN.
- `run_once.ps1` now updates hosts using the **uplink best IP only**.
- `update_hosts.ps1` no longer binds the down alias to the uplink IP unless `DownIp` is explicitly provided.
- Added `HistoryPath` / `output/history.csv` so live hosts, task timing, and best-IP changes can be correlated.
- `status.ps1` now shows recent history.
- Added `QuickTimeoutSec` as a CloudflareST safety timeout. If `result.csv` is already written, the run can still continue after timeout; if not, that run may still fail.
- Changed the default periodic task from **6h to 24h** for desktop users.
- Expanded docs with:
  - explicit-proxy verification
  - `(35) Recv failure` false-alarm guidance
  - snapshot-vs-live-state guidance
  - harmless PowerShell mojibake guidance
  - benign `wsasend ... aborted` guidance
  - upgrade notes from old JSON-rewrite bundles to hosts-mode
