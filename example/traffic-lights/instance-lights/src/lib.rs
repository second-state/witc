use serde::{Deserialize, Serialize};
invoke_witc::wit_instance!(export("traffic-lights.wit"));

fn toggle(status: light) -> light {
    use light::*;
    match status {
        green => yellow,
        yellow => red,
        red => green,
    }
}
