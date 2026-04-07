new-post := "tools/new-post/target/release/new-post"

_build:
    cargo build --manifest-path tools/new-post/Cargo.toml --release --quiet

post: _build
    {{new-post}} post

now: _build
    {{new-post}} now
