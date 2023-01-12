use anyhow::Error;
use wasmedge_sdk::{
    config::{CommonConfigOptions, ConfigBuilder, HostRegistrationConfigOptions},
    Vm,
};

fn main() -> Result<(), Error> {
    let config = ConfigBuilder::new(CommonConfigOptions::default())
        .with_host_registration_config(HostRegistrationConfigOptions::default().wasi(true))
        .build()?;

    let vm = Vm::new(Some(config))?
        .register_module_from_file(
            "instance-logging",
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
