use std::marker::PhantomData;

#[derive(Debug)]
#[repr(C)]
pub struct WitVec<T> {
    ptr: usize,
    cap: usize,
    len: usize,
    phantom: PhantomData<T>,
}

#[cfg(not(target_arch = "wasm32"))]
mod implement {
    use super::*;
    use crate::runtime::Runtime;
    use wasmedge_sdk::{Caller, WasmValue};

    fn build_inputs(data: Vec<u8>) -> Vec<WasmValue> {
        data.chunks(4)
            .map(|bytes| WasmValue::from_i32(i32::from_ne_bytes(bytes.try_into().unwrap())))
            .collect()
    }

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

            let mut input_a = build_inputs(data);
            while input_a.len() != 0 {
                let (e, r2) = A::new_by_runtime(caller, input_a);
                input_a = r2;
                r.push(e);
            }

            (r, input[3..].into())
        }
    }
}

impl<WT, T> From<Vec<T>> for WitVec<WT>
where
    T: Into<WT>,
{
    fn from(r: Vec<T>) -> Self {
        let mut v: Vec<WT> = vec![];
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

impl<T, WT> Into<Vec<T>> for WitVec<WT>
where
    WT: Into<T>,
{
    fn into(self: Self) -> Vec<T> {
        let v: Vec<WT> = unsafe { Vec::from_raw_parts(self.ptr as *mut WT, self.cap, self.len) };
        let mut r: Vec<T> = Vec::with_capacity(self.cap);
        for e in v {
            r.push(e.into());
        }
        r
    }
}
