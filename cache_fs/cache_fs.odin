package cache_fs

import "core:os/os2"
import "core:fmt"
import "core:strings"
import hashalgo "core:hash"
import "core:strconv"
import "core:mem"
import "core:path/filepath"
import "core:slice"

Error :: union #shared_nil {
    os2.Error,
    mem.Allocator_Error
}

File_System :: struct {
    allocator: mem.Allocator,
    path: string,
    owned_strings: [dynamic]string,
    children: [dynamic]File_System
}

// This procedure will not destroy its children.
destroy :: proc(system: ^File_System) -> (err: Error) {
    context.allocator = system.allocator
    for &s in system.owned_strings do delete(s)
    delete(system.owned_strings) or_return
    delete(system.children) or_return
    return nil
}

from :: proc(path: string, allocator: mem.Allocator) -> (system: File_System, err: Error) {
    system.allocator = allocator
    system.path = path
    system.owned_strings = make([dynamic]string, system.allocator) or_return
    system.children = make([dynamic]File_System, system.allocator) or_return

    if !os2.exists(system.path) {
        os2.make_directory(system.path) or_return
    }

    return system, nil
}

child :: proc(system: ^File_System, name: string) -> (child_system: File_System, err: Error) {
    context.allocator = system.allocator

    path := filepath.join({ system.path, name }) or_return
    append(&system.owned_strings, path) or_return
    child_system = from(path, system.allocator) or_return
    append(&system.children, child_system) or_return

    return child_system, nil
}

clear :: proc(system: ^File_System) -> Error {
    os2.remove_all(system.path) or_return
    os2.make_directory(system.path) or_return
    return nil
}

hashf :: proc(
    allocator: mem.Allocator,
    format: string,
    args: ..any
) -> (output: string, hash_v: u64, err: mem.Allocator_Error) {
    s := fmt.aprintf(format, ..args, allocator=allocator)
    hash_v = hashalgo.murmur64a(transmute([]byte)s)
    return s, hash_v, nil
}

hash :: proc(
    allocator: mem.Allocator,
    args: ..any, 
    sep := " "
) -> (output: string, hash_v: u64, err: mem.Allocator_Error) {
    s := fmt.aprint(..args, sep=sep,allocator=allocator)
    hash_v = hashalgo.murmur64a(transmute([]byte)s)
    return s, hash_v, nil
}

path_from_hash :: proc(system: ^File_System, hash_v: u64) -> (path: string, err: mem.Allocator_Error) {
    context.allocator = system.allocator

    hex_hash_buf: [16]byte
    hex_hash := strconv.write_uint(hex_hash_buf[:], hash_v, 16)

    filename := strings.concatenate({ hex_hash, ".txt" }) or_return
    defer delete(filename)

    path = filepath.join({ system.path, filename }) or_return
    for &other_string in system.owned_strings {
        if strings.compare(other_string, path) == 0 {
            delete(path)
            return other_string, nil
        }
    }
    append(&system.owned_strings, path) or_return
    return path, nil
}

hash_exists :: proc(system: ^File_System, hash_v: u64) -> bool {
    path, path_err := path_from_hash(system, hash_v)
    if path_err != nil do return false
    return os2.exists(path)
}

existsf :: proc(system: ^File_System, format: string, args: ..any) -> bool {
    s, hash_v, err := hashf(system.allocator, format, ..args)
    defer delete(s)
    if err != nil do return false
    return hash_exists(system, hash_v)
}

exists :: proc(system: ^File_System, args: ..any, sep:=" ") -> bool {
    s, hash_v, err := hash(system.allocator, ..args, sep=sep)
    defer delete(s)
    if err != nil do return false
    return hash_exists(system, hash_v)
}

cachef :: proc(
    system: ^File_System,
    format: string,
    args: ..any
) -> (path: string, err: Error) {
    context.allocator = system.allocator

    s, hash_v := hashf(system.allocator, format, ..args) or_return
    defer delete(s)
    
    path = path_from_hash(system, hash_v) or_return

    if !os2.exists(path) do os2.write_entire_file(path, s) or_return

    return path, nil
}

cache :: proc(
    system: ^File_System, 
    args: ..any, 
    sep := " "
) -> (path: string, err: Error) {
    context.allocator = system.allocator

    s, hash_v := hash(system.allocator, ..args, sep=sep) or_return
    defer delete(s)
    
    path = path_from_hash(system, hash_v) or_return

    if !os2.exists(path) do os2.write_entire_file(path, s) or_return

    return path, nil
}