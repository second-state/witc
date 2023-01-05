use wasmedge_sdk::{Caller, Memory, WasmValue};

/// Runtime trait provides to build wasm abi-objects from wasmedge_sdk
pub trait Runtime {
    /// size
    ///
    /// The function returns how many bytes the `T`, which `impl Runtime for T`, has
    ///
    /// For example, the size of `WitString` is `12` since it has 3 `i32` in wasi32 encoding
    fn size() -> usize;

    /// new_by_runtime
    ///
    /// This function get caller and a series of input to build up itself, returns the built Self and rest input
    fn new_by_runtime(caller: &Caller, input: Vec<WasmValue>) -> (Self, Vec<WasmValue>)
    where
        Self: Sized;

    fn allocate(self: Self, mem: &mut Memory) -> Vec<WasmValue>;
}
