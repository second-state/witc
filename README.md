# witc

> **Warning**
> This is an early-stage project

A compiler generates code for `*.wit` files.

### Overview

To understand this project, I will show you what's `*.wit` stand for first. The story starts by passing a string as an argument to function in the wasm instance, if you do so, you will find out that wasm has no type called `string`. You will figure out that you only need to encode the string as a pair of `i32`, which means `(i32, i32)` and one for address, one for string length. However, the address valid out of an instance will not be valid in that instance. Then you found runtime(e.g. wasmedge, wasmtime) can operate the memory of instances, write data to somewhere in the instance, and use that address, problem solved!

Quickly, your program grows, and now you manage tons of mappings.

```rust
fn foo(s: String, s2: String) -> String
// <->
fn foo(s_addr: i32, s_size: i32, s2_addr: i32, s2_size: i32) -> (i32, i32)
```

The thing is a bit out of control, not to say compound types like **structure**, **enum**, and **list**. In this sense, **wit** stands for one source code that is reusable for multi-target, and multi-direction and **witc** does code generation and manages ABI and memory operations. Thus, you can import/export types or functions from instance or runtime.

### CLI

Conceptual command

```sh
witc instance import xxx.wit
witc runtime export xxx.wit
```
