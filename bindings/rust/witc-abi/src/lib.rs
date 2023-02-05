use serde::{Deserialize, Serialize};
use wasmedge_sdk::{error::HostFuncError, host_function, Caller, Vm, WasmValue};

const EMPTY_STRING: String = String::new();
pub static mut BUCKET: [String; 100] = [EMPTY_STRING; 100];
pub static mut COUNT: usize = 0;

// runtime export
#[host_function]
pub fn allocate(_caller: Caller, values: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    let size = values[0].to_i32() as usize;

    let s = String::with_capacity(size);

    unsafe {
        BUCKET[COUNT] = s;
        let count = COUNT;
        COUNT += 1;

        Ok(vec![WasmValue::from_i32(count as i32)])
    }
}
#[host_function]
pub fn write(_caller: Caller, values: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    let count = values[0].to_i32() as usize;
    unsafe {
        let s = &mut BUCKET[count];
        // TODO: read as u64, and decode big endian
        let byte = values[1].to_i32() as u8;
        s.push(byte as char);
    }

    Ok(vec![])
}
#[host_function]
pub fn read(_caller: Caller, values: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    let s: &String = unsafe { &BUCKET[values[COUNT].to_i32() as usize] };
    let offset = values[1].to_i32() as usize;
    // TODO: return u64, encode as big endian
    Ok(vec![WasmValue::from_i32(s.as_bytes()[offset] as i32)])
}

// runtime import
pub struct CallingConfig<'a> {
    vm: &'a Vm,
    mod_name: &'a str,
}

impl<'a> CallingConfig<'a> {
    pub fn new(vm: &'a Vm, mod_name: &'a str) -> Self {
        Self { vm, mod_name }
    }

    pub fn run(self: &Self, fn_name: &str, values: Vec<WasmValue>) -> Vec<WasmValue> {
        self.vm
            .run_func(Some(self.mod_name), fn_name, values)
            .unwrap()
    }

    pub fn put_to_remote<A>(self: &Self, a: &A) -> Vec<WasmValue>
    where
        A: Serialize,
    {
        let encode_json = serde_json::to_string(a).unwrap();

        let han_a = self.run(
            "allocate",
            vec![WasmValue::from_i32(encode_json.len() as i32)],
        )[0];
        for c in encode_json.bytes() {
            self.run("write", vec![han_a, WasmValue::from_i32(c as i32)]);
        }

        vec![han_a, WasmValue::from_i32(encode_json.len() as i32)]
    }
}

impl<'a, 'b> CallingConfig<'a> {
    pub fn read_from_remote<A>(
        self: &Self,
        s: &'b mut String,
        result_han: WasmValue,
        result_len: usize,
    ) -> A
    where
        A: Deserialize<'b>,
    {
        for i in 0..result_len {
            let r = self.run("read", vec![result_han, WasmValue::from_i32(i as i32)]);
            s.push(char::from_u32(r[0].to_i32() as u32).unwrap())
        }
        serde_json::from_str(s).unwrap()
    }
}
