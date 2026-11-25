# urnetwork-termux

Sources for building the URnetwork Android/Termux CLI tools:

- **provider** — shares this device's internet connection (mining/egress).
- **proxy-socks** — local SOCKS5 client into the URnetwork.

This repository contains sources only. It has no credentials, auth codes, JWTs, provider identity files or device profiles.

## Layout

- `connect/` — `github.com/urnetwork/connect` with the `egress_resolver_linux.go` IPv4 DNS fallback.
- `proxy/` — `github.com/urnetwork/proxy` with local relative `replace` directives.
- `anet/` — local copy of `github.com/wlynxg/anet` with the `net.zoneCache` linkname removed (needed by Go 1.27.4 Android cgo builds).
- `build.sh` — fetches pinned dependencies, builds `proxy-socks` for Android/arm64 with the Bionic resolver, and downloads the official statically linked `provider` binary.

`build.sh` clones into `deps/` (gitignored) at build time: `glog`, `quic-go`, `userwireguard`, `gvisor` (pinned commit).

## Prerequisites

- Go 1.27.4
- Android NDK (set `ANDROID_NDK_HOME`)
- `git`, `curl`, `python3`

## Build

```sh
export ANDROID_NDK_HOME=/path/to/android-ndk
./build.sh
```

Outputs:

- `out/proxy-socks` — Android/arm64 PIE, cgo, dynamic interpreter `/system/bin/linker64`, depends only on `liblog.so`, `libdl.so`, `libc.so`.
- `out/provider` — official `linux/arm64` release binary.

No secrets are included in the build outputs. Credentials are supplied by the user at runtime.

## Android provider with extender/port mapping

`build-provider-android.sh` builds the provider for Android/arm64 with cgo (Bionic resolver) and the desktop extender role enabled, so `--no-port-mapping` can be omitted and the miner can ask the router for UPnP/NAT-PMP/PCP forwarding of TCP 443, UDP 443 and UDP 4053. Output: `provider-android-arm64`. It requires the Android NDK and clones the sibling `urnetwork` modules into `deps/`.

## Prebuilt VPS bundles

Ready-to-install Linux binaries are published as GitHub release assets, so no Go toolchain is needed on the VPS:

- `urnetwork-vps-linux-amd64.tar.gz`
- `urnetwork-vps-linux-arm64.tar.gz`
- `SHA256SUMS.txt`

Each bundle contains `proxy-socks`, `provider`, `tun2socks`, `README.txt` and its own `SHA256SUMS.txt`. Verify the archive checksum before use. No credentials are included.

## Notes

- The `proxy-socks` binary uses the Bionic resolver through cgo, which is why DNS works on Android devices without `/etc/resolv.conf` or `net.dns*` properties.
- Running the provider on Android is an unsupported scenario; it is the official Linux binary executed under a root shell.
