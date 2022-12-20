// use super::runtime::Runtime;

#[derive(Debug)]
#[repr(C)]
pub struct WitString {
    addr: *mut u8,
    cap: usize,
    len: usize,
}

// impl Runtime for WitString {}

impl From<&str> for WitString {
    fn from(s: &str) -> Self {
        let (ptr, len, cap) = s.to_string().into_raw_parts();
        Self {
            addr: ptr,
            cap,
            len,
        }
    }
}
impl From<String> for WitString {
    fn from(s: String) -> Self {
        let (ptr, len, cap) = s.into_raw_parts();
        Self {
            addr: ptr,
            cap,
            len,
        }
    }
}

impl Into<String> for WitString {
    fn into(self: Self) -> String {
        unsafe { String::from_raw_parts(self.addr, self.len, self.cap) }
    }
}
