package promise

import "core:mem"
import "core:sync"
import "core:thread"

import "base:intrinsics"
import "base:runtime"

Promise :: struct($T: typeid) {
    data: ^T,
    allocator: mem.Allocator,
    mutex: sync.Mutex,
    _terminate: bool,
    _index: int
}

init :: proc(p: ^Promise($T), allocator := context.allocator) -> mem.Allocator_Error {
    if sync.guard(&p.mutex) {
        p.allocator = allocator
        p.data = new(T, allocator=p.allocator) or_return
        return nil
    }
    return nil
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

@private _set :: proc(
    p: ^Promise($T), 
    setter: #type proc(source: ^Promise(T), output: ^T, client_data: rawptr), 
    client_data: rawptr
) -> (tp: thread.Task_Proc, data: rawptr) {
    _Data :: struct {
        p: ^Promise(T),
        setter: #type proc(^Promise(T),^T,rawptr),
        client_data: rawptr
    }
    non_raw_data := new(_Data, allocator=p.allocator)
    non_raw_data.p = p
    non_raw_data.setter = setter
    non_raw_data.client_data = client_data
    data=non_raw_data
    tp = proc(task: thread.Task) {
        context.allocator = task.allocator
        
        data := transmute(^_Data)task.data
        if sync.guard(&data.p.mutex) {
            if !should_terminate(data.p) {
                data.setter(data.p, data.p.data, data.client_data)
                terminate(data.p)
            }
        }

        free(task.data, allocator=data.p.allocator)
    }
    return tp, data
}

set :: proc(
    p: ^Promise($T), 
    pool: ^Pool, 
    setter: #type proc(source: ^Promise(T), output: ^T, client_data: rawptr), 
    client_data: rawptr,
    allocator := context.allocator
) {
    @static user_index := 0
    tp, data := _set(p, setter, client_data)
    p._index = user_index
    _pool_add_task(pool, allocator, tp, data, user_index=p._index)
    user_index += 1
}

get_ref :: proc(
    p: ^Promise($T)
) -> ^T {
    if sync.guard(&p.mutex) {
        return p.data
    }
    unimplemented()
}

get :: proc(
    p: ^Promise($T)
) -> T {
    return get_ref(p)^
}

Pool :: [size_of(thread.Pool) when thread.IS_SUPPORTED else 0]byte

pool_thread_pool :: #force_inline proc(pool: ^Pool) -> ^thread.Pool {
    when thread.IS_SUPPORTED {
        return transmute(^thread.Pool)pool
    } else {
        return nil
    }
}
pool_init :: #force_inline proc(pool: ^Pool, allocator: mem.Allocator, thread_count: int) {
    when thread.IS_SUPPORTED {
        thread.pool_init(pool_thread_pool(pool), allocator, thread_count)
    }
}
@private _pool_add_task :: #force_inline proc(pool: ^Pool, allocator: mem.Allocator, procedure: thread.Task_Proc, data: rawptr, user_index: int = 0) {
    when thread.IS_SUPPORTED {
        thread.pool_add_task(pool_thread_pool(pool), allocator, procedure, data, user_index)
    } else {
        procedure(thread.Task{
	    	procedure  = procedure,
	    	data       = data,
	    	user_index = user_index,
	    	allocator  = allocator,
	    })
    }
}
pool_destroy :: #force_inline proc(pool: ^Pool) {
    when thread.IS_SUPPORTED {
        thread.pool_destroy(pool_thread_pool(pool))
    }
}
pool_finish :: #force_inline proc(pool: ^Pool) {
    when thread.IS_SUPPORTED {
        thread.pool_finish(pool_thread_pool(pool))
    }
}
pool_is_empty :: #force_inline proc(pool: ^Pool) -> bool {
    when thread.IS_SUPPORTED {
        return thread.pool_is_empty(pool_thread_pool(pool))
    } else {
        return true
    }
}
pool_join :: #force_inline proc(pool: ^Pool) {
    when thread.IS_SUPPORTED {
        thread.pool_join(pool_thread_pool(pool))
    }
}
pool_num_done :: #force_inline proc(pool: ^Pool) -> int {
    when thread.IS_SUPPORTED {
        return thread.pool_num_done(pool_thread_pool(pool))
    } else {
        return 0
    }
}
pool_num_in_processing :: #force_inline proc(pool: ^Pool) -> int {
    when thread.IS_SUPPORTED {
        return thread.pool_num_in_processing(pool_thread_pool(pool))
    } else {
        return 0
    }
}
pool_num_outstanding :: #force_inline proc(pool: ^Pool) -> int {
    when thread.IS_SUPPORTED {
        return thread.pool_num_outstanding(pool_thread_pool(pool))
    } else {
        return 0
    }
}
pool_num_waiting :: #force_inline proc(pool: ^Pool) -> int {
    when thread.IS_SUPPORTED {
        return thread.pool_num_waiting(pool_thread_pool(pool))
    } else {
        return 0
    }
}
pool_start :: #force_inline proc(pool: ^Pool) {
    when thread.IS_SUPPORTED {
        thread.pool_start(pool_thread_pool(pool))
    }
}
pool_shutdown :: proc(pool: ^Pool, exit_code: int = 1) {
    when thread.IS_SUPPORTED {
        thread.pool_shutdown(pool_thread_pool(pool), exit_code)
    }
}
pool_stop_all_tasks :: proc(pool: ^Pool, exit_code: int = 1) {
    when thread.IS_SUPPORTED {
        thread.pool_stop_all_tasks(pool_thread_pool(pool), exit_code)
    }
}