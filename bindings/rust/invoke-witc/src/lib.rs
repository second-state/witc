use proc_macro::TokenStream;
use std::process::Command;
use syn::{parse_macro_input, LitStr};

#[proc_macro]
pub fn wit_instance_import(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as LitStr);
    let wit_file = input.value();
    let r = Command::new("witc-exe")
        .args(["instance", "import", &wit_file])
        .output()
        .unwrap();
    String::from_utf8_lossy(&r.stdout).parse().unwrap()
}

#[proc_macro]
pub fn wit_runtime_export(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as LitStr);
    let wit_file = input.value();
    let r = Command::new("witc-exe")
        .args(["runtime", "export", &wit_file])
        .output()
        .unwrap();
    String::from_utf8_lossy(&r.stdout).parse().unwrap()
}
