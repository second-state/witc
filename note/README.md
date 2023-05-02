# Note

## Current implementation: runtime management queue

This implementation assuming a queue pool in runtime (provided by witc_abi), the existed three functions are

1. require a new queue
2. putting data into queue
3. getting data from queue

In runtime, we have direct access to the global state object. In instance, we will use the provided host functions. Whatever you're, a function call will be the following steps:

1. requires a queue, get an ID
2. write encoded arguments to the queue by the ID
3. invokes converted interface function, provides ID to it
4. read all returns and decode them back from the queue by the ID

Therefore, each callee (implementor) must do

1. read all parameters back from queue by ID and decode them
2. invokes real function with decoded data
3. write encoded returns back to queue by ID

## Survey

Before we use current solution, we have tried.

- [implementation](./drop/component-three-fn-impl.md): each component provides allocate/read/write
- [C ABI](./drop/c_abi.md): `Option`, `Result`, `Vec`, and `String` don't have a stable layout across different rust versions, however. Therefore, we define our types with a stable layout and convert between them.
- [wasm ABI](./drop/wasm_abi.md): rust memory layout.
