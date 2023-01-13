use wasmedge_sdk::{error::HostFuncError, host_function, Caller, WasmValue};

const EMPTY_STRING: String = String::new();
pub static mut BUCKET: [String; 100] = [EMPTY_STRING; 100];
pub static mut COUNT: usize = 0;

// allocate : (size : usize) -> (addr : i32)
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

// write : (addr : i32) -> (offset : i32) -> (byte : u8) -> ()
#[host_function]
pub fn write(_caller: Caller, values: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    let count = values[0].to_i32() as usize;
    unsafe {
        let string = &mut BUCKET[count];
        let offset = values[1].to_i32() as usize;
        let byte = values[2].to_i32() as u8;
        string.insert(offset, byte as char);
    }

    Ok(vec![])
}

// read : (addr : i32) -> (offset : i32) -> (byte : u8)
#[host_function]
pub fn read(_caller: Caller, values: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    let s = unsafe { &BUCKET[values[COUNT].to_i32() as usize] };
    let offset = values[1].to_i32() as usize;
    Ok(vec![WasmValue::from_i32(s.as_bytes()[offset] as i32)])
}
