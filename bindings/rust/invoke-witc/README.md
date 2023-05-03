# invoke-witc

Add the crate to the dependencies.

```
invoke-witc = "0.2"
```

The usage of this crate is using the following macros to generate polyfill programs.

```rust
invoke_witc::wit_instance!(import("./xxx.wit"));
invoke_witc::wit_runtime!(import("./xxx.wit"));
invoke_witc::wit_runtime!(export("./xxx.wit"));
```
