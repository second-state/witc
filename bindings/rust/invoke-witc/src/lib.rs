use proc_macro::TokenStream;
use std::process::{Command, Output};
use syn::{parse_macro_input, Lit, Meta, MetaList, NestedMeta};

fn lit_as_str(lit: &Lit) -> String {
    match lit {
        Lit::Str(s) => s.value(),
        _ => unreachable!(),
    }
}
fn name_value_meta(meta: &Meta) -> (String, String) {
    match meta {
        Meta::NameValue(nv) => (
            nv.path.get_ident().unwrap().to_string(),
            lit_as_str(&nv.lit),
        ),
        _ => unreachable!(),
    }
}

fn check_version() {
    let ver_output = Command::new("witc-exe")
        .args(["--version"])
        .output()
        .unwrap();
    let ver = String::from_utf8(ver_output.stdout).unwrap();
    if ver != "0.2.0\n" {
        panic!("witc-exe version mismatch: expected 0.2.0, got {}", ver);
    }
}

#[proc_macro]
pub fn wit_instance(input: TokenStream) -> TokenStream {
    check_version();
    let MetaList { path, nested, .. } = parse_macro_input!(input);
    let mode = path.get_ident().unwrap().to_string();
    let r: Output = match &nested[0] {
        NestedMeta::Lit(lit) => {
            let wit_file = lit_as_str(lit);
            Command::new("witc-exe")
                .args(["instance", &mode, &wit_file])
                .output()
                .unwrap()
        }
        NestedMeta::Meta(meta) => {
            let (import_name, wit_file) = name_value_meta(meta);
            Command::new("witc-exe")
                .args(["instance", &mode, &wit_file, &import_name])
                .output()
                .unwrap()
        }
    };
    String::from_utf8_lossy(&r.stdout).parse().unwrap()
}

#[proc_macro]
pub fn wit_runtime(input: TokenStream) -> TokenStream {
    check_version();
    let MetaList { path, nested, .. } = parse_macro_input!(input);
    let mode = path.get_ident().unwrap().to_string();
    let r: Output = match &nested[0] {
        NestedMeta::Lit(lit) => {
            let wit_file = lit_as_str(lit);
            Command::new("witc-exe")
                .args(["runtime", &mode, &wit_file])
                .output()
                .unwrap()
        }
        NestedMeta::Meta(meta) => {
            let (import_name, wit_file) = name_value_meta(meta);
            Command::new("witc-exe")
                .args(["runtime", &mode, &wit_file, &import_name])
                .output()
                .unwrap()
        }
    };
    String::from_utf8_lossy(&r.stdout).parse().unwrap()
}
