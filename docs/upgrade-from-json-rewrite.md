# Upgrade from JSON-rewrite bundles

This note explains the difference between older “rewrite the client JSON again and
again” bundles and the newer hosts-mode design in this repo.

## Old pattern: re-generate client artifacts

A common older bundle did something like:

- run CloudflareSpeedTest
- pick a best IP
- rewrite `current-client.json`
- rewrite `current-vless-*.txt`

That can be useful, but it is only **semi-automatic**.

Why?

Because generating a new JSON file does **not automatically prove** that the running
v2rayN / Xray process has switched to it.

## Current pattern: stable config + mutable hosts alias

This repo does something different:

- your v2rayN custom JSON is imported **once**
- the outbound `address` is a stable local alias such as `cf-up.example.local`
- scheduled automation updates only the Windows `hosts` file mapping for that alias

That means the running client does not need repeated re-import just because the best
Cloudflare entry IP changed.

## Why this matters more in split XHTTP setups

In a real XHTTP split deployment:

- the **uplink** may benefit from Cloudflare best-IP optimization
- the **downlink** may stay pinned to its own real host / CDN (for example CloudFront)

So tying every direction to the same “best IP” is not only unnecessary, it can be
wrong.

## Practical migration rule

If you are moving from an older JSON-rewrite bundle to this repo:

1. keep the uplink `address` on a local alias like `cf-up.example.local`
2. keep the uplink SNI / Host on the real domain
3. in split mode, keep the downlink on its real fixed host unless you intentionally
   manage a second alias yourself
4. import the custom JSON once
5. let the scheduled tasks maintain only the hosts mapping
