#![feature(wasm_abi)]
use serde::{Deserialize, Serialize};
invoke_witc::wit_instance_import!("./keyvalue.wit");

#[no_mangle]
pub unsafe extern "wasm" fn start() -> u32 {
    let store = open_store("store A".to_string()).unwrap();
    store_set(store, "key1".to_string(), vec![1, 2, 3]).unwrap();
    let value = store_get(store, "key1".to_string()).unwrap();
    assert_eq!(value, vec![1, 2, 3]);
    return 0;
}
