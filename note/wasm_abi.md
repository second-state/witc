# Wasm ABI

This development note records the conversion from **Rust** type to wasm representation, it's not for most people not goes to implement `wit` format compiler, but should be valuable internally.

### Rust `String`, wit `string`

`String` will become a 3-tuple `(i32, i32, i32)` that for `addr`, `capability`, and `length`.

### Rust `struct A`, wit `record A`

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

### Rust `enum`, wit `enum`

Tricky thing is **wit** also has `variant` type seems just like **Rust** `enum` for sum-of-product, but here is only about the trivial case: sum of tag. In this sense, **Rust** `enum` is the **wit** `enum`, and the encoding is an integer.

Hence, if we said there has a definition

```wit
enum color {
    red,
    green,
    blue
}
```

After compiled to **Rust**, there would have a mapping

- `color::red` => `0`
- `color::green` => `1`
- `color::blue` => `2`
