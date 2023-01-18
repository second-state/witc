# keyvalue

This demo shows how to wrap handle related functions as struct and its `impl` in rust. With a `keyvalue.wit` as the following

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

As you can see, the 

### instance (callsite)

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

As you see, you always can wrap a set of handle related functions to a struct, which is resource concept in wasm interface types intend to.

### runtime (provides implementations)

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
 
