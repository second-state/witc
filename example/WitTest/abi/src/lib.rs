#[repr(C, u8)]
pub enum WitResult<T, E> {
    Ok(T),
    Err(E),
}

impl<T, E> From<Result<T, E>> for WitResult<T, E> {
    fn from(r: Result<T, E>) -> Self {
        match r {
            Ok(ok) => WitResult::Ok(ok),
            Err(err) => WitResult::Err(err),
        }
    }
}
