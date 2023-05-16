use once_cell::sync::Lazy;
use std::{
    collections::{HashMap, VecDeque},
    sync::atomic::{AtomicI32, Ordering},
};
use wasmedge_sdk::{
    error::HostFuncError, host_function, Caller, ImportObject, ImportObjectBuilder, WasmEdgeResult,
    WasmValue,
};

pub struct GlobalState {
    counter: AtomicI32,
    queue_pool: HashMap<i32, VecDeque<String>>,
}

impl GlobalState {
    fn new() -> Self {
        Self {
            counter: AtomicI32::new(0),
            queue_pool: HashMap::new(),
        }
    }

    // This allocation algorithm relys on HashMap will limit the bucket size to a fixed number,
    // and the calls will not grow too fast (run out of i32 to use).
    // It still might have problem, if two limits above are broke.
    pub fn new_queue(&mut self) -> i32 {
        let id = self.counter.fetch_add(1, Ordering::SeqCst);
        self.queue_pool.insert(id, VecDeque::new());
        id
    }

    pub fn put_buffer(&mut self, queue_id: i32, buf: String) {
        self.queue_pool.get_mut(&queue_id).unwrap().push_back(buf);
    }

    pub fn read_buffer(&mut self, queue_id: i32) -> String {
        self.queue_pool
            .get_mut(&queue_id)
            .unwrap()
            .pop_front()
            .unwrap()
    }
}

pub static mut STATE: Lazy<GlobalState> = Lazy::new(|| GlobalState::new());

#[host_function]
fn require_queue(_caller: Caller, _input: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    unsafe {
        let id = STATE.new_queue();
        Ok(vec![WasmValue::from_i32(id)])
    }
}

#[host_function]
fn put_buffer(caller: Caller, input: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    let id = input[0].to_i32();
    let offset = input[1].to_i32() as u32;
    let len = input[2].to_i32() as u32;

    let data_buffer = caller.memory(0).unwrap().read_string(offset, len).unwrap();

    unsafe {
        STATE.put_buffer(id, data_buffer);
    }

    Ok(vec![])
}

#[host_function]
fn read_buffer(caller: Caller, input: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    let read_buf_struct_ptr = input[0].to_i32() as u32;
    let queue_id = input[1].to_i32();

    let data_buffer = unsafe { &STATE.read_buffer(queue_id) };
    // capacity will use underlying vector's capacity
    // potential problem is it might be bigger than exact (data) needs
    let data_size = data_buffer.capacity() as u32;
    // The idea here is putting data from backward of memory, and hopes it would not overlap with program usage
    let mut mem = caller.memory(0).unwrap();
    let offset = (mem.size() as u32) - data_size;
    mem.write(data_buffer, offset).unwrap();

    let instance_ptr = offset as u32;
    let mut struct_content = instance_ptr.to_le_bytes().to_vec();
    // This assuming that the struct `ReadBuf` in instance will have linear layout
    //
    // #[repr(C)]
    // pub struct ReadBuf {
    //     pub offset: usize,
    //     pub len: usize,
    // }
    struct_content.extend((data_buffer.len() as u32).to_le_bytes());
    mem.write(struct_content, read_buf_struct_ptr).unwrap();

    Ok(vec![])
}

pub fn component_model_wit_object() -> WasmEdgeResult<ImportObject> {
    ImportObjectBuilder::new()
        .with_func::<(), i32>("require_queue", require_queue)?
        .with_func::<(i32, i32, i32), ()>("write", put_buffer)?
        .with_func::<(i32, i32), ()>("read", read_buffer)?
        .build("wasmedge.component.model")
}
