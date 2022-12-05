#![feature(wasm_abi)]

#[link(wasm_import_module = "host")]
extern "wasm" {
    fn exchange(s: String) -> String;
}

#[no_mangle]
pub unsafe extern "wasm" fn start() -> u32 {
    let mut s = String::with_capacity(10);
    s.push('a');
    let _s = exchange(s);
    return 0;
}
