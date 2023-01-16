# Note

The current implementation is that, each component provides three functions (below is conceptual haskell code)

```haskell
allocate :: U32 -> IO U32
allocate size = makeHandle size
write :: U32 -> U32 -> Byte -> IO ()
write handle offset byte = do
  bv <- getHandle handle
  bv[offset] = byte
read :: U32 -> U32 -> IO Byte
read handle offset = do
  bv <- getHandle handle
  pure bv
```

Every caller encode it's arguments to bytes and invokes `allocate` and `write` to put argument to callee. For example, `let c = foo(a, b)` can have generated `foo`

```haskell
foo :: A -> B -> IO C
foo a b = do
  bv_a <- toJson a
  han_a <- allocate (length bv_a)
  for (write han_a) bv_a

  bv_b <- toJson b
  han_b <- allocate (length bv_b)
  for (write han_b) bv_b

  (han_c, size_c) <- extern_foo(han_a, han_b)
  bv_c <- map (read han_c) [0..size_c-1]
  fromJson bv_c
```

As you can see, the `foo` will be generated to wrap function that defined in another component automatically.

In callee side, who implements the function, will get a generated wrapper.

```haskell
extern_foo :: U32 -> U32 -> IO (U32, U32)
extern_foo han_a han_b = do
  bv_a <- getHandle han_a
  bv_b <- getHandle han_b
  c <- apply foo (map fromJson [bv_a, bv_b])
	bv_c <- toJson c
	han_c <- putHandle bv_c
	pure (han_c, length bv_c)
```

With these, one can understand and modify this repository without fear.

## Survey

Before we use current solution, we have tried.

- [C ABI](./c_abi.md): `Option`, `Result`, `Vec`, and `String` don't have a stable layout across different rust versions, however. Therefore, we define our types with a stable layout and convert between them.
- [wasm ABI](./wasm_abi.md): rust memory layout.
