package intern_arena

import vmem "core:mem/virtual"
import "core:mem"
import "core:hash"
import "core:slice"
import "core:strings"
import "core:fmt"

import "base:intrinsics"

Error :: vmem.Allocator_Error

Intern_Entry :: struct { data: rawptr, size: int }

Intern_Pool :: struct {
    buckets: map[u32][dynamic]Intern_Entry,
    data_allocator: mem.Allocator
}

intern_pool_destroy :: proc(m: ^Intern_Pool) -> Error {
    data_allocator_feat := mem.query_features(m.data_allocator)
    for h, values in m.buckets {
        if .Free in data_allocator_feat {
            for &value in values {
                delete((transmute([^]byte)value.data)[:value.size], allocator=m.data_allocator) or_return
            }
        }
        delete(values)
    }
    delete(m.buckets) or_return
    return nil
}

intern_pool_init :: proc(m: ^Intern_Pool, data_allocator: mem.Allocator, allocator := context.allocator) {
    context.allocator = allocator
    m.buckets = make(map[u32][dynamic]Intern_Entry) 
    m.data_allocator = data_allocator
}

intern_pool_add_value :: proc(m: ^Intern_Pool, v: Intern_Entry) -> (out: Intern_Entry, err: Error) #optional_allocator_error {
    value_bytes_ptr := transmute([^]byte)v.data
    value_bytes := value_bytes_ptr[:v.size]
    h := hash.murmur32(value_bytes)

    bucket, bucket_exists := &m.buckets[h]
    if bucket_exists {
        for interned in bucket {
            interned_bytes_ptr := transmute([^]byte)interned.data
            interned_bytes := interned_bytes_ptr[:interned.size]
            if mem.compare(value_bytes, interned_bytes) == 0 do return interned, nil
        }
    }

    out.size = v.size
    out.data = mem.alloc(v.size, allocator=m.data_allocator) or_return
    mem.copy(out.data, v.data, v.size)
    if bucket_exists {
        append(bucket, out) or_return
    } else {
        new_bucket := make([dynamic]Intern_Entry, m.buckets.allocator) or_return
        append(&new_bucket, out) or_return
        m.buckets[h] = new_bucket
    }

    return out, nil
}
intern_pool_add_parapoly :: proc(m: ^Intern_Pool, v: $T/^$P) -> (out: Intern_Entry, err: Error) #optional_allocator_error {
    return intern_pool_add_value(m, parapoly_to_intern_entry(v))
}
intern_pool_add_string :: proc(m: ^Intern_Pool, v: string) -> (out: Intern_Entry, err: Error) #optional_allocator_error {
    return intern_pool_add_value(m, string_to_intern_entry(v))
}
intern_pool_add_cstring :: proc(m: ^Intern_Pool, v: cstring) -> (out: Intern_Entry, err: Error) #optional_allocator_error {
    return intern_pool_add_value(m, cstring_to_intern_entry(v))
}
intern_pool_add :: proc{intern_pool_add_value,intern_pool_add_parapoly,intern_pool_add_string,intern_pool_add_cstring}

parapoly_to_intern_entry :: proc(v: $T/^$P) -> (out: Intern_Entry) {
    out.size = size_of(P)
    out.data = v
    return
}
string_to_intern_entry :: proc(v: string) -> (out: Intern_Entry) {
    out.size = len(v)
    out.data = raw_data(v)
    return
}
cstring_to_intern_entry :: proc(v: cstring) -> (out: Intern_Entry) {
    out.size = len(v)
    out.data = transmute([^]byte)v
    return
}
to_intern_entry :: proc{parapoly_to_intern_entry,string_to_intern_entry,cstring_to_intern_entry}

Arena :: struct {
    using arena: vmem.Arena,
    intern_pools: map[typeid]Intern_Pool
}

DEFAULT_GROWING_MINIMUM_BLOCK_SIZE : uint : vmem.DEFAULT_ARENA_GROWING_MINIMUM_BLOCK_SIZE

