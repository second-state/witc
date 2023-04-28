use anyhow::Error;
use serde::{Deserialize, Serialize};
use wasmedge_sdk::{
    config::{CommonConfigOptions, ConfigBuilder, HostRegistrationConfigOptions},
    host_function, Caller, Vm,
};
use witc_abi::runtime::*;
invoke_witc::wit_runtime!(export("./test.wit"));

fn set_name(p: person, name: String) -> person {
    println!("wasmedge: Person: {:?}", p);
    person { name, age: p.age }
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
        .register_import_module(witc_abi::runtime::component_model_wit_object()?)?
        .register_import_module(wit_import_object()?)?
        .register_module_from_file("lib", "target/wasm32-wasi/release/lib.wasm")?;

    let result = vm.run_func(Some("lib"), "start", None)?;
    assert!(result[0].to_i32() == 0);

    Ok(())
}
