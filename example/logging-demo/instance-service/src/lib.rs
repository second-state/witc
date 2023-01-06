#![feature(wasm_abi)]

use witc_abi::*;
invoke_witc::wit_instance_import!("./logging.wit");

#[no_mangle]
pub unsafe extern "wasm" fn start() -> u32 {
    let _ = log(pack {
        message: "cannot connect to 196.128.10.3".to_string(),
        level: 1,
    });
    return 0;
}
