use std::marker::PhantomData;

use super::string::WitString;

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
