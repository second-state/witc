#![feature(wasm_abi)]
use serde::{Deserialize, Serialize};
invoke_witc::wit_instance_export!("./logging.wit");

const EMPTY_STRING: String = String::new();
pub static mut BUCKET: [String; 100] = [EMPTY_STRING; 100];
pub static mut COUNT: usize = 0;

// allocate : (size : usize) -> (addr : i32)
#[no_mangle]
pub unsafe extern "wasm" fn allocate(size: usize) -> usize {
    println!("allocate?");
    let s = String::with_capacity(size);
    BUCKET[COUNT] = s;
    let count = COUNT;
    COUNT += 1;
    count
}
// write : (addr : i32) -> (offset : i32) -> (byte : u8) -> ()
#[no_mangle]
pub unsafe extern "wasm" fn write(count: usize, offset: usize, byte: u8) {
    println!("writing?");
    let string = &mut BUCKET[count];
    string.insert(offset, byte as char);
}
// read : (addr : i32) -> (offset : i32) -> (byte : u8)
#[no_mangle]
pub unsafe extern "wasm" fn read(count: usize, offset: usize) -> u8 {
    println!("reading?");
    COUNT = 0;
    let s = &BUCKET[count];
    s.as_bytes()[offset]
}

#[no_mangle]
pub unsafe extern "wasm" fn extern_log(ptr: usize, len: usize) -> (usize, usize) {
    let s = String::from_raw_parts(ptr as *mut u8, len, len);
    let p: pack = serde_json::from_str(s.as_str()).unwrap();
    let res = log(p);
    let res_str = serde_json::to_string(&res).unwrap();
    let len = res_str.len();
    BUCKET[0] = res_str;
    (0, len)
}

fn log(p: pack) -> u32 {
    println!("{} {}", p.level, p.message);
    p.level
}
