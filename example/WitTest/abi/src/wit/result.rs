#[cfg(not(target_arch = "wasm32"))]
mod implement {
    use super::*;
    use crate::runtime::Runtime;
    use core::cmp::max;
    use wasmedge_sdk::{Caller, WasmValue};

    impl<A: Runtime, E: Runtime> Runtime for WitResult<A, E> {
        type T = Result<A::T, E::T>;

        fn size() -> usize {
            4 + max(A::size(), E::size())
        }

        fn new_by_runtime(caller: &Caller, input: Vec<WasmValue>) -> (Self::T, Vec<WasmValue>) {
            let skip = Self::size() / 4;
            match input[0].to_i32() {
                0 => {
                    let (a, _) = A::new_by_runtime(caller, input[1..].into());
                    (Ok(a), input[skip..].into())
                }
                1 => {
                    let (e, _) = E::new_by_runtime(caller, input[1..].into());
                    (Err(e), input[skip..].into())
                }
                _ => unreachable!(),
            }
        }
    }
}

use super::string::WitString;

#[derive(Debug)]
#[repr(C, u32)]
pub enum WitResult<T, E> {
    Ok(T),
    Err(E),
}

impl<T> From<Result<T, &str>> for WitResult<T, WitString> {
    fn from(r: Result<T, &str>) -> Self {
        match r {
            Ok(ok) => WitResult::Ok(ok.into()),
            Err(err) => WitResult::Err(err.into()),
        }
    }
}
impl From<Result<String, String>> for WitResult<WitString, WitString> {
    fn from(r: Result<String, String>) -> Self {
        match r {
            Ok(ok) => WitResult::Ok(ok.into()),
            Err(err) => WitResult::Err(err.into()),
        }
    }
}
impl<T> From<Result<T, String>> for WitResult<T, WitString> {
    fn from(r: Result<T, String>) -> Self {
        match r {
            Ok(ok) => WitResult::Ok(ok.into()),
            Err(err) => WitResult::Err(err.into()),
        }
    }
}
impl<E> From<Result<&str, E>> for WitResult<WitString, E> {
    fn from(r: Result<&str, E>) -> Self {
        match r {
            Ok(ok) => WitResult::Ok(ok.into()),
            Err(err) => WitResult::Err(err.into()),
        }
    }
}
impl<E> From<Result<String, E>> for WitResult<WitString, E> {
    fn from(r: Result<String, E>) -> Self {
        match r {
            Ok(ok) => WitResult::Ok(ok.into()),
            Err(err) => WitResult::Err(err.into()),
        }
    }
}

impl<T, E> From<Result<T, E>> for WitResult<T, E> {
    fn from(r: Result<T, E>) -> Self {
        match r {
            Ok(ok) => WitResult::Ok(ok.into()),
            Err(err) => WitResult::Err(err.into()),
        }
    }
}

#[test]
fn result_abi() {
    let r = Ok(1);
    let r2: WitResult<i32, i32> = r.into();
    println!("{:?}", r2);

    let r: Result<String, String> = Ok("test".to_string());
    let r2: WitResult<WitString, WitString> = r.into();
    println!("{:?}", r2);
}
