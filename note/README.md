# Note

The current implementation is that, each component provides three functions (below is conceptual haskell code)

```haskell
allocate :: U32 -> IO U32
allocate size = makeHandle size
write :: U32 -> Byte -> IO ()
write handle byte = do
  bv <- getHandle handle
  push bv byte
read :: U32 -> U32 -> IO Byte
read handle offset = do
  bv <- getHandle handle
  pure bv
```

- `getHandle :: U32 -> IO [Byte]` is an assumed function, which pull put handle from a global mutable pool (such as `IORef` in haskell).
- `putHandle :: [Byte] -> IO U32` inserted a bytes into the pool, and returns a new unique `U32` value as handle.
- `push :: [Byte] -> Byte -> IO ()` modify the bytes directly.

## Caller

Every caller encode it's arguments to bytes and invokes `allocate` and `write` to put argument to callee. For example, `let c = foo(a, b)` can have generated `foo :: A -> B -> IO C`

```haskell
foo :: A -> B -> IO C
foo a b = do
  bv_a <- toJson a                             -- encode object to bytes first
  han_a <- allocate (length bv_a)              -- allocate enough size bytes in the other component, and get a handle
  for (write han_a) bv_a                       -- write all char to remote via handle

  bv_b <- toJson b                             -- again, this follows previous argument
  han_b <- allocate (length bv_b)
  for (write han_b) bv_b

  (han_c, size_c) <- extern_foo(han_a, han_b)  -- finally, invokes the mangled function (or wrapper), get handle of return value
  bv_c <- map (read han_c) [0..size_c-1]       -- make bytes that big enough, and read data back via handle of return value
  fromJson bv_c
```

As you can see, the `foo` will be generated to wrap function that defined in another component automatically.

## Callee

In callee side, who implements the function, will get a generated wrapper (wrapper has mangled name).

```haskell
extern_foo :: U32 -> U32 -> IO (U32, U32)
extern_foo han_a han_b = do
  bv_a <- getHandle han_a                      -- since caller already allocate & write bytes into handle pool, we can expect there has data
  bv_b <- getHandle han_b
  c <- apply foo (map fromJson [bv_a, bv_b])   -- forwarding decoded object to implementation, notice that, `foo` must be implemented in this component
  bv_c <- toJson c                             -- encode the return value as return bytes
  han_c <- putHandle bv_c                      -- put return bytes into pool, so that it can be represented by a handle
  pure (han_c, length bv_c)                    -- returns the (handle, bytes-length) pair
```

With these, one can understand and modify this repository without fear.

## Survey

Before we use current solution, we have tried.

- [C ABI](./c_abi.md): `Option`, `Result`, `Vec`, and `String` don't have a stable layout across different rust versions, however. Therefore, we define our types with a stable layout and convert between them.
- [wasm ABI](./wasm_abi.md): rust memory layout.
