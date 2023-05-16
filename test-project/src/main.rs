use wasmedge_sdk::{
    config::{CommonConfigOptions, ConfigBuilder, HostRegistrationConfigOptions},
    Vm, VmBuilder, WasmEdgeResult,
};
invoke_witc::wit_runtime!(export(export1 = "export1.wit"));
invoke_witc::wit_runtime!(export(export2 = "export2.wit"));

fn identity_one(a: u32) -> u32 {
    a
}
fn identity_two(a: u32) -> u32 {
    a
}

fn main() {
    let vm = build_vm().expect("vm failed");

    let result = vm
        .run_func(
            Some("import_wasm"),
            "run",
            vec![wasmedge_sdk::WasmValue::from_i32(1)],
        )
        .expect("test");

    println!("{}", result[0].to_i32());
}

fn build_vm() -> WasmEdgeResult<Vm> {
    let config = ConfigBuilder::new(CommonConfigOptions::default())
        .with_host_registration_config(HostRegistrationConfigOptions::default().wasi(true))
        .build()?;

    VmBuilder::new()
        .with_config(config)
        .build()?
        .register_import_module(witc_abi::runtime::component_model_wit_object()?)?
        .register_import_module(export1::wit_import_object()?)?
        .register_import_module(export2::wit_import_object()?)?
        .register_module_from_file(
            "import_wasm",
            "import_wasm/target/wasm32-wasi/release/import_wasm.wasm",
        )
}

#[test]
fn export1() {
    let vm = build_vm().unwrap();

    let result = vm
        .run_func(
            Some("import_wasm"),
            "run",
            vec![wasmedge_sdk::WasmValue::from_i32(1)],
        )
        .unwrap();

    assert!(result[0].to_i32() == 1);
}
