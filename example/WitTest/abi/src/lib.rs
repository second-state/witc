#[derive(Debug)]
#[repr(C)]
pub struct WitString {
    addr: *mut u8,
    cap: usize,
    len: usize,
}

impl From<&str> for WitString {
    fn from(s: &str) -> Self {
        Self {
            addr: s.as_ptr() as *mut u8,
            cap: s.len(),
            len: s.len(),
        }
    }
}
impl From<String> for WitString {
    fn from(s: String) -> Self {
        Self {
            addr: s.as_ptr() as *mut u8,
            cap: s.capacity(),
            len: s.len(),
        }
    }
}

impl Into<String> for WitString {
    fn into(self: Self) -> String {
        unsafe { String::from_raw_parts(self.addr, self.len, self.cap) }
    }
}

#[derive(Debug)]
#[repr(C, u8)]
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

#[derive(Debug)]
#[repr(C)]
pub struct WitVec<T> {
    ptr: *const T,
    cap: usize,
    len: usize,
}

impl From<Vec<String>> for WitVec<WitString> {
    fn from(r: Vec<String>) -> Self {
        WitVec {
            ptr: 0 as *const WitString,
            cap: r.capacity(),
            len: r.len(),
        }
    }
}
impl<T> From<Vec<T>> for WitVec<T> {
    fn from(r: Vec<T>) -> Self {
        WitVec {
            ptr: r.as_ptr(),
            cap: r.capacity(),
            len: r.len(),
        }
    }
}
impl Into<Vec<String>> for WitVec<WitString> {
    fn into(self: Self) -> Vec<String> {
        vec![]
    }
}
impl<T> Into<Vec<T>> for WitVec<T> {
    fn into(self: Self) -> Vec<T> {
        vec![]
    }
}

#[derive(Debug)]
#[repr(C, u8)]
pub enum WitResult<T, E> {
    Ok(T),
    Err(E),
}

impl<T> From<Result<T, String>> for WitResult<T, WitString> {
    fn from(r: Result<T, String>) -> Self {
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
