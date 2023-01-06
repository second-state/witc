# Witc ABI

When choosing which ABI we should use in `witc`, we did some surveys like [C ABI](./c_abi.md) and [Wasm ABI](./wasm_abi.md).
Originally, we use the Wasm ABI, which is based on the Rust memory layout.
However, `Option`, `Result`, `Vec`, and `String` don't have a stable layout across different Rust versions,
so we decide to define our types with a stable layout and convert between them.

### `string`

The `string` type in wit will become `WitString` and could convert between Rust `String`.

```rust
#[repr(C)]
pub struct WitString {
 addr: *mut u8,
 cap: usize,
 len: usize,
}
```

### `option`

The `option` type in wit will become `WitOption` and could convert between Rust `Option`.

```rust
#[repr(C, u32)]
pub enum WitOption<T> {
 None,
 Some(T),
}
```

### `expected`

The `expected` type in wit will become `WitResult` and could convert between Rust `Result`.

```rust
#[repr(C, u32)]
pub enum WitResult<T, E> {
 Ok(T),
 Err(E),
}
```

### `list`

The `list` type in wit will become `WitVec` and could convert between Rust `Vec`.

```rust
#[repr(C)]
pub struct WitVec<T> {
 ptr: usize,
 cap: usize,
 len: usize,
 phantom: PhantomData<T>,
}
```

### trait `Runtime`

We create a trait `Runtime` which contains the size information and build logic for ABI objects.
In addition to the above types, `witc` also generate implement code to other types like `record` and `enum`, which have stable layout.

Check [witc-abi](../bindings/rust/witc-abi/) for more information.
