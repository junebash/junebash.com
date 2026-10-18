#!/usr/bin/env bash
# Netlify's build: install Swift, compile fancy mode, then the site. Arguments go to `zola build`.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
version="$(tr -d '[:space:]' < "$root/fancy/.swift-version")"
release="swift-${version}-RELEASE"
toolchain_url="https://download.swift.org/swift-${version}-release/ubuntu2404/${release}/${release}-ubuntu24.04.tar.gz"
sdk="${release}_wasm"
sdk_url="https://download.swift.org/swift-${version}-release/wasm-sdk/${release}/${sdk}.artifactbundle.tar.gz"
# For 6.3.3. Changing .swift-version means updating this too.
sdk_checksum="cabfa08b73bb8ac783927ecd15fa386e99d0c139c5f232445067bcf58379cae7"

df -h "$HOME" /tmp

# Netlify's own Swift install (swiftenv) unpacks all 3.5GB beside the 1GB tarball and runs out of disk.
# Streaming skips the tarball, and the excludes drop about 1.2GB of debugger and editor tooling.
toolchain="$HOME/swift-toolchain"
if [[ ! -x "$toolchain/usr/bin/swift" ]]; then
  mkdir -p "$toolchain"
  curl -fsSL "$toolchain_url" | tar xz -C "$toolchain" --strip-components=1 \
    --wildcards \
    --exclude='*/usr/bin/sourcekit-lsp' --exclude='*/usr/bin/lldb*' --exclude='*/usr/lib/liblldb*' \
    --exclude='*/usr/lib/libsourcekitdInProc*' --exclude='*/usr/bin/clangd' --exclude='*/usr/bin/docc' \
    --exclude='*/usr/bin/swift-format' --exclude='*/usr/lib/swift_static' --exclude='*/usr/share/docc'
fi

# PackageToJS skips optimizing without wasm-opt, and the unoptimized wasm busts the size limit.
binaryen="binaryen-version_133"
binaryen_checksum="2dc9c7813f5375db93d96ead4b78222fcc3e2677bbb832297af4797782a37489"
if [[ ! -x "$HOME/$binaryen/bin/wasm-opt" ]]; then
  curl -fsSL -o "$HOME/$binaryen.tar.gz" "https://github.com/WebAssembly/binaryen/releases/download/${binaryen#binaryen-}/$binaryen-x86_64-linux.tar.gz"
  echo "$binaryen_checksum  $HOME/$binaryen.tar.gz" | sha256sum -c -
  tar xzf "$HOME/$binaryen.tar.gz" -C "$HOME" "$binaryen/bin/wasm-opt"
  rm "$HOME/$binaryen.tar.gz"
fi

export PATH="$toolchain/usr/bin:$HOME/$binaryen/bin:$PATH"
swift --version
wasm-opt --version

swift sdk list | grep -qx "$sdk" || swift sdk install "$sdk_url" --checksum "$sdk_checksum"

(cd "$root/fancy" && swift package --swift-sdk "$sdk" js -c release)
"$root/scripts/package-fancy.sh"
df -h "$HOME"
zola build "$@"
