# Troubleshooting

## The pick ran, but the connection still seems unchanged

- **Reconnect the node.** Existing long-lived connections may continue using the old
  edge IP until a new connection is opened.
- Check the live hosts block directly:
  ```powershell
  Get-Content C:\Windows\System32\drivers\etc\hosts | Select-String 'cf-up|cf-down'
  ```
- Check alias resolution:
  ```powershell
  [System.Net.Dns]::GetHostAddresses("cf-up.example.local")
  ```
- Then verify the exit IP through an explicit proxy:
  ```powershell
  curl.exe -4 -x http://127.0.0.1:10809 https://api.ipify.org
  ```

## Bare curl says `(35) Recv failure: Connection was aborted`

Example:

```powershell
curl.exe -4 https://api.ipify.org
curl: (35) Recv failure: Connection was aborted
```

Do **not** treat that as a final failure verdict by itself.

On some Windows + v2rayN setups, bare `curl.exe` does not behave the same way as an
explicit proxy test.

Try this first (replace `10809` if your local HTTP proxy port differs):

```powershell
curl.exe -4 -x http://127.0.0.1:10809 https://api.ipify.org
```

If the explicit-proxy form returns the expected exit IP, the node path is working.

## `status.ps1` shows one IP, but live hosts shows another

That can happen legitimately when a scheduled task runs between your checks.

When investigating, trust this order:

1. live hosts block
2. `output/history.csv`
3. `Get-ScheduledTaskInfo`
4. `status.ps1` snapshot

## CloudflareST times out after ~45 seconds

In real deployments, CloudflareST may already have produced a useful `result.csv` but
fail to exit quickly.

Current scripts support a safety timeout for this case:

- the process can be stopped after the configured timeout
- if `result.csv` was already written, the script can still parse and continue
- if no CSV was written yet, the run can still fail

So timeout-kill does **not always mean failure**, but it is not a guaranteed rescue
path either.

## CloudflareST produced garbled Chinese output in PowerShell

PowerShell 5.1 console mojibake is annoying, but it does **not automatically mean the
measurement is invalid**.

Check these instead:

- `result.csv`
- the managed hosts block
- `output/history.csv`

Those are more trustworthy than console glyph rendering.

## `wsasend: An established connection was aborted by the software in your host machine`

If you see this in Xray logs, do **not** immediately conclude that the remote node is
broken.

When this warning appears together with:

- successful real traffic to normal destinations
- normal delay / ping values
- a correct explicit-proxy exit IP check

it is often just a local client / browser / app-side disconnect, not an upstream node
failure.

## `Administrator rights are required`

`update_hosts.ps1` and the install scripts must run from an **elevated** PowerShell.

Re-run PowerShell as Administrator.

## `result.csv` is empty or no usable IPs were picked

- thresholds may be too strict
- candidate pool may be poor
- your test URL may be unsuitable for the chosen probe mode

Try:

- raising `LatencyMaxMs`
- lowering `SpeedMinMBps`
- testing a smaller known-good candidate pool first

## I want to undo everything

See [security-and-rollback.md](security-and-rollback.md).
