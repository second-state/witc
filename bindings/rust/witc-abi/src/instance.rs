#[repr(C)]
pub struct ReadBuf {
    offset: usize,
    len: usize,
}

impl ToString for ReadBuf {
    fn to_string(self: &Self) -> String {
        unsafe { String::from_raw_parts(self.offset as *mut u8, self.len, self.len) }
    }
}

#[link(wasm_import_module = "wasmedge.component.model")]
extern "C" {
    pub fn require_queue() -> i32;
    pub fn write(id: i32, offset: usize, len: usize);
    pub fn read(id: i32) -> ReadBuf;
}
