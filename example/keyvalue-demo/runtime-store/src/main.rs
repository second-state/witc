use anyhow::Error;
use serde::{Deserialize, Serialize};
use wasmedge_sdk::{
    config::{CommonConfigOptions, ConfigBuilder, HostRegistrationConfigOptions},
    VmBuilder,
};
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

fn keyvalue_open(name: String) -> Result<keyvalue, keyvalue_error> {
    println!("new store `{}`", name);
    unsafe {
        STORES.push(Store::new(name));
        Ok((STORES.len() - 1) as u32)
    }
}
fn keyvalue_set(handle: keyvalue, key: String, value: Vec<u8>) -> Result<(), keyvalue_error> {
    let store = unsafe { &mut STORES[handle as usize] };
    println!("insert `{}` to store `{}`", key, store.name);
    store.map.insert(key, value);
    Ok(())
}
fn keyvalue_get(handle: keyvalue, key: String) -> Result<Vec<u8>, keyvalue_error> {
    let store = unsafe { &mut STORES[handle as usize] };
    println!("get `{}` from store `{}`", key, store.name);
    store
        .map
        .get(key.as_str())
        .map(|v| v.to_vec())
        .ok_or(keyvalue_error::key_not_found(key))
}
fn keyvalue_keys(handle: keyvalue) -> Result<Vec<String>, keyvalue_error> {
    let store = unsafe { &mut STORES[handle as usize] };
    let keys = store.map.clone().into_keys().collect();
    println!("store `{}` keys: {:?}", store.name, keys);
    Ok(keys)
}
fn keyvalue_delete(handle: keyvalue, key: String) -> Result<(), keyvalue_error> {
    let store = unsafe { &mut STORES[handle as usize] };
    store.map.remove(&key);
    println!("remove `{}` from store `{}`", key, store.name);
    Ok(())
}

fn main() -> Result<(), Error> {
    let config = ConfigBuilder::new(CommonConfigOptions::default())
        .with_host_registration_config(HostRegistrationConfigOptions::default().wasi(true))
        .build()?;

    let vm = VmBuilder::new()
        .with_config(config)
        .build()?
        .register_import_module(witc_abi::runtime::component_model_wit_object()?)?
        .register_import_module(wasmedge::wit_import_object()?)?
        .register_module_from_file(
            "instance-service",
            "target/wasm32-wasi/release/instance_service.wasm",
        )?;

    let result = vm.run_func(Some("instance-service"), "start", None)?;
    assert!(result[0].to_i32() == 2);

    Ok(())
}
