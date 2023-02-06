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

### Installation

```sh
stack install
# install to `~/.local/bin`
```

### Usage

`*.wit` files are sharing interface and common types between different component in the wasm ecosystem, a runtime is a component, a running wasm module is a component. In our context, wasmedge is the runtime, and wasm module instance is the instance. Under **witc**, you have three directions

1. instance invokes a runtime function
2. instance invokes an instance function
3. runtime invokes an instance function

Without **witc** you can still invoke these function, but have to convert typing by yourself and figuring out complicated layout. Now, development is easy and lovely, all callsite and implementation using the native type of that language.

#### Rust examples

> **Note** Don't forget to install rust supplyment when you are trying to run example out of box

To illustrate how to use witc, we have the following examples, and you can use the following command to run them

```sh
cargo run --release
```

- [demo: keyvalue](./example/keyvalue-demo/): instance invokes runtime
- [demo: logging](./example/logging-demo/): instance invokes instance
- [demo: traffic lights](./example/traffic-lights/): runtime invokes instance

#### CLI

You can also use following commands to let compiler output to stdout

- instance

  - import `witc instance import xxx.wit`, or `witc instance import xxx.wit yyy` if you want to have different import name(usually happened when you import code from another instance)
  - export `witc instance export xxx.wit`

- runtime

  - export `witc runtime export xxx.wit`

### Development

To get the proper Haskell configuration, we recommend you install the following combination with [`ghcup`](https://www.haskell.org/ghcup/).

```shell
ghcup install ghc 9.2.5
ghcup install hls 1.9.0.0
```

### Why witc?

You might wonder why you need `witc` since `wit-bindgen` already exists. Although `wit-bindgen` is good, it is currently in active development, and `witc` will explore different approach that increases the diversity of wit related toolchain. Additionally, the Component Model and Canonical ABI change frequently with large updates, in this sense `witc` will serve as a middle project to wait for `wit-bindgen` to become stable. We will contribute to `wit-bindgen` at that point, for these reasons, we will support a small number of features in `witc` that only ensuring that the basic demo works.
