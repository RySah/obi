package garbage_collector

import vmem "core:mem/virtual"
import "core:mem"
import "core:hash"
import "core:reflect"
import "core:strings"

import "base:intrinsics"

Error :: vmem.Allocator_Error

Intern_Value :: struct { data: rawptr, size: int }

Intern_Map :: map[u32][dynamic]Intern_Value

intern_map_add_value :: proc(m: ^Intern_Map, v: Intern_Value) -> (out: Intern_Value, err: Error) #optional_allocator_error {
    value_bytes_ptr := transmute([^]byte)v.data
    value_bytes := value_bytes_ptr[:v.size]
    h := hash.murmur32(value_bytes)

    bucket, bucket_exists := &m[h]
    if bucket_exists {
        for interned in bucket {
            interned_bytes_ptr := transmute([^]byte)interned.data
            interned_bytes := interned_bytes_ptr[:interned.size]
            if mem.compare(value_bytes, interned_bytes) == 0 do return interned, nil
        }
    }

    out.size = v.size
    out.data = mem.alloc(v.size, allocator=m.allocator) or_return
    mem.copy(out.data, v.data, v.size)
    if bucket_exists {
        append(bucket, out) or_return
    } else {
        new_bucket := make([dynamic]Intern_Value, m.allocator) or_return
        append(&new_bucket, out) or_return
        m[h] = new_bucket
    }

    return out, nil
}
intern_map_add_parapoly :: proc(m: ^Intern_Map, v: $T/^$P) -> (out: Intern_Value, err: Error) #optional_allocator_error {
    return intern_map_add_value(m, parapoly_to_intern_value(v))
}
intern_map_add_string :: proc(m: ^Intern_Map, v: string) -> (out: Intern_Value, err: Error) #optional_allocator_error {
    return intern_map_add_value(m, string_to_intern_value(v))
}
intern_map_add_cstring :: proc(m: ^Intern_Map, v: cstring) -> (out: Intern_Value, err: Error) #optional_allocator_error {
    return intern_map_add_value(m, cstring_to_intern_value(v))
}
intern_map_add :: proc{intern_map_add_value,intern_map_add_parapoly,intern_map_add_string,intern_map_add_cstring}

any_to_intern_value :: proc(v: any) -> (out: Intern_Value) {
    out.size = reflect.size_of_typeid(v.id)
    out.data = v.data
    return
}
parapoly_to_intern_value :: proc(v: $T/^$P) -> (out: Intern_Value) {
    out.size = size_of(P)
    out.data = v
    return
}
string_to_intern_value :: proc(v: string) -> (out: Intern_Value) {
    out.size = len(v)
    out.data = raw_data(v)
    return
}
cstring_to_intern_value :: proc(v: cstring) -> (out: Intern_Value) {
    out.size = len(v)
    out.data = transmute([^]byte)v
    return
}
to_intern_value :: proc{any_to_intern_value,parapoly_to_intern_value,string_to_intern_value,cstring_to_intern_value}

Garbage_Collector :: struct {
    using arena: vmem.Arena,
    intern_pool: map[typeid]Intern_Map
}

DEFAULT_GROWING_MINIMUM_BLOCK_SIZE : uint : vmem.DEFAULT_ARENA_GROWING_MINIMUM_BLOCK_SIZE

DEFAULT_STATIC_RESERVE_SIZE : uint : vmem.DEFAULT_ARENA_STATIC_RESERVE_SIZE
DEFAULT_STATIC_COMMIT_SIZE : uint : vmem.DEFAULT_ARENA_STATIC_COMMIT_SIZE

@(require_results, no_sanitize_address)
init_growing :: proc(
    collector: ^Garbage_Collector, 
    backing_allocator: mem.Allocator, 
    reserved: uint = DEFAULT_GROWING_MINIMUM_BLOCK_SIZE
) -> (err: Error) {
    collector.intern_pool = make(map[typeid]Intern_Map, backing_allocator)
    return vmem.arena_init_growing(collector, reserved=reserved)
}

@(require_results, no_sanitize_address)
init_static :: proc(
    collector: ^Garbage_Collector, 
    backing_allocator: mem.Allocator, 
    reserved: uint = DEFAULT_STATIC_RESERVE_SIZE, 
    commit_size: uint = DEFAULT_STATIC_COMMIT_SIZE
) -> (err: Error) {
    collector.intern_pool = make(map[typeid]Intern_Map, backing_allocator)
    return vmem.arena_init_static(collector, reserved=reserved, commit_size=commit_size)
}

@(require_results, no_sanitize_address)
init_buffer :: proc(
    collector: ^Garbage_Collector, 
    backing_allocator: mem.Allocator, 
    buffer: []byte
) -> (err: Error) {
    collector.intern_pool = make(map[typeid]Intern_Map, backing_allocator)
    return vmem.arena_init_buffer(collector, buffer)
}


collect :: vmem.arena_free_all

destroy :: vmem.arena_destroy

create_intern_map :: proc(collector: ^Garbage_Collector, T: typeid) -> (out: ^Intern_Map) {
    collector.intern_pool[T] = make(Intern_Map, collector.intern_pool.allocator)
    return &collector.intern_pool[T]
}

can_manage :: proc($T: typeid) -> bool {
    return (intrinsics.type_is_string(T) || intrinsics.type_is_pointer(T)) && T != Intern_Value 
}

manage_immut :: proc(collector: ^Garbage_Collector, value: $T) -> (out: T, err: Error) where can_manage(T) #optional_allocator_error {
    intern_map, intern_map_exists := collector.intern_pool[typeid_of(T)]
    if !intern_map_exists do intern_map = create_intern_map(collector, typeid_of(T))

    intern_value := intern_map_add(intern_map, value) or_return

    when T == string {
        bytes_ptr := transmute([^]byte)intern_value.data
        return strings.string_from_ptr(bytes_ptr, intern_value.size)
    } else when T == cstring {
        bytes_ptr := transmute([^]byte)intern_value.data
        return cstring(bytes_ptr)
    } else { // T/^P
        return transmute(T)intern_value.data
    }
}

manage_mut :: proc(collector: ^Garbage_Collector, value: $T) -> (out: T, err: Error) where can_manage(T) #optional_allocator_error {
    when T == string {
        return strings.clone(value, allocator=vmem.arena_allocator(collector))
    } else when T == cstring {
        buf_size := len(value)
        copy_buf := transmute([^]byte)mem.alloc(buf_size, allocator=vmem.arena_allocator(collector)) or_return
        copy(copy_buf, transmute([^]byte)value, buf_size)
        return cstring(copy_buf), nil
    } else { // T/^P
        return new_clone(value^, allocator=vmem.arena_allocator(collector))
    }
}
