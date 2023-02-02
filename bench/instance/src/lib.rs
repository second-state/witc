#![feature(wasm_abi)]
use serde::{Deserialize, Serialize};
invoke_witc::wit_instance!(import("base.wit"));

#[link(wasm_import_module = "host")]
extern "wasm" {
    fn host_fib(n: u64) -> u64;
}

#[no_mangle]
pub unsafe extern "wasm" fn call_base() -> u32 {
    let arg = c {
        name: "test".to_string(),
        age: 1,
    };
    let r = base(arg);
    return r.age;
}

#[no_mangle]
pub unsafe extern "wasm" fn call_fib() -> u64 {
    return fib(10);
}

#[no_mangle]
pub unsafe extern "wasm" fn call_host_fib() -> u64 {
    return host_fib(10);
}
