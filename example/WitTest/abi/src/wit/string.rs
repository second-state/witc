#[derive(Debug)]
#[repr(C)]
pub struct WitString {
    addr: *mut u8,
    cap: usize,
    len: usize,
}

#[cfg(not(target_arch = "wasm32"))]
mod implement {
    use super::*;
    use crate::runtime::Runtime;
    use wasmedge_sdk::{Caller, WasmValue};

    impl Runtime for WitString {
        fn size() -> usize {
            12
        }

        fn new_by_runtime(caller: &Caller, input: Vec<WasmValue>) -> (Self, Vec<WasmValue>) {
            let cap = input[1].to_i32() as usize;
            let len = input[2].to_i32() as u32;
            let mem = caller.memory(0).unwrap();
            let data = mem
                .read(input[0].to_i32() as u32, len)
                .expect("fail to get string");
            (
                WitString {
                    addr: data.leak().as_mut_ptr(),
                    cap,
                    len: len as usize,
                },
                input[3..].into(),
            )
        }
    }
}

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
