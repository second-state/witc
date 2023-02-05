const EMPTY_STRING: String = String::new();
pub static mut BUCKET: [String; 100] = [EMPTY_STRING; 100];
pub static mut COUNT: usize = 0;

#[no_mangle]
pub unsafe extern "wasm" fn allocate(size: usize) -> usize {
    let s = String::with_capacity(size);
    BUCKET[COUNT] = s;
    let count = COUNT;
    COUNT += 1;
    count
}
#[no_mangle]
pub unsafe extern "wasm" fn write(count: usize, byte: u8) {
    // TODO: expected u64
    let s = &mut BUCKET[count];
    s.push(byte as char);
}
#[no_mangle]
pub unsafe extern "wasm" fn read(count: usize, offset: usize) -> u8 {
    // TODO: return u64
    let s = &BUCKET[count];
    s.as_bytes()[offset]
}
