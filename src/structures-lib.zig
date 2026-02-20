const set = @import("ziglangSet");

/// Convert set to slice
///
/// Slices are more convenient for looping
/// This shit is cursed, bad design and probably does not work, I'll just slap the 3 iterators where I needed
pub fn set_to_slice(T: type, _set: set.Set(T)) []const T {
    const slice: [_set.cardinality()]T = undefined;
    const it = _set.iterator();
    var i = 0;
    while (it.next()) |p| {
        slice[i] = p;
        i += 1;
    }
    return slice;
}
