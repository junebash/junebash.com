new-post := "tools/new-post/target/release/new-post"

_build:
    cargo build --manifest-path tools/new-post/Cargo.toml --release --quiet

post: _build
    {{new-post}} post

now: _build
    {{new-post}} now

swiftly := env_var('HOME') / ".swiftly/bin/swiftly"
wasm-sdk := "swift-6.3.3-RELEASE_wasm"

# Build fancy mode (Swift → WebAssembly) into static/fancy/build/
fancy:
    cd fancy && {{swiftly}} run swift package --swift-sdk {{wasm-sdk}} js -c release
    scripts/package-fancy.sh

# Run fancy mode's core tests on macOS
fancy-test:
    cd fancy && {{swiftly}} run swift test
