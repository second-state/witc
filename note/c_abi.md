# C ABI

For more stable representation for data structures in rust,
we could use `repr(C)` and `std:ffi:CString` to make the representation more consistent. Check PR [stable-api](https://github.com/second-state/witc/pull/22) for more details.

### Rust `CString`

`CString` will become a 2-tuple `(i32, i32)` that for

1. address
2. length

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
