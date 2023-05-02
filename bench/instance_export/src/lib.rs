use serde::{Deserialize, Serialize};
invoke_witc::wit_instance!(export("instance_export.wit"));
use witc_abi::instance::*;

fn base2(c: c2) -> c2 {
    c2 {
        name: c.name,
        age: c.age + 1,
    }
}
