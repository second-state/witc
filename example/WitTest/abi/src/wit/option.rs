#[cfg(not(target_arch = "wasm32"))]
mod implement {
    use super::*;
    use crate::runtime::Runtime;
    use wasmedge_sdk::{Caller, WasmValue};

    impl Runtime for WitOption<u8> {
        type T = Option<u8>;

        fn size() -> usize {
            4 + 4
        }

        fn new_by_runtime(_caller: &Caller, input: Vec<WasmValue>) -> (Self::T, Vec<WasmValue>) {
            match input[0].to_i32() {
                0 => (None, input[2..].into()),
                1 => {
                    let e = input[1].to_i32() as u8;
                    (Some(e), input[2..].into())
                }
                _ => unreachable!(),
            }
        }
    }

    impl<A: Runtime> Runtime for WitOption<A> {
        type T = Option<A::T>;

        fn size() -> usize {
            4 + A::size()
        }

        fn new_by_runtime(caller: &Caller, input: Vec<WasmValue>) -> (Self::T, Vec<WasmValue>) {
            match input[0].to_i32() {
                0 => {
                    let size = A::size();
                    (None, input[1 + (size / 4)..].into())
                }
                1 => {
                    let (e, input) = A::new_by_runtime(caller, input[1..].into());
                    (Some(e), input)
                }
                _ => unreachable!(),
            }
        }
    }
}

#[derive(Debug)]
#[repr(C, u32)]
pub enum WitOption<T> {
    None,
    Some(T),
}

impl<T> From<Option<T>> for WitOption<T> {
    fn from(r: Option<T>) -> Self {
        match r {
            None => WitOption::None,
            Some(v) => WitOption::Some(v.into()),
        }
    }
}
impl<T> Into<Option<T>> for WitOption<T> {
    fn into(self: Self) -> Option<T> {
        match self {
            WitOption::None => None,
            WitOption::Some(v) => Some(v.into()),
        }
    }
}
