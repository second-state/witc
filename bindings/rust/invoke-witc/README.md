# invoke-witc

Add the crate to the dependencies.

```
invoke-witc = "0.2"
```

The usage of this crate is using the following macros to generate polyfill programs. e.g.

```rust
invoke_witc::wit_instance!(import("./xxx.wit"));
invoke_witc::wit_runtime!(import("./xxx.wit"));
invoke_witc::wit_runtime!(export("./xxx.wit"));
```

Let's assume there has a file `xxx.wit` contains

```wit
num : func(a: u32) -> u32
```

and discuss some special cases

## import: instance vs runtime

In instance, if we write

```rust
invoke_witc::wit_instance!(import("./xxx.wit"));
```

then we can just use `num(10)` to get a `u32`. But in runtime, due to the limitation, we will have to write

```rust
let u = num(&vm, 10);
```

where `vm : Vm`.

## export in runtime: with & without name

Let's say we are exporting component `xxx` in runtime, we will need to provide definition of `num`, like the following.

```rust
invoke_witc::wit_runtime!(export("./xxx.wit"));

// An example implementation
fn num(a: u32) -> u32 { a + 1 }
```

Then we have to register import object to `vm : Vm`, therefore, we will write

```rust
vm.register_import_module(xxx::wit_import_object()?)?
```

to ensure later wasm instances can use this implementation. A notable thing is that you can define export name:

```
invoke_witc::wit_runtime!(export(a = "./xxx.wit"));
invoke_witc::wit_runtime!(export(b = "./yyy.wit"));
```

with export name, the `wit_import_object` will be wrapped under different module, and hence, we will have:

```rust
vm.register_import_module(a::wit_import_object()?)?
  .register_import_module(b::wit_import_object()?)?
```
