mod export1
{pub fn wit_import_object() -> wasmedge_sdk::WasmEdgeResult<wasmedge_sdk::ImportObject> {Ok (wasmedge_sdk::ImportObjectBuilder::new() .with_func::<i32, ()> ( "extern_identity_one"
, extern_identity_one ) ? .build("wasmedge")?)}
use wasmedge_sdk::Caller;
#[wasmedge_sdk::host_function] 
 fn extern_identity_one (caller: wasmedge_sdk::Caller, input: Vec<wasmedge_sdk::WasmValue>) -> Result<Vec<wasmedge_sdk::WasmValue>, wasmedge_sdk::error::HostFuncError> {    let id = input[0].to_i32(); let a : u32 = serde_json::from_str(unsafe { witc_abi::runtime::STATE.read_buffer(id).as_str() }).unwrap(); let r = identity_one ( a ) ; let result_str = serde_json::to_string(&r).unwrap(); unsafe { witc_abi::runtime::STATE.put_buffer(id, result_str) } Ok(vec![])}}