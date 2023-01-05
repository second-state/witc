#[derive(Debug)]
#[repr(C, u32)]
pub enum WitResult<T, E> {
    Ok(T),
    Err(E),
}

#[cfg(not(target_arch = "wasm32"))]
mod implement {
    use super::*;
    use crate::for_all_pairs;
    use crate::runtime::Runtime;
    use core::cmp::max;
    use wasmedge_sdk::{Caller, Memory, WasmValue};

    macro_rules! impl_result {
        ($t1:ty, $t2:ty) => {
            impl Runtime for WitResult<$t1, $t2> {
                fn size() -> usize {
                    4 + 4
                }
                fn new_by_runtime(
                    _caller: &Caller,
                    input: Vec<WasmValue>,
                ) -> (Self, Vec<WasmValue>) {
                    match input[0].to_i32() {
                        0 => {
                            let a = input[1].to_i32() as $t1;
                            (WitResult::Ok(a), input[2..].into())
                        }
                        1 => {
                            let a = input[1].to_i32() as $t2;
                            (WitResult::Err(a), input[2..].into())
                        }
                        _ => unreachable!(),
                    }
                }
                fn allocate(self: Self, mem: &mut Memory) -> Vec<WasmValue> {
                    let s: Result<$t1, $t2> = self.into();

                    match s {
                        Ok(a) => vec![WasmValue::from_i32(0), WasmValue::from_i32(a as i32)],
                        Err(e) => vec![WasmValue::from_i32(1), WasmValue::from_i32(e as i32)],
                    }
                }
            }
        };
    }

    for_all_pairs!(impl_result: i8 u8 i16 u16 i32 u32);

    impl<A, E> Runtime for WitResult<A, E>
    where
        A: Runtime,
        E: Runtime,
    {
        fn size() -> usize {
            4 + max(A::size(), E::size())
        }

        fn new_by_runtime(caller: &Caller, input: Vec<WasmValue>) -> (Self, Vec<WasmValue>) {
            let skip = Self::size() / 4;
            match input[0].to_i32() {
                0 => {
                    let (a, _) = A::new_by_runtime(caller, input[1..].into());
                    (WitResult::Ok(a), input[skip..].into())
                }
                1 => {
                    let (e, _) = E::new_by_runtime(caller, input[1..].into());
                    (WitResult::Err(e), input[skip..].into())
                }
                _ => unreachable!(),
            }
        }

        fn allocate(self: Self, mem: &mut Memory) -> Vec<WasmValue> {
            let s: Result<A, E> = self.into();

            match s {
                Ok(a) => {
                    let mut v = vec![WasmValue::from_i32(0)];
                    v.append(&mut a.allocate(mem));
                    v
                }
                Err(e) => {
                    let mut v = vec![WasmValue::from_i32(1)];
                    v.append(&mut e.allocate(mem));
                    v
                }
            }
        }
    }
}

impl<WT, WE, T, E> From<Result<T, E>> for WitResult<WT, WE>
where
    T: Into<WT>,
    E: Into<WE>,
{
    fn from(r: Result<T, E>) -> Self {
        match r {
            Ok(ok) => WitResult::Ok(ok.into()),
            Err(err) => WitResult::Err(err.into()),
        }
    }
}

impl<WT, WE, T, E> Into<Result<T, E>> for WitResult<WT, WE>
where
    WT: Into<T>,
    WE: Into<E>,
{
    fn into(self: Self) -> Result<T, E> {
        match self {
            WitResult::Ok(ok) => Ok(ok.into()),
            WitResult::Err(err) => Err(err.into()),
        }
    }
}

#[cfg(test)]
mod test {
    use super::*;
    use crate::wit::string::WitString;

    #[test]
    fn result_abi() {
        let r: Result<i32, i32> = Ok(1);
        let r2: WitResult<i32, i32> = r.into();
        println!("{:?}", r2);

        let r: Result<String, String> = Ok("test".to_string());
        let r2: WitResult<WitString, WitString> = r.into();
        println!("{:?}", r2);
    }
}
