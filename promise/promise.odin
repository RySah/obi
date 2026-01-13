package promise

import "core:mem"
import "core:sync"
import "core:thread"

import "base:intrinsics"

Promise :: struct($T: typeid) {
    data: ^T,
    allocator: mem.Allocator,
    mutex: sync.Mutex,
    _terminate: bool
}

init :: proc(p: ^Promise($T), allocator := context.allocator) -> mem.Allocator_Error {
    if sync.guard(&p.mutex) {
        p.allocator = allocator
        p.data = new(T, allocator=p.allocator) or_return
        return nil
    }
}

terminate :: proc(p: ^Promise($T)) {
    sync.atomic_store(&p._terminate, true)
}

should_terminate :: proc(p: ^Promise($T)) -> bool {
    return sync.atomic_load(&p._terminate)
}

destroy :: proc(p: ^Promise($T)) -> mem.Allocator_Error {
    terminate(p)
    if sync.guard(&p.mutex) {
        return free(p.data, allocator=p.allocator)
    }
    return nil
}

set :: proc(
    p: ^Promise($T), 
    setter: #type proc(source: ^Promise(T), output: ^T, client_data: rawptr), 
    client_data: rawptr
) -> (tp: thread.Task_Proc, data: rawptr) {
    _Data :: struct {
        p: ^Promise(T),
        setter: #type proc(^Promise(T),^T,rawptr),
        client_data: rawptr
    }
    non_raw_data := new(_Data, allocator=p.allocator) or_return
    non_raw_data.p = p
    non_raw_data.setter = setter
    non_raw_data.client_data = client_data
    data=non_raw_data
    tp = proc(task: thread.Task) {
        context.allocator = task.allocator
        
        data := transmute(^_Data)task.data
        if sync.guard(&data.p.mutex) && !should_terminate(data.p) {
            data.setter(data.p, data.p.data, data.client_data)
            terminate(data.p)
        }

        free(task.data, allocator=data.p.allocator)
    }
    return tp, data
}

set_using_thread_pool :: proc(
    p: ^Promise($T), 
    pool: ^thread.Pool, 
    setter: #type proc(source: ^Promise(T), output: ^T, client_data: rawptr), 
    client_data: rawptr,
    allocator := context.allocator,
    user_index := 0
) {
    tp, data := set(p, setter, client_data)
    thread.pool_add_task(pool, allocator, tp, data, user_index=user_index)
}

get_ref :: proc(
    p: ^Promise($T)
) -> ^T {
    if sync.guard(&p.mutex) {
        return p.data
    }
}

get :: proc(
    p: ^Promise($T)
) -> T {
    return get_ref(p)^
}