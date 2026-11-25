#!/bin/sh
# Build the URnetwork provider for Android/arm64 with cgo/Bionic resolver and
# the desktop extender role enabled (port mapping support).
set -eu

ROOT="$(cd "$(dirname "$0")" && pwd)"
DEPS="$ROOT/deps"
NDK="${ANDROID_NDK_HOME:-$HOME/.local/share/android-sdk/ndk/30.0.16248370}"
CC="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang"

mkdir -p "$DEPS"

clone() {
  repo=$1
  dir=$2
  if [ ! -d "$DEPS/$dir/.git" ]; then
    echo "clone $dir"
    git clone --depth 1 "https://github.com/urnetwork/$repo.git" "$DEPS/$dir"
  fi
}

# Our patched sources live in the repository root.
ln -sfn ../connect "$DEPS/connect"
ln -sfn ../proxy "$DEPS/proxy"
ln -sfn ../anet "$DEPS/anet"

clone glog glog
clone quic-go quic-go
clone userwireguard userwireguard
if [ ! -d "$DEPS/gvisor/.git" ]; then
  git clone --filter=blob:none --no-checkout https://github.com/urnetwork/gvisor.git "$DEPS/gvisor"
  git -C "$DEPS/gvisor" fetch --depth 1 origin 9b1144b679cb
  git -C "$DEPS/gvisor" checkout 9b1144b679cb
fi

for name in sdk server warp goidenticons sn; do
  clone "$name" "$name"
done

# Stock Android builds disable the extender role. Enable the native
# implementation for android so the miner can ask the router to forward ports.
sed -i 's#^//go:build ios || android || js$#//go:build ios || js#' "$DEPS/sdk/device_local_extender_mobile.go"
sed -i 's#^//go:build !ios && !android && !js$#//go:build !ios \&\& !js#' "$DEPS/sdk/device_local_extender_native.go"

# Use the local anet copy without the Go 1.27.4 zoneCache linkname.
if ! grep -q 'wlynxg/anet => ../anet' "$DEPS/sn/go.mod"; then
  printf '\nreplace github.com/wlynxg/anet => ../anet\n' >> "$DEPS/sn/go.mod"
fi

if [ ! -x "$CC" ]; then
  echo "Android clang not found: $CC" >&2
  exit 1
fi

echo "build provider android/arm64 cgo + extender"
cd "$DEPS/sn"
CGO_ENABLED=1 GOOS=android GOARCH=arm64 CC="$CC" \
  go build -trimpath -ldflags='-s -w' -o "$ROOT/provider-android-arm64" ./cli/miner

echo "done: $ROOT/provider-android-arm64"
