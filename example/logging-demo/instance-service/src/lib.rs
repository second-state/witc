#![feature(wasm_abi)]
use serde::{Deserialize, Serialize};
use witc_abi::instance::*;
invoke_witc::wit_instance!(import(instance_logging = "logging.wit"));

#[no_mangle]
pub unsafe extern "wasm" fn start() -> u32 {
    let _ = log(pack {
        message: "cannot connect to 196.128.10.3".to_string(),
        level: 1,
    });
    return 0;
}
