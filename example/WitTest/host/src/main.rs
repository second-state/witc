use abi::runtime::Runtime;
use abi::{WitOption, WitResult, WitString, WitVec};
use anyhow::Error;
use wasmedge_sdk::{
    config::{CommonConfigOptions, ConfigBuilder, HostRegistrationConfigOptions},
    error::HostFuncError,
    host_function, Caller, Memory, Vm, WasmValue,
};

pmacro::wit_runtime_export!("../test.wit");

#[host_function]
fn extern_exchange(caller: Caller, input: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    let (s, input) = WitString::new_by_runtime(&caller, input);
    println!("wasmedge: Get: {}", s);

    let (s2, input) = WitString::new_by_runtime(&caller, input);
    println!("wasmedge: Get Name: {}", s2);
    println!("wasmedge: Get Age: {}", input[0].to_i32());

    let mut mem = caller.memory(0).unwrap();
    // take last address+1
    let final_addr = mem.size() + 1;
    // grow a page size
    mem.grow(1).expect("fail to grow memory");
    // put the returned string into new address
    mem.write(s.as_bytes(), final_addr)
        .expect("fail to write returned string");

    Ok(vec![
        WasmValue::from_i32(final_addr as i32),
        WasmValue::from_i32(s.capacity() as i32),
        WasmValue::from_i32(s.len() as i32),
    ])
}

#[host_function]
fn extern_exchange_enum(
    _caller: Caller,
    input: Vec<WasmValue>,
) -> Result<Vec<WasmValue>, HostFuncError> {
    // definition:
    //
    // enum color { red, green, blue }
    //
    // enum gets numberic encoding
    match input[0].to_i32() {
        0 => println!("wasmedge: color: red"),
        1 => println!("wasmedge: color: green"),
        2 => println!("wasmedge: color: blue"),
        _ => unreachable!(),
    };
    Ok(vec![input[0]])
}

fn maybe_test(v: Option<u8>) -> Option<u8> {
    println!("wasmedge: Option<u8>: {:?}", v);
    v
}

#[host_function]
fn extern_maybe_test(
    caller: Caller,
    input: Vec<WasmValue>,
) -> Result<Vec<WasmValue>, HostFuncError> {
    let (o, _input) = WitOption::<u8>::new_by_runtime(&caller, input.clone());
    let r: WitOption<u8> = maybe_test(o).into();
    // let mem = caller.memory(0).unwrap();
    // r.allocate(mem);
    // let input = r.to_input();
    Ok(input)
}

#[host_function]
fn extern_send_result(
    caller: Caller,
    input: Vec<WasmValue>,
) -> Result<Vec<WasmValue>, HostFuncError> {
    let (r, _) = WitResult::<WitString, WitString>::new_by_runtime(&caller, input.clone());
    println!("wasmedge: Result<String, String>: {:?}", r);
    Ok(vec![WasmValue::from_i32(0)])
}

#[host_function]
fn extern_send_result2(
    caller: Caller,
    input: Vec<WasmValue>,
) -> Result<Vec<WasmValue>, HostFuncError> {
    let (r, _) = WitResult::<i8, u8>::new_by_runtime(&caller, input.clone());
    println!("wasmedge: Result<i8, u8>: {:?}", r);
    Ok(vec![WasmValue::from_i32(0)])
}

#[host_function]
fn extern_exchange_list(
    caller: Caller,
    input: Vec<WasmValue>,
) -> Result<Vec<WasmValue>, HostFuncError> {
    let (v, _) = WitVec::<u8>::new_by_runtime(&caller, input.clone());
    println!("wasmedge: Vec<u8>: {:?}", v);
    Ok(input)
}

#[host_function]
fn extern_exchange_list_string(
    caller: Caller,
    input: Vec<WasmValue>,
) -> Result<Vec<WasmValue>, HostFuncError> {
    let (v, _) = WitVec::<WitString>::new_by_runtime(&caller, input.clone());
    println!("wasmedge: Vec<String>: {:?}", v);
    Ok(input)
}

// pass-nat: func(n : nat) -> s32;
fn recur_print(mem: Memory, pair: (u32, u32)) {
    match pair.0 {
        0 => {
            println!("zero");
        }
        1 => {
            let res = mem.read(pair.1, 8).unwrap();
            print!("suc ");
            let l = u32::from_ne_bytes(res[0..4].try_into().unwrap());
            let r = u32::from_ne_bytes(res[4..8].try_into().unwrap());
            recur_print(mem, (l, r))
        }
        _ => unreachable!(),
    }
}
#[host_function]
fn extern_pass_nat(caller: Caller, input: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    recur_print(
        caller.memory(0).unwrap(),
        (input[0].to_i32() as u32, input[1].to_i32() as u32),
    );
    Ok(vec![WasmValue::from_i32(0)])
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
