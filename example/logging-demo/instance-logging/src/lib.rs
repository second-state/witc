#![feature(wasm_abi)]
use serde::{Deserialize, Serialize};
invoke_witc::wit_instance_export!("./logging.wit");

#[link(wasm_import_module = "runtime")]
extern "wasm" {
    fn runtime_println(str_ptr: *const u8, str_len: usize) -> ();
}

fn println(s: String) {
    unsafe {
        runtime_println(s.as_ptr(), s.len());
    }
}

#[no_mangle]
pub unsafe extern "wasm" fn extern_log(count: usize, len: usize) -> (usize, usize) {
    let s = &BUCKET[count];
    let p: pack = serde_json::from_str(s.as_str()).unwrap();
    let res = log(p);
    let res_str = serde_json::to_string(&res).unwrap();
    let len = res_str.len();
    BUCKET[0] = res_str;
    (0, len)
}

fn log(p: pack) -> u32 {
    println(format!("{} {}", p.level, p.message));
    p.level
}
