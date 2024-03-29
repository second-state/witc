use anyhow::Error;
use serde::{Deserialize, Serialize};
use wasmedge_sdk::{
    config::{CommonConfigOptions, ConfigBuilder, HostRegistrationConfigOptions},
    VmBuilder,
};
invoke_witc::wit_runtime!(import(lights = "traffic-lights.wit"));

fn main() -> Result<(), Error> {
    let config = ConfigBuilder::new(CommonConfigOptions::default())
        .with_host_registration_config(HostRegistrationConfigOptions::default().wasi(true))
        .build()?;

    let vm = VmBuilder::new()
        .with_config(config)
        .build()?
        .register_import_module(witc_abi::runtime::component_model_wit_object()?)?
        .register_module_from_file("lights", "target/wasm32-wasi/release/instance_lights.wasm")?;

    let start = light::green;
    let r = toggle(&vm, start);
    println!("{:?}", r);
    let r = toggle(&vm, r);
    println!("{:?}", r);
    let r = toggle(&vm, r);
    println!("{:?}", r);
    let r = toggle(&vm, r);
    println!("{:?}", r);

    Ok(())
}
