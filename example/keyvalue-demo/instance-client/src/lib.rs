#![feature(wasm_abi)]
use serde::{Deserialize, Serialize};
invoke_witc::wit_instance!(import("./keyvalue.wit"));

struct Store {
    handle: keyvalue,
}

impl Store {
    fn open(name: String) -> Self {
        Self {
            handle: keyvalue_open(name).unwrap(),
        }
    }

    fn set(&self, key: String, value: Vec<u8>) {
        keyvalue_set(self.handle, key, value).unwrap();
    }

    fn get(&self, key: String) -> Vec<u8> {
        keyvalue_get(self.handle, key).unwrap()
    }
}

#[no_mangle]
pub unsafe extern "wasm" fn start() -> u32 {
    let store = Store::open("store A".to_string());
    store.set("key1".to_string(), vec![1, 2, 3]);
    let value = store.get("key1".to_string());
    assert_eq!(value, vec![1, 2, 3]);
    return 0;
}
