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

#### Rust example

> **Note** Don't forget to install rust supplyment when you are trying to run example out of box

With a `keyvalue.wit` as the following

```wit
variant keyvalue-error {
	key-not-found(string),
	invalid-key(string),
	invalid-value(string),
	connection-error(string),
	authentication-error(string),
	timeout-error(string),
	io-error(string),
	unexpected-error(string)
}

// a handle
type keyvalue = u32
// open a keyvalue store with name
open-store: func(name: string) -> expected<keyvalue, keyvalue-error>

store-set: func(store: keyvalue, key: string, value: list<u8>) -> expected<unit, keyvalue-error>
store-get: func(store: keyvalue, key: string) -> expected<list<u8>, keyvalue-error>
```

Instance side (use site)

```rust
#![feature(wasm_abi)]
use serde::{Deserialize, Serialize};
invoke_witc::wit_instance!(import("./keyvalue.wit"));

struct Store {
    handle: keyvalue,
}

impl Store {
    fn open(name: String) -> Self {
        Self {
            handle: open_store(name).unwrap(),
        }
    }

    fn set(&self, key: String, value: Vec<u8>) {
        store_set(self.handle, key, value).unwrap();
    }

    fn get(&self, key: String) -> Vec<u8> {
        store_get(self.handle, key).unwrap()
    }
}
```

Runtime side (implementation)

```rust
use witc_abi::*;
invoke_witc::wit_runtime!(export("./keyvalue.wit"));

static mut STORES: Vec<Store> = Vec::new();

struct Store {
    name: String,
    map: std::collections::HashMap<String, Vec<u8>>,
}
impl Store {
    fn new(name: String) -> Self {
        Self {
            name,
            map: std::collections::HashMap::new(),
        }
    }
}

fn open_store(name: String) -> Result<keyvalue, keyvalue_error> {
    println!("new store `{}`", name);
    unsafe {
        STORES.push(Store::new(name));
        Ok((STORES.len() - 1) as u32)
    }
}
fn store_set(handle: keyvalue, key: String, value: Vec<u8>) -> Result<(), keyvalue_error> {
    let store = unsafe { &mut STORES[handle as usize] };
    store.map.insert(key.clone(), value);
    println!("insert `{}` to store `{}`", key, store.name);
    Ok(())
}
fn store_get(handle: keyvalue, key: String) -> Result<Vec<u8>, keyvalue_error> {
    let store = unsafe { &mut STORES[handle as usize] };
    println!("get `{}` from store `{}`", key, store.name);
    store
        .map
        .get(key.as_str())
        .map(|v| v.to_vec())
        .ok_or(keyvalue_error::key_not_found(key))
}
```

You can use the command below to have a try

```sh
(cd example/keyvalue-demo && cargo run --release)
```

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
