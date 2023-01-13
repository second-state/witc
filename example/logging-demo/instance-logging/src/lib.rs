#![feature(wasm_abi)]
use serde::{Deserialize, Serialize};
invoke_witc::wit_instance!(export("./logging.wit"));

#[link(wasm_import_module = "runtime")]
extern "wasm" {
    fn runtime_println(str_ptr: *const u8, str_len: usize) -> ();
}

fn println(s: String) {
    unsafe {
        runtime_println(s.as_ptr(), s.len());
    }
}

fn log(p: pack) -> u32 {
    println(format!("{} {}", p.level, p.message));
    p.level
}
