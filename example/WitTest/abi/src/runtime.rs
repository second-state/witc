use wasmedge_sdk::{Caller, WasmValue};

/// Runtime trait provides to build wasm abi-objects from wasmedge_sdk
pub trait Runtime {
    /// size
    ///
    /// How many bytes
    ///
    /// For example, the size of `WitString` is `12` since it has 3 `i32` in wasi32 encoding
    fn size() -> usize;

    fn new_by_runtime(caller: &Caller, input: Vec<WasmValue>) -> (Self, Vec<WasmValue>)
    where
        Self: Sized;
}
