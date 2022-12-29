#[macro_export]
macro_rules! for_all_pairs {
    ($mac:ident: $($x:ident)*) => {
        // Duplicate the list
        for_all_pairs!(@inner $mac: $($x)*; $($x)*);
    };
    // The end of iteration: we exhausted the list
    (@inner $mac:ident: ; $($x:ident)*) => {};
    // The head/tail recursion: pick the first element of the first list
    // and recursively do it for the tail.
    (@inner $mac:ident: $head:ident $($tail:ident)*; $($x:ident)*) => {
        $(
            $mac!($head, $x);
        )*
        for_all_pairs!(@inner $mac: $($tail)*; $($x)*);
    };
}

#[macro_export]
macro_rules! gen_all {
    ($mac:ident: $($x:ident)*) => {
        $(
            $mac!($x);
        )*
    };
}
