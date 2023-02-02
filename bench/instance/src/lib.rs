#![feature(wasm_abi)]
use serde::{Deserialize, Serialize};
invoke_witc::wit_instance!(import("base.wit"));

#[no_mangle]
pub unsafe extern "wasm" fn start() -> u32 {
    let arg = c {
        name: "test".to_string(),
        age: 1,
    };
    let r = base(arg);
    return r.age;
}
