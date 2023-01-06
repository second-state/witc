use anyhow::Error;
use wasmedge_sdk::{
    config::{CommonConfigOptions, ConfigBuilder, HostRegistrationConfigOptions},
    host_function, Caller, Vm, WasmValue,
};
use witc_abi::runtime::Runtime;
use witc_abi::{WitOption, WitResult, WitString, WitVec};

invoke_witc::wit_runtime_export!("../test.wit");

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

impl Runtime for nat {
    fn size() -> usize {
        8
    }

    fn new_by_runtime(caller: &Caller, input: Vec<WasmValue>) -> (Self, Vec<WasmValue>) {
        let mem = caller.memory(0).unwrap();
        match input[0].to_i32() {
            0 => (nat::zero, input[2..].into()),
            1 => {
                let data = mem
                    .read(input[1].to_i32() as u32, Self::size() as u32)
                    .unwrap();
                let (res, input) = Self::new_by_runtime(
                    caller,
                    vec![
                        WasmValue::from_i32(i32::from_ne_bytes(data[0..4].try_into().unwrap())),
                        WasmValue::from_i32(i32::from_ne_bytes(data[4..8].try_into().unwrap())),
                    ],
                );
                (nat::suc(Box::new(res)), input)
            }
            _ => unreachable!(),
        }
    }
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
