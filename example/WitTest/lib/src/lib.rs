#![feature(wasm_abi)]

pmacro::wit_instance_import!("../test.wit");

#[no_mangle]
pub unsafe extern "wasm" fn start() -> u32 {
    let mut s = String::with_capacity(10);
    s.push('a');
    let _s = exchange(s);
    return 0;
}
