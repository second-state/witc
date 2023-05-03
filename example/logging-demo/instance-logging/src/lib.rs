use serde::{Deserialize, Serialize};
invoke_witc::wit_instance!(export("./logging.wit"));

#[link(wasm_import_module = "runtime")]
extern "C" {
    fn runtime_println(str_ptr: *const u8, str_len: usize) -> ();
}

fn log(p: pack) -> u32 {
    let s = format!("{} {}", p.level, p.message);
    unsafe {
        runtime_println(s.as_ptr(), s.len());
    }
    p.level
}
