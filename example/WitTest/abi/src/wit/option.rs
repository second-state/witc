#[derive(Debug)]
#[repr(C, u32)]
pub enum WitOption<T> {
    None,
    Some(T),
}

impl<T> From<Option<T>> for WitOption<T> {
    fn from(r: Option<T>) -> Self {
        match r {
            None => WitOption::None,
            Some(v) => WitOption::Some(v.into()),
        }
    }
}
impl<T> Into<Option<T>> for WitOption<T> {
    fn into(self: Self) -> Option<T> {
        match self {
            WitOption::None => None,
            WitOption::Some(v) => Some(v.into()),
        }
    }
}
