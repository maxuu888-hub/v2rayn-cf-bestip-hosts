# Shadowrocket and other clients: limitations

This toolkit is built around **v2rayN / Xray on Windows**, where you can paste a full
Xray JSON config (custom config node) and let the OS `hosts` file steer the dial IP.
That model does not transfer cleanly to every client.

## Shadowrocket (iOS)

- **No full Xray JSON import.** Shadowrocket uses its own per-node UI/URI format. You
  cannot paste the `v2rayn-custom-xhttp-template.json` and get the same behavior,
  including the `downloadSettings` split-path feature.
- **No user-writable hosts file.** iOS does not give apps a Windows-style `hosts`
  file you can script. Shadowrocket has its own limited "host" override under a
  config profile, but it is not driven by an external speed-test tool the way this
  toolkit drives Windows `hosts`.
- **Practical approach on iOS:** rely on Cloudflare's own anycast routing, or use a
  client that lets you set the node address directly and change it manually when
  needed. The automatic best-IP rotation here is Windows-specific.

## XHTTP `downloadSettings`

Client support for the XHTTP `downloadSettings` (split upload/download path) varies by
Xray-core version. If your core does not support it, remove that block from the
template — the node still works using a single path.

## General client caveats

- **What is optimized:** only the **Cloudflare entry IP** you dial. Your exit
  IP / geo-location is decided by your server and does not change.
- **Long-lived connections** keep the old edge until you reconnect.
- **Reality** nodes cannot be fronted by Cloudflare's orange-cloud proxy, so the
  best-IP-via-hosts idea does not apply to Reality at all — there is no Cloudflare
  edge in front to choose between.
- **Admin / platform access** to edit a hosts file is required; this is available on
  Windows (and similarly `/etc/hosts` on desktop Linux/macOS) but not on locked-down
  mobile platforms.
