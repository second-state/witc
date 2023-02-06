use anyhow::Error;
use wasmedge_sdk::{
    config::{CommonConfigOptions, ConfigBuilder, HostRegistrationConfigOptions},
    error::HostFuncError,
    host_function, Caller, ImportObjectBuilder, Vm, WasmValue,
};
fn load_string(caller: &Caller, addr: u32, size: u32) -> String {
    let mem = caller.memory(0).unwrap();
    let data = mem.read(addr, size).expect("fail to get string");
    String::from_utf8_lossy(&data).to_string()
}
#[host_function]
fn runtime_println(caller: Caller, input: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    let s = load_string(&caller, input[0].to_i32() as u32, input[1].to_i32() as u32);
    println!("{}", s);
    Ok(vec![])
}

fn main() -> Result<(), Error> {
    let config = ConfigBuilder::new(CommonConfigOptions::default())
        .with_host_registration_config(HostRegistrationConfigOptions::default().wasi(true))
        .build()?;

    let import = ImportObjectBuilder::new()
        .with_func::<(i32, i32), ()>("runtime_println", runtime_println)?
        .build("runtime")?;
    let vm = Vm::new(Some(config))?
        .register_import_module(import)?
        .register_module_from_file(
            "instance_logging",
            "target/wasm32-wasi/release/instance_logging.wasm",
        )?
        .register_module_from_file(
            "instance-service",
            "target/wasm32-wasi/release/instance_service.wasm",
        )?;

    let result = vm.run_func(Some("instance-service"), "start", None)?;
    assert!(result[0].to_i32() == 0);

    Ok(())
}
