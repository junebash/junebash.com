#!/usr/bin/env bash
# Copies the fancy-mode build into a content-hashed folder under static/,
# so returning visitors never get a stale wasm/js pairing from cache.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/fancy/.build/plugins/PackageToJS/outputs/Package"
dest_root="$root/static/fancy/build"
limit=3000000

stage="$(mktemp -d)"
mkdir -p "$stage/app/platforms" "$stage/app/wasi-shim"
cp "$out"/index.js "$out"/instantiate.js "$out"/runtime.js "$out"/Fancy.wasm "$stage/app/"
cp "$out"/platforms/browser.js "$stage/app/platforms/"
cp "$root"/fancy/vendor/browser_wasi_shim/*.js "$root"/fancy/vendor/browser_wasi_shim/LICENSE-* "$stage/app/wasi-shim/"
browser="$stage/app/platforms/browser.js"
sed "s#'@bjorn3/browser_wasi_shim'#'../wasi-shim/index.js'#" "$browser" > "$browser.new"
mv "$browser.new" "$browser"
grep -q "../wasi-shim/index.js" "$stage/app/platforms/browser.js"
cp "$root"/fancy/web/* "$stage/"

# Brotli is what browsers get; gzip runs larger, so it's a stricter stand-in where brotli is missing.
if command -v brotli > /dev/null; then
  compressor=brotli
  compressed=$(brotli -c -q 11 "$stage/app/Fancy.wasm" | wc -c | tr -d ' ')
else
  compressor=gzip
  compressed=$(gzip -c -9 "$stage/app/Fancy.wasm" | wc -c | tr -d ' ')
fi
if (( compressed > limit )); then
  echo "Fancy.wasm is ${compressed} bytes compressed, over the ${limit} limit. Did Foundation sneak in?" >&2
  exit 1
fi

sha256() { if command -v sha256sum > /dev/null; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }
remove() { if command -v trash > /dev/null; then trash "$@"; else rm -rf "$@"; fi; }
hash=$(cd "$stage" && find . -type f | LC_ALL=C sort | while read -r file; do sha256 "$file"; done | sha256 | cut -c1-12)
mkdir -p "$dest_root"
for old in "$dest_root"/*/; do
  [[ -d "$old" && "$(basename "$old")" != "$hash" ]] && remove "$old"
done
[[ -e "$dest_root/$hash" ]] && remove "$dest_root/$hash"
mv "$stage" "$dest_root/$hash"
chmod -R a+rX "$dest_root/$hash"
printf 'hash = "%s"\n' "$hash" > "$dest_root/manifest.toml"
echo "fancy build $hash ($(( compressed / 1024 ))KB wasm, $compressor)"
