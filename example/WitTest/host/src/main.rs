use anyhow::Error;
use wasmedge_sdk::{
    config::{CommonConfigOptions, ConfigBuilder, HostRegistrationConfigOptions},
    error::HostFuncError,
    host_function, Caller, ImportObjectBuilder, Vm, WasmValue,
};

fn load_string(caller: &Caller, addr: i32, size: i32) -> String {
    let mem = caller.memory(0).unwrap();
    let data = mem
        .read(addr as u32, size as u32)
        .expect("fail to get string");
    String::from_utf8_lossy(&data).to_string()
}

#[host_function]
fn exchange(caller: Caller, input: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    let s = load_string(&caller, input[0].to_i32(), input[2].to_i32());
    println!("wasmedge: Get: {}", s);

    let s2 = load_string(&caller, input[3].to_i32(), input[5].to_i32());
    println!("wasmedge: Get Name: {}", s2);
    println!("wasmedge: Get Age: {}", input[6].to_i32());

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
fn maybe_test(_caller: Caller, input: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    match input[0].to_i32() {
        1 => println!("wasmedge: Some({})", input[1].to_i32()),
        0 => println!("wasmedge: None"),
        _ => unreachable!(),
    };
    Ok(vec![input[0], input[1]])
}

#[host_function]
fn send_result(caller: Caller, input: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    match input[0].to_i32() {
        0 => println!("Ok({})", input[1].to_i32()),
        1 => println!("Err({:?}), {:?}", input[1], input[2]),
        addr => {
            let s = load_string(&caller, addr, input[2].to_i32());
            println!("Err({:?})", s)
        }
    }
    Ok(vec![WasmValue::from_i32(0)])
}

#[host_function]
fn send_result2(_caller: Caller, input: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    match input[0].to_i32() {
        0 => println!("Ok({:?})", input[1].to_i32()),
        1 => println!("Err({:?})", input[1].to_i32()),
        _ => unreachable!(),
    }
    Ok(vec![WasmValue::from_i32(0)])
}

fn main() -> Result<(), Error> {
    let config = ConfigBuilder::new(CommonConfigOptions::default())
        .with_host_registration_config(HostRegistrationConfigOptions::default().wasi(true))
        .build()?;

    let import = ImportObjectBuilder::new()
        .with_func::<(i32, i32, i32, i32, i32, i32, i32), (i32, i32, i32)>("exchange", exchange)?
        .with_func::<i32, i32>("exchange_enum", exchange_enum)?
        .with_func::<(i32, i32), (i32, i32)>("maybe_test", maybe_test)?
        .with_func::<(i32, i32, i32), i32>("send_result", send_result)?
        .with_func::<(i32, i32), i32>("send_result2", send_result2)?
        .build("wasmedge")?;
    let vm = Vm::new(Some(config))?
        .register_import_module(import)?
        .register_module_from_file("lib", "target/wasm32-wasi/release/lib.wasm")?;

    let result = vm.run_func(Some("lib"), "start", None)?;
    assert!(result[0].to_i32() == 0);

    Ok(())
}
