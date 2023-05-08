test: build-wasm
	cargo test
.PHONY: test

build-wasm:
	cargo build --manifest-path import_wasm/Cargo.toml --target wasm32-wasi -r
.PHONY: build-wasm
