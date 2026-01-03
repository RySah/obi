package thread_safe_allocator

import "base:runtime"
import "core:sync"

Thread_Safe_Allocator :: struct {
    using impl: runtime.Allocator,
    backing: runtime.Allocator,
    mutex: sync.Mutex
}

allocator_proc : runtime.Allocator_Proc : proc(
    allocator_data: rawptr, 
    mode: runtime.Allocator_Mode, 
    size, alignment: int, 
    old_memory: rawptr, 
    old_size: int, 
    location: runtime.Source_Code_Location = #caller_location
) -> ([]byte, runtime.Allocator_Error) {
    allocator := transmute(^Thread_Safe_Allocator)allocator_data
    if sync.mutex_guard(&allocator.mutex) {
        return allocator.backing.procedure(
            allocator.backing.data,
            mode,
            size, alignment,
            old_memory,
            old_size,
            location
        )
    }
    unreachable()
}

init :: proc(a: ^Thread_Safe_Allocator, backing: runtime.Allocator) {
    a.backing = backing
    a.impl.data = a
    a.impl.procedure = allocator_proc
}

original :: proc(a: ^Thread_Safe_Allocator) -> runtime.Allocator {
    return a.backing
}