use once_cell::sync::Lazy;
use std::{
    collections::{HashMap, VecDeque},
    sync::atomic::{AtomicI32, Ordering},
};
use wasmedge_sdk::{
    error::HostFuncError, host_function, Caller, ImportObject, ImportObjectBuilder, WasmEdgeResult,
    WasmValue,
};

struct GrowCache {
    offset: u32,
    pages: u32,
}

pub struct GlobalState {
    counter: AtomicI32,
    grow_cache: HashMap<String, GrowCache>,
    queue_pool: HashMap<i32, VecDeque<String>>,
}

impl GlobalState {
    fn new() -> Self {
        Self {
            counter: AtomicI32::new(0),
            queue_pool: HashMap::new(),
            grow_cache: HashMap::new(),
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

    fn get_cache(&self, instance_name: &String) -> Option<&GrowCache> {
        self.grow_cache.get(instance_name)
    }

    fn update_cache(&mut self, instance_name: String, offset: u32, pages: u32) {
        self.grow_cache
            .insert(instance_name, GrowCache { offset, pages });
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

    println!("enqueue {}", data_buffer.clone());

    unsafe {
        STATE.put_buffer(id, data_buffer);
    }

    Ok(vec![])
}

#[host_function]
fn read_buffer(caller: Caller, input: Vec<WasmValue>) -> Result<Vec<WasmValue>, HostFuncError> {
    let id = input[0].to_i32();

    let data_buffer = unsafe { &STATE.read_buffer(id) };
    let data_size = (data_buffer.as_bytes().len() * 8) as u32;
    // one page = 64KiB = 65,536 bytes
    let pages = (data_size / (65536)) + 1;

    println!(
        "dequeue `{}`\n pages: {} (64KiB each page)\n data size: {} bytes",
        data_buffer, pages, data_size,
    );

    let mut mem = caller.memory(0).unwrap();

    let instance_name = caller.instance().unwrap().name().unwrap();
    let cache = unsafe { STATE.get_cache(&instance_name) };

    match cache {
        // 1. cache missing than grow 50
        None => {
            let current_tail = mem.size();

            mem.grow(pages).unwrap();
            let offset = current_tail + 1;
            // 1. memory the `current_tail+1` as `offset`
            mem.write(data_buffer, offset).unwrap();
            // 2. memory the `pages` we just grow
            unsafe {
                STATE.update_cache(instance_name, offset, pages);
            }

            Ok(vec![
                WasmValue::from_i32(offset as i32),
                WasmValue::from_i32(data_buffer.len() as i32),
            ])
        }
        // 2. cache existed, than reuse `offset` in cache
        Some(cache) => {
            let offset = cache.offset;
            // the size we already have
            let grew_pages = cache.pages;

            if grew_pages >= pages {
                // 1. if `grow_size` is big enough than reuse it
                mem.write(data_buffer, offset).unwrap();
                Ok(vec![
                    WasmValue::from_i32(offset as i32),
                    WasmValue::from_i32(data_buffer.len() as i32),
                ])
            } else {
                // 2. or grow more to reach the needed, than update the cache
                mem.grow(pages - grew_pages).unwrap();
                mem.write(data_buffer, offset).unwrap();
                unsafe {
                    STATE.update_cache(instance_name, offset, pages);
                }

                Ok(vec![
                    WasmValue::from_i32(offset as i32),
                    WasmValue::from_i32(data_buffer.len() as i32),
                ])
            }
        }
    }
}

pub fn component_model_wit_object() -> WasmEdgeResult<ImportObject> {
    ImportObjectBuilder::new()
        .with_func::<(), i32>("require_queue", require_queue)?
        .with_func::<(i32, i32, i32), ()>("write", put_buffer)?
        .with_func::<i32, (i32, i32)>("read", read_buffer)?
        .build("wasmedge.component.model")
}