DEFAULT_STATIC_RESERVE_SIZE : uint : vmem.DEFAULT_ARENA_STATIC_RESERVE_SIZE
DEFAULT_STATIC_COMMIT_SIZE : uint : vmem.DEFAULT_ARENA_STATIC_COMMIT_SIZE

@(require_results, no_sanitize_address)
init_growing :: proc(
    arena: ^Arena, 
    backing_allocator: mem.Allocator, 
    reserved: uint = DEFAULT_GROWING_MINIMUM_BLOCK_SIZE
) -> (err: Error) {
    arena.intern_pools = make(map[typeid]Intern_Pool, backing_allocator)
    return vmem.arena_init_growing(arena, reserved=reserved)
}

@(require_results, no_sanitize_address)
init_static :: proc(
    arena: ^Arena, 
    backing_allocator: mem.Allocator, 
    reserved: uint = DEFAULT_STATIC_RESERVE_SIZE, 
    commit_size: uint = DEFAULT_STATIC_COMMIT_SIZE
) -> (err: Error) {
    arena.intern_pools = make(map[typeid]Intern_Pool, backing_allocator)
    return vmem.arena_init_static(arena, reserved=reserved, commit_size=commit_size)
}

@(require_results, no_sanitize_address)
init_buffer :: proc(
    arena: ^Arena, 
    backing_allocator: mem.Allocator, 
    buffer: []byte
) -> (err: Error) {
    arena.intern_pools = make(map[typeid]Intern_Pool, backing_allocator)
    return vmem.arena_init_buffer(arena, buffer)
}

destroy :: proc(arena: ^Arena) -> Error {
    vmem.arena_destroy(arena)
    for _, &intern in arena.intern_pools do intern_pool_destroy(&intern) or_return
    delete(arena.intern_pools) or_return
    return nil
}

create_intern_pool :: proc(arena: ^Arena, T: typeid) -> (out: ^Intern_Pool) {
    assert(T not_in arena.intern_pools, "Intern pool for this type already exists.")
    arena.intern_pools[T] = Intern_Pool{}
    intern_pool_init(&arena.intern_pools[T], vmem.arena_allocator(arena), allocator=arena.intern_pools.allocator)
    return &arena.intern_pools[T]
}

intern_string :: proc(arena: ^Arena, entry: string) -> (out: string, err: Error) #optional_allocator_error {
    intern_pool, intern_pool_exists := &arena.intern_pools[string]
    if !intern_pool_exists do intern_pool = create_intern_pool(arena, string)

    intern_v := intern_pool_add(intern_pool, entry) or_return

    bytes_ptr := transmute([^]byte)intern_v.data
    return strings.string_from_ptr(bytes_ptr, intern_v.size), nil
}
intern_cstring :: proc(arena: ^Arena, entry: cstring) -> (out: cstring, err: Error) #optional_allocator_error {
    intern_pool, intern_pool_exists := &arena.intern_pools[string]
    if !intern_pool_exists do intern_pool = create_intern_pool(arena, string)

    intern_v := intern_pool_add(intern_pool, entry) or_return

    bytes_ptr := transmute([^]byte)intern_v.data
    return cstring(bytes_ptr), nil
}
intern_ptr :: proc(arena: ^Arena, entry: $T/^$P) -> (out: T, err: Error) #optional_allocator_error {
    intern_pool, intern_pool_exists := &arena.intern_pools[T]
    if !intern_pool_exists do intern_pool = create_intern_pool(arena, T)

    intern_v := intern_pool_add(intern_pool, entry) or_return

    return transmute(T)intern_v.data, nil
}
intern_multi_ptr :: #force_inline proc(arena: ^Arena, entry: $T/[^]$E) -> (out: T, err: Error) #optional_allocator_error {
    return intern_ptr(arena, transmute(^E)entry)
}
intern_by_value :: proc{intern_string,intern_cstring,intern_ptr,intern_multi_ptr}

