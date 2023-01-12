use anyhow::Error;
use serde::{Deserialize, Serialize};
use wasmedge_sdk::{
    config::{CommonConfigOptions, ConfigBuilder, HostRegistrationConfigOptions},
    host_function, Caller, Vm, WasmValue,
};
use witc_abi::*;
invoke_witc::wit_runtime!(export("./keyvalue.wit"));

static mut STORES: Vec<Store> = Vec::new();

struct Store {
    name: String,
    map: std::collections::HashMap<String, Vec<u8>>,
}
impl Store {
    fn new(name: String) -> Self {
        Self {
            name,
            map: std::collections::HashMap::new(),
        }
    }
}

fn open_store(name: String) -> Result<keyvalue, keyvalue_error> {
    println!("new store `{}`", name);
    unsafe {
        STORES.push(Store::new(name));
        Ok((STORES.len() - 1) as u32)
    }
}
fn store_set(store: keyvalue, key: String, value: Vec<u8>) -> Result<(), keyvalue_error> {
    let store = unsafe { &mut STORES[store as usize] };
    store.map.insert(key.clone(), value);
    println!("insert `{}` to store `{}`", key, store.name);
    Ok(())
}
fn store_get(store: keyvalue, key: String) -> Result<Vec<u8>, keyvalue_error> {
    let store = unsafe { &mut STORES[store as usize] };
    println!("get `{}` from store `{}`", key, store.name);
    store
        .map
        .get(key.as_str())
        .map(|v| v.to_vec())
        .ok_or(keyvalue_error::key_not_found(key))
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
