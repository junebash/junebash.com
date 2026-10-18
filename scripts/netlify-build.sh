#!/usr/bin/env bash
# Netlify's build: compile fancy mode, then the site. Arguments go to `zola build`.
# Netlify installs the toolchain itself from SWIFT_VERSION (see netlify.toml).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
sdk="swift-${SWIFT_VERSION}-RELEASE_wasm"
sdk_url="https://download.swift.org/swift-${SWIFT_VERSION}-release/wasm-sdk/swift-${SWIFT_VERSION}-RELEASE/${sdk}.artifactbundle.tar.gz"
sdk_checksum="cabfa08b73bb8ac783927ecd15fa386e99d0c139c5f232445067bcf58379cae7"

swift --version
swift sdk list | grep -qx "$sdk" || swift sdk install "$sdk_url" --checksum "$sdk_checksum"

(cd "$root/fancy" && swift package --swift-sdk "$sdk" js -c release)
"$root/scripts/package-fancy.sh"
zola build "$@"
