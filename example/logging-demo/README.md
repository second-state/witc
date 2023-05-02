# logging

This demo shows across instance call, the following is our wit file:

```wit
record pack {
  message : string,
  level: u32
}

log: func(p : pack) -> u32
```

### instance (provides `log` implementation)

```rust
use serde::{Deserialize, Serialize};
invoke_witc::wit_instance!(export("./logging.wit"));

fn log(p: pack) -> u32 {
    let s = format!("{} {}", p.level, p.message);
    unsafe {
        runtime_println(s.as_ptr(), s.len());
    }
    p.level
}
```

### instance (mock another service that use logging)

```rust
use serde::{Deserialize, Serialize};
invoke_witc::wit_instance!(import(instance_logging = "logging.wit"));

#[no_mangle]
pub unsafe extern "C" fn start() -> u32 {
    let _ = log(pack {
        message: "cannot connect to 196.128.10.3".to_string(),
        level: 1,
    });
    return 0;
}
```

### runtime (glue instances)

```rust
let vm = Vm::new(Some(config))?
    .register_module_from_file(
        "instance_logging",
        "target/wasm32-wasi/release/instance_logging.wasm",
    )?
    .register_module_from_file(
        "instance-service",
        "target/wasm32-wasi/release/instance_service.wasm",
    )?;

let result = vm.run_func(Some("instance-service"), "start", None)?;
assert!(result[0].to_i32() == 0);
```
