use once_cell::sync::Lazy;
use std::{
    collections::{HashMap, VecDeque},
    sync::atomic::{AtomicI32, Ordering},
};
use wasmedge_sdk::{
    error::HostFuncError, host_function, Caller, ImportObject, ImportObjectBuilder, Memory,
    WasmEdgeResult, WasmValue,
};

pub struct GlobalState {
    counter: AtomicI32,
    queue_pool: HashMap<i32, VecDeque<String>>,
    mem_pool: HashMap<i32, Memory>,
}

impl GlobalState {
    fn new() -> Self {
        Self {
            counter: AtomicI32::new(0),
            queue_pool: HashMap::new(),
            mem_pool: HashMap::new(),
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

    pub fn register_memory(&mut self, mem: Memory) -> i32 {
        let new_id = self.new_queue();
        self.mem_pool.insert(new_id, mem);
        return new_id;
    }

    pub fn copy_data(
        &mut self,
        mem_id_from: i32,
        mem_id_to: i32,
        offset: u32,
        len: u32,
    ) -> (u32, u32) {
        let from_mem = self.mem_pool.get(&mem_id_from).unwrap();
        let data = from_mem.read(offset, len).unwrap();
        let data_len = data.len() as u32;
        let to_mem = self.mem_pool.get_mut(&mem_id_to).unwrap();
        let mut offset = to_mem.size() as u32;
        offset -= data_len;
        to_mem.write(data, offset).unwrap();
        (offset, data_len)
    }
}

pub static mut STATE: Lazy<GlobalState> = Lazy::new(|| GlobalState::new());

#[host_function]
fn register_memory(caller: Caller, _: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    let mem = caller.memory(0).unwrap();
    let mem_id = unsafe { STATE.register_memory(mem) };
    Ok(vec![WasmValue::from_i32(mem_id)])
}

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