intern_value :: proc(arena: ^Arena, entry: $T) -> (out: ^T, err: Error) 
where !intrinsics.type_is_pointer(T) && !intrinsics.type_is_multi_pointer(T) && 
      !intrinsics.type_is_string(T) && !intrinsics.type_is_array(T) && 
      !intrinsics.type_is_slice(T) #optional_allocator_error {
    entry := entry
    return intern_by_value(arena, &entry)
}

clone_string :: proc(arena: ^Arena, entry: string) -> (out: string, err: Error) #optional_allocator_error {
    return strings.clone(entry, allocator=vmem.arena_allocator(arena))
}
clone_cstring :: proc(arena: ^Arena, entry: cstring) -> (out: cstring, err: Error) #optional_allocator_error {
    return cstring(raw_data(slice.clone((transmute([^]u8)entry)[:len(entry)], allocator=vmem.arena_allocator(arena)) or_return)), nil
}
clone_slice :: proc(arena: ^Arena, entry: $T/[]$E) -> (out: T, err: Error) #optional_allocator_error {
    return slice.clone(entry, allocator=vmem.arena_allocator(arena))
}
clone_ptr :: proc(arena: ^Arena, entry: $T/^$P) -> (out: T, err: Error) #optional_allocator_error {
    out = new(P) or_return
    out^ = entry^
    return out, nil
}
clone_multi_ptr :: #force_inline proc(arena: ^Arena, entry: $T/[^]$E) -> (out: T, err: Error) #optional_allocator_error {
    return clone_ptr(arena, transmute(^E)entry)
}
clone_by_value :: proc{clone_string,clone_cstring,clone_slice,clone_ptr,clone_multi_ptr}

clone_value :: proc(arena: ^Arena, entry: $T) -> (out: ^T, err: Error) 
where !intrinsics.type_is_pointer(T) && !intrinsics.type_is_multi_pointer(T) && 
      !intrinsics.type_is_string(T) && !intrinsics.type_is_array(T) && 
      !intrinsics.type_is_slice(T) #optional_allocator_error {
    entry := entry
    return clone_by_value(arena, &entry)
}

print :: proc(arena: ^Arena, args: ..any, sep := " ") -> (string, Error) {
    content := fmt.aprint(..args, sep=sep)
    defer delete(content)
    return clone_by_value(arena, content)
}
println :: proc(arena: ^Arena, args: ..any, sep := " ") -> (string, Error) {
    content := fmt.aprintln(..args, sep=sep)
    defer delete(content)
    return clone_by_value(arena, content)
}
printf :: proc(arena: ^Arena, fmt_: string, args: ..any, newline := false) -> (string, Error) {
    content := fmt.aprintf(fmt_, ..args, newline=newline)
    defer delete(content)
    return clone_by_value(arena, content)
}
printfln :: proc(arena: ^Arena, fmt_: string, args: ..any) -> (string, Error) {
    content := fmt.aprintfln(fmt_, ..args)
    defer delete(content)
    return clone_by_value(arena, content)
}

intern_print :: proc(arena: ^Arena, args: ..any, sep := " ") -> (string, Error) {
    content := fmt.aprint(..args, sep=sep)
    defer delete(content)
    return intern_by_value(arena, content)
}
intern_println :: proc(arena: ^Arena, args: ..any, sep := " ") -> (string, Error) {
    content := fmt.aprintln(..args, sep=sep)
    defer delete(content)
    return intern_by_value(arena, content)
}
intern_printf :: proc(arena: ^Arena, fmt_: string, args: ..any, newline := false) -> (string, Error) {
    content := fmt.aprintf(fmt_, ..args, newline=newline)
    defer delete(content)
    return intern_by_value(arena, content)
}
intern_printfln :: proc(arena: ^Arena, fmt_: string, args: ..any) -> (string, Error) {
    content := fmt.aprintfln(fmt_, ..args)
    defer delete(content)
    return intern_by_value(arena, content)
}
iprint :: intern_print
iprintln :: intern_println
iprintf :: intern_printf
iprintfln :: intern_printfln

allocator :: vmem.arena_allocator