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

    let r = Ok("test".to_string());
    let r2: WitResult<WitString, WitString> = r.into();
    println!("{:?}", r2);
}
