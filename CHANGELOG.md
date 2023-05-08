# Changelog for `witc`

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to the
[Haskell Package Versioning Policy](https://pvp.haskell.org/).

## Unreleased

## 0.2.1

- export multiple component in runtime

## 0.2.0.0

- performance improvement: memory queue of call
- validation: check directory
- CLI: add `--help` and subcommand
- validation: check imports existed, e.g. `use {a, b, c} from m` will ensure `m` does have type definition `a`, `b`, and `c`

## 0.1.0.0

- wasm interface types supporting
    - `func`
    - `record`
    - `variant`
    - `enum`
    - `resource`
- backend: code generation
    - rust
      - runtime import/export
      - instance import/export
- check command
