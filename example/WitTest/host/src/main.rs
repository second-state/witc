use anyhow::Error;
use libc;
use serde::{Deserialize, Serialize};
use wasmedge_sdk::{
    config::{CommonConfigOptions, ConfigBuilder, HostRegistrationConfigOptions},
    error::HostFuncError,
    host_function, Caller, Vm, WasmValue,
};
invoke_witc::wit_runtime_export!("../test.wit");

// allocate : (size : usize) -> (addr : i32)
#[host_function]
fn allocate(_caller: Caller, values: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    let size = values[0].to_i32() as usize;

    let addr = unsafe { libc::malloc(std::mem::size_of::<u8>() * size as libc::size_t) as *mut u8 };

    println!("allocate to addr {}", addr as usize);
    Ok(vec![WasmValue::from_i32(addr as i32)])
}

// write : (addr : i32) -> (offset : i32) -> (byte : u8) -> ()
#[host_function]
fn write(_caller: Caller, values: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    let offset = values[1].to_i32() as usize;
    let addr = (values[0].to_i32() as usize + offset) as *mut u8;
    println!("write to addr {}", values[0].to_i32() as usize);

    unsafe {
        let byte = values[2].to_i32() as u8;
        *addr = byte;
    }

    Ok(vec![])
}

// read : (addr : i32) -> (offset : i32) -> (byte : u8)
#[host_function]
fn read(_caller: Caller, values: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    let offset = values[1].to_i32() as usize;
    let addr = (values[0].to_i32() as usize + offset) as *mut u8;
    Ok(vec![WasmValue::from_i32(unsafe { *addr } as i32)])
}

fn exchange(s: String, p: person) -> u32 {
    println!("wasmedge: Get: {}", s);
    println!("wasmedge: Get Name: {}", p.name);
    println!("wasmedge: Get Age: {}", p.age);
    0
}

fn exchange_enum(c: color) -> u32 {
    println!("wasmedge: color: {:?}", c);
    0
}

fn maybe_test(v: Option<u8>) -> u32 {
    println!("wasmedge: Option<u8>: {:?}", v);
    0
}

fn send_result(r: Result<String, String>) -> u32 {
    println!("wasmedge: Result<String, String>: {:?}", r);
    0
}

fn send_result2(r: Result<i8, u8>) -> u32 {
    println!("wasmedge: Result<i8, u8>: {:?}", r);
    0
}

fn exchange_list(v: Vec<u8>) -> u32 {
    println!("wasmedge: Vec<u8>: {:?}", v);
    0
}

fn exchange_list_string(v: Vec<String>) -> u32 {
    println!("wasmedge: Vec<String>: {:?}", v);
    0
}

fn pass_nat(n: nat) -> u32 {
    println!("{:?}", n);
    0
}

fn main() -> Result<(), Error> {
    let config = ConfigBuilder::new(CommonConfigOptions::default())
        .with_host_registration_config(HostRegistrationConfigOptions::default().wasi(true))
        .build()?;

    let vm = Vm::new(Some(config))?
        .register_import_module(wit_import_object()?)?
        .register_module_from_file("lib", "target/wasm32-wasi/release/lib.wasm")?;

    let result = vm.run_func(Some("lib"), "start", None)?;
    assert!(result[0].to_i32() == 0);

    Ok(())
}
