use std::marker::PhantomData;

use super::string::WitString;

#[cfg(not(target_arch = "wasm32"))]
mod implement {
    use super::*;
    use crate::runtime::Runtime;
    use wasmedge_sdk::{Caller, WasmValue};

    impl Runtime for WitVec<u8> {
        type T = Vec<u8>;

        fn size() -> usize {
            12
        }

        fn new_by_runtime(caller: &Caller, input: Vec<WasmValue>) -> (Self::T, Vec<WasmValue>) {
            let mem = caller.memory(0).unwrap();
            let data = mem
                .read(input[0].to_i32() as u32, input[2].to_i32() as u32)
                .expect("fail to get vector");
            (data, input[3..].into())
        }
    }

    fn convert(data: Vec<u8>) -> Vec<WasmValue> {
        data.chunks(4)
            .map(|bytes| WasmValue::from_i32(i32::from_ne_bytes(bytes.try_into().unwrap())))
            .collect()
    }

    impl<A> Runtime for WitVec<A>
    where
        A: Runtime,
    {
        type T = Vec<A::T>;

        fn size() -> usize {
            12
        }

        fn new_by_runtime(caller: &Caller, input: Vec<WasmValue>) -> (Self::T, Vec<WasmValue>) {
            let len = input[2].to_i32() as u32 * A::size() as u32;
            let mem = caller.memory(0).unwrap();
            let data = mem
                .read(input[0].to_i32() as u32, len)
                .expect("fail to get vector");

            let mut r: Self::T = vec![];

            let mut input_a = convert(data);
            while input_a.len() != 0 {
                let (e, r2) = A::new_by_runtime(caller, input_a);
                input_a = r2;
                r.push(e);
            }

            (r, input[3..].into())
        }
    }
}

#[derive(Debug)]
#[repr(C)]
pub struct WitVec<T> {
    ptr: usize,
    cap: usize,
    len: usize,
    phantom: PhantomData<T>,
}

impl From<Vec<String>> for WitVec<WitString> {
    fn from(r: Vec<String>) -> Self {
        let mut v: Vec<WitString> = vec![];
        for e in r {
            v.push(e.into());
        }

        WitVec {
            cap: v.capacity(),
            len: v.len(),
            ptr: v.leak().as_ptr() as usize,
            phantom: PhantomData,
        }
    }
}
impl<T> From<Vec<T>> for WitVec<T> {
    fn from(r: Vec<T>) -> Self {
        WitVec {
            cap: r.capacity(),
            len: r.len(),
            ptr: r.leak().as_ptr() as usize,
            phantom: PhantomData,
        }
    }
}
impl Into<Vec<String>> for WitVec<WitString> {
    fn into(self: Self) -> Vec<String> {
        let v: Vec<WitString> =
            unsafe { Vec::from_raw_parts(self.ptr as *mut WitString, self.cap, self.len) };
        let mut r: Vec<String> = Vec::with_capacity(self.cap);
        for e in v {
            r.push(e.into());
        }
        r
    }
}
impl<T> Into<Vec<T>> for WitVec<T> {
    fn into(self: Self) -> Vec<T> {
        unsafe { Vec::from_raw_parts(self.ptr as *mut T, self.cap, self.len) }
    }
}
