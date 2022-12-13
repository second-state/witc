use anyhow::Error;
use wasmedge_sdk::{
    config::{CommonConfigOptions, ConfigBuilder, HostRegistrationConfigOptions},
    error::HostFuncError,
    host_function, Caller, ImportObjectBuilder, Vm, WasmValue,
};

fn load_string(caller: &Caller, addr: i32, len: i32) -> String {
    let mem = caller.memory(0).unwrap();
    let data = mem
        .read(addr as u32, len as u32)
        .expect("fail to get string");
    String::from_utf8_lossy(&data).to_string()
}

fn load_vec(caller: &Caller, addr: i32, len: i32) -> Vec<u8> {
    let mem = caller.memory(0).unwrap();
    let data = mem
        .read(addr as u32, len as u32)
        .expect("fail to get vector");
    data
}

fn load_vec_string(caller: &Caller, addr: i32, len: i32) -> Vec<String> {
    // since String is (i32, i32, i32)'s 3-tuple
    // but the data is Vec<u8>
    // 12 times
    let mem = caller.memory(0).unwrap();
    let data = mem
        .read(addr as u32, (len * 12) as u32)
        .expect("fail to get vector");

    let mut r_v = vec![];
    for i in 0..(len as usize) {
        let i = i * 12;
        let s_addr = i32::from_le_bytes(data[i..(i + 4)].try_into().unwrap());
        let _s_cap = i32::from_le_bytes(data[(i + 4)..(i + 8)].try_into().unwrap());
        let s_len = i32::from_le_bytes(data[(i + 8)..(i + 12)].try_into().unwrap());
        let s = load_string(caller, s_addr, s_len);
        r_v.push(s);
    }
    r_v
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
        1 => println!("wasmedge: Option<u8>: Some({})", input[1].to_i32()),
        0 => println!("wasmedge: Option<u8>: None"),
        _ => unreachable!(),
    };
    Ok(vec![input[0], input[1]])
}

#[host_function]
fn send_result(caller: Caller, input: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    match input[0].to_i32() {
        0 => println!("wasmedge: Result<i32, String>: Ok({})", input[4].to_i32()),
        1 => {
            println!("{:?}", input[1..].len());
            println!("{:?}", input[1..].into_iter());
            // println!("wasmedge: Result<i32, String>: Err({:?})", s)
        }
        _ => unreachable!(),
    }
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
    let addr = input[0].to_i32();
    let _cap = input[1].to_i32();
    let len = input[2].to_i32();
    println!("wasmedge: Vec<u8>: {:?}", load_vec(&caller, addr, len));
    Ok(input)
}

#[host_function]
fn exchange_list_string(
    caller: Caller,
    input: Vec<WasmValue>,
) -> Result<Vec<WasmValue>, HostFuncError> {
    let addr = input[0].to_i32();
    let _cap = input[1].to_i32();
    let len = input[2].to_i32();
    println!(
        "wasmedge: Vec<String>: {:?}",
        load_vec_string(&caller, addr, len)
    );
    Ok(input)
}

// pass-nat: func(n : nat) -> s32;
#[host_function]
fn pass_nat(_caller: Caller, input: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    println!("{:?}", input);
    match input[0].to_i32() {
        0 => println!("zero"),
        x => println!("{}", x),
    }
    Ok(vec![WasmValue::from_i32(0)])
}

fn main() -> Result<(), Error> {
    let config = ConfigBuilder::new(CommonConfigOptions::default())
        .with_host_registration_config(HostRegistrationConfigOptions::default().wasi(true))
        .build()?;

    let import = ImportObjectBuilder::new()
        .with_func::<(i32, i32, i32, i32, i32, i32, i32), (i32, i32, i32)>(
            "extern_exchange",
            exchange,
        )?
        .with_func::<i32, i32>("extern_exchange_enum", exchange_enum)?
        .with_func::<(i32, i32), (i32, i32)>("extern_maybe_test", maybe_test)?
        .with_func::<(
            i32,
            i32,
            i32,
            i32,
            i32,
            i32,
            i32,
            i32,
            i32,
            i32,
            i32,
            i32,
            i32,
            i32,
            i32,
            i32,
        ), i32>("extern_send_result", send_result)?
        .with_func::<(i32, i32), i32>("extern_send_result2", send_result2)?
        .with_func::<(i32, i32, i32), (i32, i32, i32)>("extern_exchange_list", exchange_list)?
        .with_func::<(i32, i32, i32), (i32, i32, i32)>(
            "extern_exchange_list_string",
            exchange_list_string,
        )?
        .with_func::<(i32, i32), i32>("extern_pass_nat", pass_nat)?
        .build("wasmedge")?;
    let vm = Vm::new(Some(config))?
        .register_import_module(import)?
        .register_module_from_file("lib", "target/wasm32-wasi/release/lib.wasm")?;

    let result = vm.run_func(Some("lib"), "start", None)?;
    assert!(result[0].to_i32() == 0);

    Ok(())
}
