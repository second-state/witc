use wasmedge_sdk::{Caller, WasmValue};

pub trait Runtime {
    type T;

    fn size() -> usize;

    fn new_by_runtime(caller: &Caller, input: Vec<WasmValue>) -> (Self::T, Vec<WasmValue>);
}
