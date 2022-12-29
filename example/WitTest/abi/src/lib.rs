#![feature(vec_into_raw_parts)]

#[cfg(not(target_arch = "wasm32"))]
pub mod runtime;

mod common;
mod wit;

pub use wit::option::WitOption;
pub use wit::result::WitResult;
pub use wit::string::WitString;
pub use wit::vec::WitVec;
