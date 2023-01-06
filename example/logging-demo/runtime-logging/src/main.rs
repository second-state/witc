use anyhow::Error;
use wasmedge_sdk::{
    config::{CommonConfigOptions, ConfigBuilder, HostRegistrationConfigOptions},
    host_function, Caller, Vm, WasmValue,
};
use witc_abi::runtime::Runtime;
use witc_abi::WitString;

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
