# witc_abi

This repository is working with `invoke_witc`, you will not need to use this crate directly, just add it into dependencies.

```toml
witc_abi = "0.2"
```

## Runtime

You will need to register common helper for your `vm : Vm` if you want to use witc

```rust
vm.register_import_module(witc_abi::runtime::component_model_wit_object()?)?
```
