use anyhow::Error;
use serde::{Deserialize, Serialize};
use wasmedge_sdk::{
    config::{CommonConfigOptions, ConfigBuilder, HostRegistrationConfigOptions},
    Vm,
};
use witc_abi::*;
// invoke_witc::wit_runtime!(import("./test.wit"));

// gen: part
fn id_string(vm: &Vm, s: String) -> String {
    let cfg = CallingConfig::new(vm, "instance");

    let args = cfg.put_to_remote(&s);
    let r = cfg.run("extern_id_string", args);

    let result_len = r[1].to_i32() as usize;
    let mut s = String::with_capacity(result_len);
    cfg.read_from_remote(&mut s, r[0], result_len)
}

fn main() -> Result<(), Error> {
    let config = ConfigBuilder::new(CommonConfigOptions::default())
        .with_host_registration_config(HostRegistrationConfigOptions::default().wasi(true))
        .build()?;

    let vm = Vm::new(Some(config))?.register_module_from_file(
        "instance",
        "target/wasm32-wasi/release/instance_export.wasm",
    )?;

    println!("{}", id_string(&vm, "Hello".into()));

    Ok(())
}
