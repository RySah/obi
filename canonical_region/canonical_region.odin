package canonical_region

import vmem "core:mem/virtual"
import "core:mem"
import "core:hash"
import "core:reflect"
import "core:strings"
import "core:fmt"

import "base:intrinsics"

Error :: vmem.Allocator_Error

Intern_Value :: struct { data: rawptr, size: int }

Intern :: struct {
    cache_map: map[u32][dynamic]Intern_Value,
    data_allocator: mem.Allocator
}

intern_destroy :: proc(m: ^Intern) -> Error {
    data_allocator_feat := mem.query_features(m.data_allocator)
    for h, values in m.cache_map {
        if .Free in data_allocator_feat {
            for &value in values {
                delete((transmute([^]byte)value.data)[:value.size], allocator=m.data_allocator) or_return
            }
        }
        delete(values)
    }
    delete(m.cache_map) or_return
    return nil
}

intern_init :: proc(m: ^Intern, data_allocator: mem.Allocator, allocator := context.allocator) {
    context.allocator = allocator
    m.cache_map = make(map[u32][dynamic]Intern_Value) 
    m.data_allocator = data_allocator
}

intern_add_value :: proc(m: ^Intern, v: Intern_Value) -> (out: Intern_Value, err: Error) #optional_allocator_error {
    value_bytes_ptr := transmute([^]byte)v.data
    value_bytes := value_bytes_ptr[:v.size]
    h := hash.murmur32(value_bytes)

    bucket, bucket_exists := &m.cache_map[h]
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
        new_bucket := make([dynamic]Intern_Value, m.cache_map.allocator) or_return
        append(&new_bucket, out) or_return
        m.cache_map[h] = new_bucket
    }

    return out, nil
}
intern_add_parapoly :: proc(m: ^Intern, v: $T/^$P) -> (out: Intern_Value, err: Error) #optional_allocator_error {
    return intern_add_value(m, parapoly_to_intern_value(v))
}
intern_add_string :: proc(m: ^Intern, v: string) -> (out: Intern_Value, err: Error) #optional_allocator_error {
    return intern_add_value(m, string_to_intern_value(v))
}
intern_add_cstring :: proc(m: ^Intern, v: cstring) -> (out: Intern_Value, err: Error) #optional_allocator_error {
    return intern_add_value(m, cstring_to_intern_value(v))
}
intern_add :: proc{intern_add_value,intern_add_parapoly,intern_add_string,intern_add_cstring}

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

Region :: struct {
    using arena: vmem.Arena,
    intern_pool: map[typeid]Intern
}

DEFAULT_GROWING_MINIMUM_BLOCK_SIZE : uint : vmem.DEFAULT_ARENA_GROWING_MINIMUM_BLOCK_SIZE

DEFAULT_STATIC_RESERVE_SIZE : uint : vmem.DEFAULT_ARENA_STATIC_RESERVE_SIZE
DEFAULT_STATIC_COMMIT_SIZE : uint : vmem.DEFAULT_ARENA_STATIC_COMMIT_SIZE

@(require_results, no_sanitize_address)
init_growing :: proc(
    collector: ^Region, 
    backing_allocator: mem.Allocator, 
    reserved: uint = DEFAULT_GROWING_MINIMUM_BLOCK_SIZE
) -> (err: Error) {
    collector.intern_pool = make(map[typeid]Intern, backing_allocator)
    return vmem.arena_init_growing(collector, reserved=reserved)
}

@(require_results, no_sanitize_address)
init_static :: proc(
    collector: ^Region, 
    backing_allocator: mem.Allocator, 
    reserved: uint = DEFAULT_STATIC_RESERVE_SIZE, 
    commit_size: uint = DEFAULT_STATIC_COMMIT_SIZE
) -> (err: Error) {
    collector.intern_pool = make(map[typeid]Intern, backing_allocator)
    return vmem.arena_init_static(collector, reserved=reserved, commit_size=commit_size)
}

@(require_results, no_sanitize_address)
init_buffer :: proc(
    collector: ^Region, 
    backing_allocator: mem.Allocator, 
    buffer: []byte
) -> (err: Error) {
    collector.intern_pool = make(map[typeid]Intern, backing_allocator)
    return vmem.arena_init_buffer(collector, buffer)
}

destroy :: proc(collector: ^Region) -> Error {
    vmem.arena_destroy(collector)
    for _, &intern in collector.intern_pool do intern_destroy(&intern) or_return
    delete(collector.intern_pool) or_return
    return nil
}

create_intern_map :: proc(collector: ^Region, T: typeid) -> (out: ^Intern) {
    collector.intern_pool[T] = Intern{}
    intern_init(&collector.intern_pool[T], vmem.arena_allocator(collector), allocator=collector.intern_pool.allocator)
    return &collector.intern_pool[T]
}

