# Wasm ABI

This development note records the conversion from **Rust** type to wasm representation, it's not for most people not goes to implement `wit` format compiler, but should be valuable internally.

### String

`String` will become a 3-tuple `(i32, i32, i32)` that for `addr`, `capability`, and `length`.

### Struct

A structure will be unfold till only wasm type left, for example

```rust
struct person {
    name: String,
    age: u32
}
```

turns to

```rust
(i32, i32, i32, i32)
```

> If you don't quite get the idea, reconsider the encoding of `String`, and how tree layout of structure to be linear tuple.
