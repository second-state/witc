#![feature(wasm_abi)]
invoke_witc::wit_instance!(export("./test.wit"));

fn id_string(s: String) -> String {
    s
}
