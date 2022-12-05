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
    // result (wit expected)
    let r = Ok(321);
    let _r = handle_result(r);
    let r = Err("test".into());
    let _r = handle_result(r);

    return 0;
}
