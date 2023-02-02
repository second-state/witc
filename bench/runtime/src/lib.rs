#![feature(test)]
extern crate test;
use serde::{Deserialize, Serialize};
use wasmedge_sdk::{host_function, Caller};
use witc_abi::*;
invoke_witc::wit_runtime!(export("base.wit"));

fn base(c1: c) -> c {
    c {
        name: c1.name,
        age: c1.age + 1,
    }
}

fn fib(n: u64) -> u64 {
    if n <= 1 {
        return n;
    }
    return fib(n - 1) + fib(n - 2);
}

#[cfg(test)]
mod tests {
    use super::*;
    use test::Bencher;
    use wasmedge_sdk::{
        config::{CommonConfigOptions, ConfigBuilder, HostRegistrationConfigOptions},
        Vm,
    };

    fn test_vm() -> Vm {
        let config = ConfigBuilder::new(CommonConfigOptions::default())
            .with_host_registration_config(HostRegistrationConfigOptions::default().wasi(true))
            .build()
            .unwrap();

        let import_object = wit_import_object().unwrap();

        Vm::new(Some(config))
            .unwrap()
            .register_import_module(import_object)
            .unwrap()
            .register_module_from_file("instance", "../target/wasm32-wasi/release/instance.wasm")
            .unwrap()
    }

    #[bench]
    fn base_native(b: &mut Bencher) {
        b.iter(|| {
            let n = test::black_box(1000);

            base(c {
                name: "test".to_string(),
                age: n,
            });
        });
    }

    #[bench]
    fn base_instance_invokes_runtime(b: &mut Bencher) {
        let vm = test_vm();

        b.iter(|| {
            vm.run_func(Some("instance"), "call_base", None).unwrap();
        });
    }

    #[bench]
    fn fib_native(b: &mut Bencher) {
        b.iter(|| {
            let n = test::black_box(10);

            fib(n);
        });
    }

    #[bench]
    fn fib_instance_invokes_runtime(b: &mut Bencher) {
        let vm = test_vm();

        b.iter(|| {
            vm.run_func(Some("instance"), "call_fib", None).unwrap();
        });
    }
}
