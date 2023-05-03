# runtime import

The example shows how runtime invokes instance's function as local one. First, we have wit file:

```wit
enum light {
  green,
  yellow,
  red
}

toggle : func(status : light) -> light
```

### instance (wasm module)

In the wasm module, we write down the following code

```rust
fn toggle(status: light) -> light {
    use light::*;
    match status {
        green => yellow,
        yellow => red,
        red => green,
    }
}
```

and write down below at the top of the file

```rust
invoke_witc::wit_instance!(export("traffic-lights.wit"));
```

to export definitions.

### runtime (wasmedge)

In runtime side, since `vm` can be created dynamically, thus, the generated wrapper has a parameter `&Vm`. Below is how to use it

```rust
let start = light::green;
let r = toggle(&vm, start);
println!("{:?}", r)
```

Just like in wasm module, you have to write the below code to import another component correctly

```rust
invoke_witc::wit_runtime!(import(instance = "traffic-lights.wit"));
```
