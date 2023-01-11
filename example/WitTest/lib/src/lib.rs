#![feature(wasm_abi)]
use serde::{Deserialize, Serialize};

invoke_witc::wit_instance_import!("../test.wit");

// TODO: extract to witc_abi
fn as_remote_string<A>(a: A) -> (usize, usize)
where
    A: Serialize,
{
    let s = serde_json::to_string(&a).unwrap();

    let remote_addr = unsafe { allocate(s.len() as usize) };
    unsafe {
        for (i, c) in s.bytes().enumerate() {
            write(remote_addr, i, c);
        }
    }

    (remote_addr, s.len())
}

// TODO: extract to witc_abi
fn from_remote_string(pair: (usize, usize)) -> String {
    let (remote_addr, len) = pair;

    let mut s = String::with_capacity(len);

    unsafe {
        for i in 0..len {
            s.push(read(remote_addr, i) as char);
        }
    }

    s
}

#[no_mangle]
pub unsafe extern "wasm" fn start() -> u32 {
    // string & struct (wit record)
    let p1 = person {
        name: "Carlo".into(),
        age: 30,
    };
    let p2 = set_name(p1, "Phillips".into());
    let p3 = set_name(p2, "August".into());
    // enum 0-product (wit enum)
    let _i = exchange_enum(color::green);
    // Option (wit option)
    let _r = maybe_test(Some(5));
    let _r = maybe_test(None);
    // Result (wit expected)
    let _r = send_result(Ok("this is fine".into()));
    let _r = send_result(Err("test111".into()));
    let _r = send_result2(Ok(1));
    let _r = send_result2(Err(1));
    let _r = send_result2(Err(2));
    let _r = send_result2(Err(3));
    // Vec (wit list)
    let mut v = Vec::with_capacity(3);
    v.push(1);
    v.push(2);
    let _l = exchange_list(v);
    let _l = exchange_list_string(vec!["test".into(), "abc".into()]);
    // enum (wit variant)
    let _ = pass_nat(nat::zero);
    let _ = pass_nat(nat::suc(Box::new(nat::suc(Box::new(nat::suc(Box::new(
        nat::zero,
    )))))));

    return 0;
}
