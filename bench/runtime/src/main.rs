#![feature(test)]
extern crate test;

use anyhow::Error;
use serde::{Deserialize, Serialize};
use wasmedge_sdk::{
    config::{CommonConfigOptions, ConfigBuilder, HostRegistrationConfigOptions},
    host_function, Caller, Vm,
};
use witc_abi::*;
invoke_witc::wit_runtime!(export("base.wit"));

fn base(c1: c) -> c {
    c {
        name: c1.name,
        age: c1.age + 1,
    }
}

fn main() -> Result<(), Error> {
    let config = ConfigBuilder::new(CommonConfigOptions::default())
        .with_host_registration_config(HostRegistrationConfigOptions::default().wasi(true))
        .build()?;

    let vm = Vm::new(Some(config))?
        .register_import_module(wit_import_object()?)?
        .register_module_from_file("instance", "target/wasm32-wasi/release/instance.wasm")?;

    let result = vm.run_func(Some("instance"), "start", None)?;
    assert!(result[0].to_i32() == 2);

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use test::Bencher;
    #[bench]
    fn b1(b: &mut Bencher) {
        let config = ConfigBuilder::new(CommonConfigOptions::default())
            .with_host_registration_config(HostRegistrationConfigOptions::default().wasi(true))
            .build()
            .unwrap();

        let import_object = wit_import_object().unwrap();

        let vm = Vm::new(Some(config))
            .unwrap()
            .register_import_module(import_object)
            .unwrap()
            .register_module_from_file("instance", "../target/wasm32-wasi/release/instance.wasm")
            .unwrap();

        b.iter(|| {
            vm.run_func(Some("instance"), "start", None).unwrap();
        });
    }
}
