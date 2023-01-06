use anyhow::Error;
use wasmedge_sdk::{
    config::{CommonConfigOptions, ConfigBuilder, HostRegistrationConfigOptions},
    error::HostFuncError,
    host_function, Caller, Vm, WasmValue,
};
use witc_abi::runtime::Runtime;
use witc_abi::{WitOption, WitResult, WitString, WitVec};

invoke_witc::wit_runtime_export!("./logging.wit");

impl Runtime for pack {
    fn size() -> usize {
        WitString::size() + 4
    }

    fn new_by_runtime(caller: &Caller, input: Vec<WasmValue>) -> (Self, Vec<WasmValue>) {
        let (field1, input) = WitString::new_by_runtime(&caller, input);
        let field2 = input[0].to_i32() as u32;
        (
            pack {
                message: field1.into(),
                level: field2.into(),
            },
            input[1..].into(),
        )
    }
}

fn log(p: pack) -> u32 {
    println!("[{}]: {}", p.level, p.message);
    0
}

#[host_function]
fn extern_log(caller: Caller, input: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    let (p, _) = pack::new_by_runtime(&caller, input);
    let r = log(p);
    Ok(vec![WasmValue::from_i32(r as i32)])
}

fn main() -> Result<(), Error> {
    let config = ConfigBuilder::new(CommonConfigOptions::default())
        .with_host_registration_config(HostRegistrationConfigOptions::default().wasi(true))
        .build()?;

    let vm = Vm::new(Some(config))?
        .register_import_module(wit_import_object()?)?
        .register_module_from_file(
            "instance-service",
            "target/wasm32-wasi/release/instance_service.wasm",
        )?;

    let result = vm.run_func(Some("instance-service"), "start", None)?;
    assert!(result[0].to_i32() == 0);

    Ok(())
}
