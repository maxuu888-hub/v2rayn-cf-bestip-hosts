# Verification

Use this checklist to verify that the toolkit is really working on a live Windows +
v2rayN setup.

## 1. Check the status snapshot

```powershell
powershell -ExecutionPolicy Bypass -File scripts\status.ps1
```

This gives you:

- scheduled-task state
- managed hosts block
- last result.csv summary
- recent history rows (if available)

## 2. Check the live hosts block

Do not rely only on memory or screenshots. Read the actual current file:

```powershell
Get-Content C:\Windows\System32\drivers\etc\hosts | Select-String 'cf-up|cf-down'
```

## 3. Check alias resolution

Prefer PowerShell / .NET resolution here.

```powershell
[System.Net.Dns]::GetHostAddresses("cf-up.example.local")
```

This should match the current live hosts mapping.

## 4. Verify the real exit IP with an explicit proxy

Recommended check (replace `10809` if your local HTTP proxy port differs):

```powershell
curl.exe -4 -x http://127.0.0.1:10809 https://api.ipify.org
```

Replace `10809` if your local HTTP proxy port differs.

If this returns your node's actual exit IP, the chain is working.

## 5. Do NOT over-trust bare curl

This may fail even when the node is fine:

```powershell
curl.exe -4 https://api.ipify.org
curl: (35) Recv failure: Connection was aborted
```

If that happens:

- do **not** immediately conclude that the node is broken
- retry with the explicit HTTP-proxy form, for example:
  ```powershell
  curl.exe -4 -x http://127.0.0.1:10809 https://api.ipify.org
  ```
- confirm real traffic is still flowing in v2rayN / Xray logs

## 6. If status, hosts, and runtime disagree

Treat these as the three primary sources of truth:

1. live hosts block
2. `output/history.csv`
3. `Get-ScheduledTaskInfo -TaskName ...`

Example investigation commands:

```powershell
Get-Content .\output\history.csv
Get-ScheduledTaskInfo -TaskName 'v2rayn-cf-bestip-hosts - pick best IP'
Get-Content C:\Windows\System32\drivers\etc\hosts | Select-String 'cf-up|cf-down'
```

That combination explains most “why did the IP change again?” situations.
