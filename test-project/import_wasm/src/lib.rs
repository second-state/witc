use serde::{Deserialize, Serialize};
invoke_witc::wit_instance!(import(export1 = "../export1.wit"));
invoke_witc::wit_instance!(import(export2 = "../export2.wit"));

#[no_mangle]
pub unsafe extern "C" fn run(a: u32) -> u32 {
    return identity_two(identity_one(a));
}
