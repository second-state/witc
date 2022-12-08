# C ABI

For more stable representation for data structures in rust,
we could use `repr(C)` and `std:ffi:CString` to make the representation more consistent.

Check branch [repr-c](https://github.com/second-state/witc/tree/repr-c) for more information.

## Rust `CString`, wit `string`

`CString` will become a 2-tuple `(i32, i32)` that for

1. address
2. length
