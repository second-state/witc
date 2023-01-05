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
    use wasmedge_sdk::{Caller, Memory, WasmValue};

    impl Runtime for WitVec<u8> {
        fn size() -> usize {
            12
        }

        fn new_by_runtime(caller: &Caller, input: Vec<WasmValue>) -> (Self, Vec<WasmValue>) {
            let cap = input[1].to_i32() as usize;
            let len = input[2].to_i32() as usize;
            let mem = caller.memory(0).unwrap();
            let data = mem
                .read(input[0].to_i32() as u32, len as u32)
                .expect("fail to get vector");
            (
                WitVec {
                    ptr: data.leak().as_mut_ptr() as usize,
                    cap,
                    len,
                    phantom: PhantomData,
                },
                input[3..].into(),
            )
        }

        fn allocate(self: Self, mem: &mut Memory) -> Vec<WasmValue> {
            let s: Vec<u8> = self.into();

            let cap = s.capacity();
            let len = s.len();

            let final_addr = mem.size() + 1;
            mem.grow(1).expect("fail to grow memory");
            // put the returned string into new address
            mem.write(s, final_addr)
                .expect("fail to write returned string");

            vec![
                WasmValue::from_i32(final_addr as i32),
                WasmValue::from_i32(cap as i32),
                WasmValue::from_i32(len as i32),
            ]
        }
    }

    fn build_inputs(data: Vec<u8>) -> Vec<WasmValue> {
        data.chunks(4)
            .map(|bytes| WasmValue::from_i32(i32::from_ne_bytes(bytes.try_into().unwrap())))
            .collect()
    }
    impl<A> Runtime for WitVec<A>
    where
        A: Runtime,
    {
        fn size() -> usize {
            12
        }

        fn new_by_runtime(caller: &Caller, input: Vec<WasmValue>) -> (Self, Vec<WasmValue>) {
            let len = input[2].to_i32() as usize;
            let mem = caller.memory(0).unwrap();
            let data = mem
                .read(input[0].to_i32() as u32, (len as u32) * A::size() as u32)
                .expect("fail to get vector");

            let mut r: Vec<A> = vec![];

            let mut input_a = build_inputs(data);
            while input_a.len() != 0 {
                let (e, r2) = A::new_by_runtime(caller, input_a);
                input_a = r2;
                r.push(e);
            }

            let cap = r.capacity();
            let len = r.len();
            (
                WitVec {
                    ptr: r.leak().as_mut_ptr() as usize,
                    cap,
                    len,
                    phantom: PhantomData,
                },
                input[3..].into(),
            )
        }

        fn allocate(self: Self, mem: &mut Memory) -> Vec<WasmValue> {
            let s: Vec<A> = self.into();

            let final_addr = mem.size() + 1;
            mem.grow(1).expect("fail to grow memory");

            let (p, cap, len) = s.into_raw_parts();

            // convert p to bytes
            let pp = unsafe { std::slice::from_raw_parts(p as *const u8, cap * A::size()) };
            mem.write(pp, final_addr)
                .expect("fail to write returned string");

            vec![
                WasmValue::from_i32(final_addr as i32),
                WasmValue::from_i32(cap as i32),
                WasmValue::from_i32(len as i32),
            ]
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
        let v: Vec<WT> = unsafe { Vec::from_raw_parts(self.ptr as *mut WT, self.len, self.cap) };
        let mut r: Vec<T> = Vec::with_capacity(self.cap);
        for e in v {
            r.push(e.into());
        }
        r
    }
}