manage_immut :: proc(collector: ^Region, value: $T) -> (out: T, err: Error) where (intrinsics.type_is_string(T) || intrinsics.type_is_pointer(T)) && (!intrinsics.type_is_slice(T)) #optional_allocator_error {
    when intrinsics.type_is_pointer(T) && intrinsics.type_is_slice(intrinsics.type_elem_type(T)) {
        // Interning the internal slice is useless
        ptr := manage_mut(collector, value) or_return
        ptr^ = manage_immut_slice(collector, value^, false) or_return
        return ptr, nil
    } else {
        intern_map, intern_map_exists := &collector.intern_pool[typeid_of(T)]
        if !intern_map_exists do intern_map = create_intern_map(collector, typeid_of(T))

        intern_value := intern_add(intern_map, value) or_return

        when T == string {
            bytes_ptr := transmute([^]byte)intern_value.data
            return strings.string_from_ptr(bytes_ptr, intern_value.size), nil
        } else when T == cstring {
            bytes_ptr := transmute([^]byte)intern_value.data
            return cstring(bytes_ptr)
        } else { // T/^P
            return transmute(T)intern_value.data, nil
        }
    }
}
manage_immut_slice :: proc(collector: ^Region, value: $T/[]$E, $manage_elements: bool) -> (out: T, err: Error) #optional_allocator_error {
    // Slices should not be interned, as its meaningless
    new_slice := make([]E, len(value), mut_allocator(collector)) or_return
    when manage_elements {
        for &x, i in value {
            when intrinsics.type_is_slice(E) {
                new_slice[i] = manage_immut_slice(collector, x, manage_elements) or_return
            } else {
                new_slice[i] = manage_immut(collector, x) or_return
            }
        }
    } else {
        copy(new_slice, value)
    }
    return new_slice, nil
}

immut_print :: proc(collector: ^Region, args: ..any, sep := " ") -> (string, Error) {
    content := fmt.aprint(..args, sep=sep)
    defer delete(content)
    return manage_immut(collector, content)
}
immut_println :: proc(collector: ^Region, args: ..any, sep := " ") -> (string, Error) {
    content := fmt.aprintln(..args, sep=sep)
    defer delete(content)
    return manage_immut(collector, content)
}
immut_printf :: proc(collector: ^Region, fmt_: string, args: ..any, newline := false) -> (string, Error) {
    content := fmt.aprintf(fmt_, ..args, newline=newline)
    defer delete(content)
    return manage_immut(collector, content)
}
immut_printfln :: proc(collector: ^Region, fmt_: string, args: ..any) -> (string, Error) {
    content := fmt.aprintfln(fmt_, ..args)
    defer delete(content)
    return manage_immut(collector, content)
}
iprint :: immut_print
iprintln :: immut_println
iprintf :: immut_printf
iprintfln :: immut_printfln

manage_mut :: proc(collector: ^Region, value: $T) -> (out: T, err: Error) where (intrinsics.type_is_string(T) || intrinsics.type_is_pointer(T)) && (!intrinsics.type_is_slice(T)) #optional_allocator_error {
    when T == string {
        return strings.clone(value, allocator=mut_allocator(collector))
    } else when T == cstring {
        buf_size := len(value)
        copy_buf := transmute([^]byte)mem.alloc(buf_size, allocator=mut_allocator(collector)) or_return
        copy(copy_buf, transmute([^]byte)value, buf_size)
        return cstring(copy_buf), nil
    } else { // T/^P
        return new_clone(value^, allocator=mut_allocator(collector))
    }
}
manage_mut_slice :: proc(collector: ^Region, value: $T/[]$E, $manage_elements: bool) -> (out: T, err: Error) where (intrinsics.type_is_string(E) || intrinsics.type_is_pointer(E)) && (intrinsics.type_is_slice(T)) #optional_allocator_error {
    new_slice := make([]E, len(value), mut_allocator(collector)) or_return
    when manage_elements {
        for &x, i in value {
            when intrinsics.type_is_slice(E) {
                new_slice[i] = manage_mut_slice(collector, x, manage_elements) or_return
            } else {
                new_slice[i] = manage_mut(collector, x) or_return
            }
        }
    } else {
        copy(new_slice, value)
    }
    return new_slice, nil
}

@(require_results, no_sanitize_address)
mut_allocator :: proc(collector: ^Region) -> mem.Allocator { return vmem.arena_allocator(collector) }

mut_print :: proc(collector: ^Region, args: ..any, sep := " ") -> string {
    return fmt.aprint(..args, sep=sep, allocator=mut_allocator(collector))
}
mut_println :: proc(collector: ^Region, args: ..any, sep := " ") -> string {
    return fmt.aprintln(..args, sep=sep, allocator=mut_allocator(collector))
}
mut_printf :: proc(collector: ^Region, fmt_: string, args: ..any, newline := false) -> string {
    return fmt.aprintf(fmt_, ..args, newline=newline, allocator=mut_allocator(collector))
}
mut_printfln :: proc(collector: ^Region, fmt_: string, args: ..any) -> string {
    return fmt.aprintfln(fmt_, ..args, allocator=mut_allocator(collector))
}
mprint :: mut_print
mprintln :: mut_println
mprintf :: mut_printf
mprintfln :: mut_printfln
