package thread_safe_array

import "base:runtime"
import "core:sync"

import "base:builtin"

Thread_Safe_Array :: struct($E: typeid) {
    buffer: ^[]E,
    mutex: sync.RW_Mutex
}
Thread_Safe_Dynamic_Array :: struct($E: typeid) {
    buffer: ^[dynamic]E,
    mutex: sync.RW_Mutex
}

init_arr :: proc "contextless" (arr: ^Thread_Safe_Array($T), back: ^[]T) {
    arr.buffer = back
}
init_dyn_arr :: proc "contextless" (arr: ^Thread_Safe_Dynamic_Array($T), back: ^[dynamic]T) {
    arr.buffer = back
}

read_arr_lock :: proc "contextless" (arr: ^Thread_Safe_Array($T)) {
    sync.rw_mutex_shared_lock(&arr.mutex)
}
read_dyn_arr_lock :: proc "contextless" (arr: ^Thread_Safe_Dynamic_Array($T)) {
    sync.rw_mutex_shared_lock(&arr.mutex)
}
read_lock :: proc{read_arr_lock,read_dyn_arr_lock}
read_arr_unlock :: proc "contextless" (arr: ^Thread_Safe_Array($T)) {
    sync.rw_mutex_shared_unlock(&arr.mutex)
}
read_dyn_arr_unlock :: proc "contextless" (arr: ^Thread_Safe_Dynamic_Array($T)) {
    sync.rw_mutex_shared_unlock(&arr.mutex)
}
read_unlock :: proc{read_arr_unlock,read_dyn_arr_unlock}
read_write_arr_lock :: proc "contextless" (arr: ^Thread_Safe_Array($T)) {
    sync.rw_mutex_lock(&arr.mutex)
}
read_write_dyn_arr_lock :: proc "contextless" (arr: ^Thread_Safe_Dynamic_Array($T)) {
    sync.rw_mutex_lock(&arr.mutex)
}
read_write_lock :: proc{read_write_arr_lock,read_write_dyn_arr_lock}
read_write_arr_unlock :: proc "contextless" (arr: ^Thread_Safe_Array($T)) {
    sync.rw_mutex_unlock(&arr.mutex)
}
read_write_dyn_arr_unlock :: proc "contextless" (arr: ^Thread_Safe_Dynamic_Array($T)) {
    sync.rw_mutex_unlock(&arr.mutex)
}
read_write_unlock :: proc{read_write_arr_unlock,read_write_dyn_arr_unlock}

read_arr_len :: proc(arr: ^Thread_Safe_Array($T)) -> int {
    read_lock(arr)
    defer read_unlock(arr)
    return len(arr.buffer^) 
}
read_dyn_arr_len :: proc(arr: ^Thread_Safe_Dynamic_Array($T)) -> int {
    read_lock(arr)
    defer read_unlock(arr)
    return len(arr.buffer^) 
}
read_len :: proc{read_arr_len,read_dyn_arr_len}
read_arr_cap :: proc(arr: ^Thread_Safe_Array($T)) -> int {
    read_lock(arr)
    defer read_unlock(arr)
    return cap(arr.buffer^) 
}
read_dyn_arr_cap :: proc(arr: ^Thread_Safe_Dynamic_Array($T)) -> int {
    read_lock(arr)
    defer read_unlock(arr)
    return cap(arr.buffer^) 
}
read_cap :: proc{read_arr_cap,read_dyn_arr_cap}
read_write_pop :: proc(arr: ^Thread_Safe_Dynamic_Array($T), loc := #caller_location) -> (res: T) {
    read_write_lock(arr)
    defer read_write_unlock(arr)
    return pop(arr.buffer, loc)
}
read_write_pop_front :: proc(arr: ^Thread_Safe_Dynamic_Array($T), loc := #caller_location) -> (res: T) {
    read_write_lock(arr)
    defer read_write_unlock(arr)
    return pop_front(arr.buffer, loc)
}
read_arr_at :: proc(arr: ^Thread_Safe_Array($T), i: int) -> T {
    read_lock(arr)
    defer read_unlock(arr)
    return arr.buffer[i]
}
read_dyn_arr_at :: proc(arr: ^Thread_Safe_Dynamic_Array($T), i: int) -> T {
    read_lock(arr)
    defer read_unlock(arr)
    return arr.buffer[i]
}
read_at :: proc{read_arr_at,read_dyn_arr_at}

Loop_Result :: enum u8 { Continue, Break }

read_arr_foreach :: proc(
    arr: ^Thread_Safe_Array($T), 
    p: #type proc(value: T, i: int) -> Loop_Result
) {
    read_lock(arr)
    defer read_unlock(arr)
    for value, i in arr.buffer {
        if p(value, i) == .Break do break
    }
}
read_dyn_arr_foreach :: proc(
    arr: ^Thread_Safe_Dynamic_Array($T), 
    p: #type proc(value: T, i: int) -> Loop_Result
) {
    read_lock(arr)
    defer read_unlock(arr)
    for value, i in arr.buffer {
        if p(value, i) == .Break do break
    }
}
read_foreach :: proc{read_arr_foreach,read_dyn_arr_foreach}

read_write_arr_foreach :: proc(
    arr: ^Thread_Safe_Array($T), 
    p: #type proc(arr: ^Thread_Safe_Array(T), value: ^T, i: int) -> Loop_Result
) {
    read_write_lock(arr)
    defer read_write_unlock(arr)
    for &value, i in arr.buffer {
        if p(arr, &value, i) == .Break do break
    }
}
read_write_dyn_arr_foreach :: proc(
    arr: ^Thread_Safe_Dynamic_Array($T), 
    p: #type proc(arr: ^Thread_Safe_Dynamic_Array(T), value: ^T, i: int) -> Loop_Result
) {
    read_write_lock(arr)
    defer read_write_unlock(arr)
    for &value, i in arr.buffer {
        if p(arr, &value, i) == .Break do break
    }
}
read_write_foreach :: proc{read_write_arr_foreach,read_write_dyn_arr_foreach}
