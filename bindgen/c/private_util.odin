package bindgen_c

remove_index :: proc(array: ^$D/[dynamic]$T, i: int, loc := #caller_location) {
    remove_range(array, i, i+1, loc=loc)
}