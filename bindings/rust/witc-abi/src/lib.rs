#[cfg(target_arch = "wasm32")]
pub mod instance;

#[cfg(not(target_arch = "wasm32"))]
pub mod runtime;
