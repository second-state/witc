#![feature(vec_into_raw_parts)]
use std::marker::PhantomData;

#[derive(Debug)]
#[repr(C)]
pub struct WitString {
    addr: *mut u8,
    cap: usize,
    len: usize,
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
