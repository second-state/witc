# Wasm ABI

This development note records the conversion from **Rust** type to wasm representation, it's not for most people not goes to implement `wit` format compiler, but should be valuable internally.

### Rust `String`, wit `string`

`String` will become a 3-tuple `(i32, i32, i32)` that for

1. address
2. capability
3. length

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

After witc compile it to **Rust** then wasm abi takes over, there would have a mapping

- `color::red` => `0`
- `color::green` => `1`
- `color::blue` => `2`

### Rust `Option`, wit `option`

`option` is the first type function, it takes one type and returns one type, witc compiles it to **Rust** `Option` type. The definition in **Rust** should be:

```rust
enum Option<T> {
    None,
    Some(T),
}
```

As expected, the tagging is `i32` when to wasm code, so the mapping as the following:

- `None` => `0`
- `Some` => `1`

and then the second encoding is depending on `T`. Thus, `option<s32>` end up be `(i32, i32)`

### Rust `Result`, wit `expected`

First wit `expected<T, E>` turns to `Result<T, E>` in **Rust**, then following above idea by finding definition of `Result`

```rust
enum Result<T, E> {
   Ok(T),
   Err(E),
}
```

As guess that simple type like `expected<s32, s32>`, the converted wasm type is `(i32, i32)`, and the first for tagging the second for value.

However, when thing came to `Err` the encoding is much more confusing now, the result of `Err` first `i32` is not always `1` but can also be any non-zero value. What's going on here?

Back to concrete example, the `expected<s32, string>` has conversion `(i32, i32, i32)`. First, the first `i32` still is `0` when it's `Ok`, but it would be an address when it's `Err`. In fact, for a construction `Err("abc")`, the tuple would be `(addr, 3, 3)`. Of course, the `String` encoding here.

Thus, the current inspection shows that the `Result` type basically is just `0`, and is `1` when `E` is a single `i32` representable type. When `E` is not `i32` representable, it will in the heap of **Rust** instance.

### Rust `Vec`, wit `list`

First, a `Vec<T>` will be came a 3-tuple `(i32, i32, i32)`, for

1. address
2. capability
3. length

Just like `String`. Then you can get a linear memory chunk for `Vec<u8>` to get all data, now you need to decode it out to target type. For example, `vec!["test".to_string(), "abc".to_string()]` will have such chunk as

```rust
[48, 13, 16, 0, 4, 0, 0, 0, 4, 0, 0, 0, 64, 13, 16, 0, 3, 0, 0, 0, 3, 0, 0, 0]
```

It's easy to figure out what's that

- `"test"`
  1. addr: 48, 13, 16, 0
  2. cap: 4, 0, 0, 0
  3. len: 4, 0, 0, 0
- `"abc"`
  1. addr: 64, 13, 16, 0
  2. cap: 3, 0, 0, 0
  3. len: 3, 0, 0, 0

That's all.
