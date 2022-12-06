#![feature(wasm_abi)]

pmacro::wit_instance_import!("../test.wit");

#[no_mangle]
pub unsafe extern "wasm" fn start() -> u32 {
    // string & struct (wit record)
    let mut s = String::with_capacity(10);
    s.push('a');
    let _s = exchange(
        s,
        person {
            name: "Carlo".into(),
            age: 30,
        },
    );
    // enum (wit enum)
    let _i = exchange_enum(color::green);
    // Option (wit option)
    let _r = maybe_test(Some(5));
    let _r = maybe_test(None);
    // Result (wit expected)
    let _r = send_result(Ok(3));
    let _r = send_result(Err("test111".into()));
    let _r = send_result2(Ok(1));
    let _r = send_result2(Err(1));
    let _r = send_result2(Err(2));
    let _r = send_result2(Err(3));

    return 0;
}
