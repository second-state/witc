# keyvalue

This demo shows how to implement resource. With a `keyvalue.wit` as the following

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

/// a keyvalue interface
resource keyvalue {
	/// open a key-value store
	static open: func(name: string) -> expected<keyvalue, keyvalue-error>

	/// get the payload for a given key
	get: func(key: string) -> expected<list<u8>, keyvalue-error> 

	/// set the payload for a given key
	set: func(key: string, value: list<u8>) -> expected<unit, keyvalue-error>

	/// list the keys in the store
	keys: func() -> expected<list<string>, keyvalue-error>

	/// delete the payload for a given key
	delete: func(key: string) -> expected<unit, keyvalue-error>
}
```

The type like `keyvalue` call **resource**, it will only live in the one side, caller will not have a real access to internal of it. Those function in resource can be separated by is static or not.

1. static one is related but no signature changes
2. non-static will get `handle : keyvalue` binding as first parameter

Let's see some mangling

1. `keyvalue_open : func(name: string) -> expected<keyvalue, keyvalue-error>`
2. `set: func(handle: keyvalue, key: string, value: list<u8>) -> expected<unit, keyvalue-error>`

Now, you have all idea about the transformation

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
            handle: open_keyvalue(name).unwrap(),
        }
    }

    fn set(&self, key: String, value: Vec<u8>) {
        keyvalue_set(self.handle, key, value).unwrap();
    }

    fn get(&self, key: String) -> Vec<u8> {
        keyvalue_get(self.handle, key).unwrap()
    }

    fn keys(&self) -> Vec<String> {
        keyvalue_keys(self.handle).unwrap()
    }

    fn delete(&self, key: String) {
        keyvalue_delete(self.handle, key).unwrap()
    }
}
```

This is resource concept's correspondning in rust.

### runtime (provides implementations)

```rust
use witc_abi::runtime::*;
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

fn open_keyvalue(name: String) -> Result<keyvalue, keyvalue_error> {
    println!("new store `{}`", name);
    unsafe {
        STORES.push(Store::new(name));
        Ok((STORES.len() - 1) as u32)
    }
}
fn keyvalue_set(handle: keyvalue, key: String, value: Vec<u8>) -> Result<(), keyvalue_error> {
    let store = unsafe { &mut STORES[handle as usize] };
    store.map.insert(key.clone(), value);
    println!("insert `{}` to store `{}`", key, store.name);
    Ok(())
}
fn keyvalue_get(handle: keyvalue, key: String) -> Result<Vec<u8>, keyvalue_error> {
    let store = unsafe { &mut STORES[handle as usize] };
    println!("get `{}` from store `{}`", key, store.name);
    store
        .map
        .get(key.as_str())
        .map(|v| v.to_vec())
        .ok_or(keyvalue_error::key_not_found(key))
}

fn keyvalue_keys(handle: keyvalue) -> Result<Vec<String>, keyvalue_error> {
    let store = unsafe { &mut STORES[handle as usize] };
    let keys = store.map.clone().into_keys().collect();
    println!("store `{}` keys: {:?}", store.name, keys);
    Ok(keys)
}

fn keyvalue_delete(handle: keyvalue, key: String) -> Result<(), keyvalue_error> {
    let store = unsafe { &mut STORES[handle as usize] };
    store.map.remove(&key);
    println!("remove `{}` from store `{}`", key, store.name);
    Ok(())
}
```
 
