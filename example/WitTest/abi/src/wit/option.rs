#[derive(Debug)]
#[repr(C, u32)]
pub enum WitOption<T> {
    None,
    Some(T),
}

#[cfg(not(target_arch = "wasm32"))]
mod implement {
    use super::*;
    use crate::gen_all;
    use crate::runtime::Runtime;
    use wasmedge_sdk::{Caller, Memory, WasmValue};

    macro_rules! impl_option {
        ($t1:ty) => {
            impl Runtime for WitOption<$t1> {
                fn size() -> usize {
                    4 + 4
                }
                fn new_by_runtime(
                    _caller: &Caller,
                    input: Vec<WasmValue>,
                ) -> (Self, Vec<WasmValue>) {
                    match input[0].to_i32() {
                        0 => (WitOption::None, input[2..].into()),
                        1 => (WitOption::Some(input[1].to_i32() as $t1), input[2..].into()),
                        _ => unreachable!(),
                    }
                }
                fn allocate(self: Self, mem: &mut Memory) -> Vec<WasmValue> {
                    let s: Option<$t1> = self.into();

                    match s {
                        None => vec![WasmValue::from_i32(0)],
                        Some(a) => vec![WasmValue::from_i32(1), WasmValue::from_i32(a as i32)],
                    }
                }
            }
        };
    }

    gen_all!(impl_option: u8 u16 u32);

    impl<A> Runtime for WitOption<A>
    where
        A: Runtime,
    {
        fn size() -> usize {
            4 + A::size()
        }

        fn new_by_runtime(caller: &Caller, input: Vec<WasmValue>) -> (Self, Vec<WasmValue>) {
            match input[0].to_i32() {
                0 => {
                    let size = A::size();
                    (WitOption::None, input[1 + (size / 4)..].into())
                }
                1 => {
                    let (e, input) = A::new_by_runtime(caller, input[1..].into());
                    (WitOption::Some(e), input)
                }
                _ => unreachable!(),
            }
        }

        fn allocate(self: Self, mem: &mut Memory) -> Vec<WasmValue> {
            let s: Option<A> = self.into();

            match s {
                None => {
                    let v = vec![WasmValue::from_i32(0)];
                    v
                }
                Some(a) => {
                    let v = vec![WasmValue::from_i32(1)];
                    v.append(&mut a.allocate(mem));
                    v
                }
            }
        }
    }
}

impl<WT, T> From<Option<T>> for WitOption<WT>
where
    T: Into<WT>,
{
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
