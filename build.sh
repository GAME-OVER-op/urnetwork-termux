#!/bin/sh
# Build the URnetwork Termux/Android bundle from this single repository.
# Prerequisites: Go 1.27.4, git, curl, python3, Android NDK.
set -eu

ROOT="$(cd "$(dirname "$0")" && pwd)"
GO="${GO:-go}"
NDK="${ANDROID_NDK_HOME:-${ROOT}/android-ndk}"
DEPS="$ROOT/deps"
OUT="$ROOT/out"

mkdir -p "$DEPS" "$OUT"

clone_shallow() {
    name="$1"
    url="$2"
    if [ ! -d "$DEPS/$name/.git" ]; then
        echo "clone $name"
        git clone --depth 1 "$url" "$DEPS/$name"
    fi
}

clone_shallow glog https://github.com/urnetwork/glog.git
clone_shallow quic-go https://github.com/urnetwork/quic-go.git
clone_shallow userwireguard https://github.com/urnetwork/userwireguard.git

# gvisor is pinned to the commit used by the current connect module.
if [ ! -d "$DEPS/gvisor/.git" ]; then
    echo "clone gvisor (pinned)"
    git clone --filter=blob:none --no-checkout https://github.com/urnetwork/gvisor.git "$DEPS/gvisor"
    git -C "$DEPS/gvisor" fetch --depth 1 origin 9b1144b679cb
    git -C "$DEPS/gvisor" checkout 9b1144b679cb
fi

CC="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang"
if [ ! -x "$CC" ]; then
    echo "Android clang not found: $CC" >&2
    echo "Set ANDROID_NDK_HOME to an NDK installation." >&2
    exit 1
fi

echo "build proxy-socks (android/arm64, cgo/Bionic resolver)"
cd "$ROOT/proxy"
CGO_ENABLED=1 GOOS=android GOARCH=arm64 CC="$CC" \
    "$GO" build -trimpath -ldflags='-s -w' -o "$OUT/proxy-socks" ./socks

echo "fetch provider linux/arm64"
url="$(curl -fsSL https://api.github.com/repos/urnetwork/build/releases/latest | python3 -c '
import json,sys
d=json.load(sys.stdin)
print(next(a["browser_download_url"] for a in d["assets"] if a["name"].startswith("urnetwork-provider-")))
')"
curl -fSL --retry 2 -o "$OUT/provider.tar.gz" "$url"
tar -xzf "$OUT/provider.tar.gz" -C "$OUT" linux/arm64/provider
mv "$OUT/linux/arm64/provider" "$OUT/provider"
chmod 755 "$OUT/provider" "$OUT/proxy-socks"

echo "done: $OUT/proxy-socks"
echo "done: $OUT/provider"
