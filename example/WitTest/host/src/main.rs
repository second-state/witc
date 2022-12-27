use abi::runtime::Runtime;
use abi::{WitOption, WitResult, WitString, WitVec};
use anyhow::Error;
use wasmedge_sdk::{
    config::{CommonConfigOptions, ConfigBuilder, HostRegistrationConfigOptions},
    error::HostFuncError,
    host_function, Caller, ImportObjectBuilder, Memory, Vm, WasmValue,
};
use wasmedge_sdk::{ImportObject, WasmEdgeResult};

#[host_function]
fn exchange(caller: Caller, input: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
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
fn exchange_enum(_caller: Caller, input: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
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

#[host_function]
fn maybe_test(caller: Caller, input: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    let (o, _) = WitOption::<u8>::new_by_runtime(&caller, input.clone());
    println!("wasmedge: Option<u8>: {:?}", o);
    Ok(input)
}

#[host_function]
fn send_result(caller: Caller, input: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    let (r, _) = WitResult::<WitString, WitString>::new_by_runtime(&caller, input.clone());
    println!("wasmedge: Result<String, String>: {:?}", r);
    Ok(vec![WasmValue::from_i32(0)])
}

#[host_function]
fn send_result2(_caller: Caller, input: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    match input[0].to_i32() {
        0 => println!("wasmedge: Result<i8, u8>: Ok({:?})", input[1].to_i32()),
        1 => println!("wasmedge: Result<i8, u8>: Err({:?})", input[1].to_i32()),
        _ => unreachable!(),
    }
    Ok(vec![WasmValue::from_i32(0)])
}

#[host_function]
fn exchange_list(caller: Caller, input: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    let (v, _) = WitVec::<u8>::new_by_runtime(&caller, input.clone());
    println!("wasmedge: Vec<u8>: {:?}", v);
    Ok(input)
}

#[host_function]
fn exchange_list_string(
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
fn pass_nat(caller: Caller, input: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    recur_print(
        caller.memory(0).unwrap(),
        (input[0].to_i32() as u32, input[1].to_i32() as u32),
    );
    Ok(vec![WasmValue::from_i32(0)])
}

fn wit_import_object() -> WasmEdgeResult<ImportObject> {
    Ok(ImportObjectBuilder::new()
        .with_func::<(i32, i32, i32, i32, i32, i32, i32), (i32, i32, i32)>(
            "extern_exchange",
            exchange,
        )?
        .with_func::<i32, i32>("extern_exchange_enum", exchange_enum)?
        .with_func::<(i32, i32), (i32, i32)>("extern_maybe_test", maybe_test)?
        .with_func::<(i32, i32, i32, i32), i32>("extern_send_result", send_result)?
        .with_func::<(i32, i32), i32>("extern_send_result2", send_result2)?
        .with_func::<(i32, i32, i32), (i32, i32, i32)>("extern_exchange_list", exchange_list)?
        .with_func::<(i32, i32, i32), (i32, i32, i32)>(
            "extern_exchange_list_string",
            exchange_list_string,
        )?
        .with_func::<(i32, i32), i32>("extern_pass_nat", pass_nat)?
        .build("wasmedge")?)
}

fn main() -> Result<(), Error> {
    let config = ConfigBuilder::new(CommonConfigOptions::default())
        .with_host_registration_config(HostRegistrationConfigOptions::default().wasi(true))
        .build()?;

    let import = wit_import_object()?;
    let vm = Vm::new(Some(config))?
        .register_import_module(import)?
        .register_module_from_file("lib", "target/wasm32-wasi/release/lib.wasm")?;

    let result = vm.run_func(Some("lib"), "start", None)?;
    assert!(result[0].to_i32() == 0);

    Ok(())
}
