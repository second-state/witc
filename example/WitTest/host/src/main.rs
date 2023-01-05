use abi::runtime::Runtime;
use abi::{WitOption, WitResult, WitString, WitVec};
use anyhow::Error;
use wasmedge_sdk::{
    config::{CommonConfigOptions, ConfigBuilder, HostRegistrationConfigOptions},
    error::HostFuncError,
    host_function, Caller, Memory, Vm, WasmValue,
};

pmacro::wit_runtime_export!("../test.wit");

impl Runtime for person {
    fn size() -> usize {
        WitString::size() + 4
    }

    fn new_by_runtime(caller: &Caller, input: Vec<WasmValue>) -> (Self, Vec<WasmValue>) {
        let (field1, input) = WitString::new_by_runtime(&caller, input);
        let field2 = input[0].to_i32() as u32;
        (
            person {
                name: field1.into(),
                age: field2.into(),
            },
            input[1..].into(),
        )
    }

    fn allocate(self: Self, mem: &mut Memory) -> Vec<WasmValue> {
        todo!()
    }
}

fn exchange(s: String, p: person) -> String {
    println!("wasmedge: Get: {}", s);
    println!("wasmedge: Get Name: {}", p.name);
    println!("wasmedge: Get Age: {}", p.age);
    s
}
#[host_function]
fn extern_exchange(caller: Caller, input: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    let (s, input) = WitString::new_by_runtime(&caller, input);
    let (person, _input) = person::new_by_runtime(&caller, input);
    let s1 = exchange(s.into(), person.into());

    let mut mem = caller.memory(0).unwrap();
    // take last address+1
    let final_addr = mem.size() + 1;
    // grow a page size
    mem.grow(1).expect("fail to grow memory");
    // put the returned string into new address
    mem.write(s1.as_bytes(), final_addr)
        .expect("fail to write returned string");

    Ok(vec![
        WasmValue::from_i32(final_addr as i32),
        WasmValue::from_i32(s1.capacity() as i32),
        WasmValue::from_i32(s1.len() as i32),
    ])
}

fn exchange_enum(c: color) {
    println!("wasmedge: color: {:?}", c);
}
#[host_function]
fn extern_exchange_enum(
    caller: Caller,
    input: Vec<WasmValue>,
) -> Result<Vec<WasmValue>, HostFuncError> {
    let (c, _input) = color::new_by_runtime(&caller, input.clone());
    exchange_enum(c.into());
    Ok(input)
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
    let _r: WitOption<u8> = maybe_test(o.into()).into();
    // let mem = caller.memory(0).unwrap();
    // r.allocate(mem);
    // let input = r.to_input();
    Ok(input)
}

fn send_result(r: Result<String, String>) -> Result<String, String> {
    println!("wasmedge: Result<String, String>: {:?}", r);
    r
}
#[host_function]
fn extern_send_result(
    caller: Caller,
    input: Vec<WasmValue>,
) -> Result<Vec<WasmValue>, HostFuncError> {
    let (r, _) = WitResult::<WitString, WitString>::new_by_runtime(&caller, input.clone());
    let _ = send_result(r.into());
    Ok(vec![WasmValue::from_i32(0)])
}

fn send_result2(r: Result<i8, u8>) -> Result<i8, u8> {
    println!("wasmedge: Result<i8, u8>: {:?}", r);
    r
}
#[host_function]
fn extern_send_result2(
    caller: Caller,
    input: Vec<WasmValue>,
) -> Result<Vec<WasmValue>, HostFuncError> {
    let (r, _) = WitResult::<i8, u8>::new_by_runtime(&caller, input.clone());
    let _ = send_result2(r.into());
    Ok(vec![WasmValue::from_i32(0)])
}

fn exchange_list(v: Vec<u8>) -> Vec<u8> {
    println!("wasmedge: Vec<u8>: {:?}", v);
    v
}
#[host_function]
fn extern_exchange_list(
    caller: Caller,
    input: Vec<WasmValue>,
) -> Result<Vec<WasmValue>, HostFuncError> {
    let (v, _) = WitVec::<u8>::new_by_runtime(&caller, input.clone());
    let _ = exchange_list(v.into());
    Ok(input)
}

fn exchange_list_string(v: Vec<String>) -> Vec<String> {
    println!("wasmedge: Vec<String>: {:?}", v);
    v
}
#[host_function]
fn extern_exchange_list_string(
    caller: Caller,
    input: Vec<WasmValue>,
) -> Result<Vec<WasmValue>, HostFuncError> {
    let (v, _) = WitVec::<WitString>::new_by_runtime(&caller, input.clone());
    let _ = exchange_list_string(v.into());
    Ok(input)
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

    fn allocate(self: Self, mem: &mut Memory) -> Vec<WasmValue> {
        todo!()
    }
}

#[host_function]
fn extern_pass_nat(caller: Caller, input: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    let (n, _) = nat::new_by_runtime(&caller, input);
    println!("{:?}", n);
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
