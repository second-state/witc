use serde::{Deserialize, Serialize};
invoke_witc::wit_instance!(import("base.wit"));
use witc_abi::instance::*;

#[link(wasm_import_module = "host")]
extern "C" {
    fn host_fib(n: u64) -> u64;
}

#[no_mangle]
pub unsafe extern "C" fn call_base() -> u32 {
    let arg = c {
        name: "test".to_string(),
        age: 1,
    };
    let r = base(arg);
    return r.age;
}

#[no_mangle]
pub unsafe extern "C" fn call_fib() -> u64 {
    return fib(10);
}

#[no_mangle]
pub unsafe extern "C" fn call_host_fib() -> u64 {
    return host_fib(10);
}
