package cache_fs

import "core:os/os2"
import "core:fmt"
import "core:strings"
import "core:hash"
import "core:strconv"
import "core:mem"
import "core:path/filepath"

Error :: union #shared_nil {
    os2.Error,
    mem.Allocator_Error
}

File_System :: struct {
    path: string
}

clear :: proc(system: ^File_System) -> Error {
    os2.remove_all(system.path) or_return
    os2.make_directory(system.path) or_return
    return nil
}

cachef :: proc(
    system: ^File_System, 
    allocator: mem.Allocator, 
    format: string,
    args: ..any
) -> (path: string, err: Error) {
    sb := strings.builder_make() or_return
    defer strings.builder_destroy(&sb)

    s := fmt.sbprintf(&sb, format, ..args)
    hash_v := hash.murmur64a(transmute([]byte)s)
    hex_hash_buf: [16]byte
    hex_hash := strconv.write_uint(hex_hash_buf[:], hash_v, 16)

    filename := strings.concatenate({ hex_hash, ".txt" }) or_return
    defer delete(filename)

    path = filepath.join({ system.path, filename }) or_return

    if !os2.exists(path) do os2.write_entire_file(path, s) or_return

    return path, nil
}

cache :: proc(
    system: ^File_System, 
    allocator: mem.Allocator, 
    args: ..any, 
    sep := " "
) -> (path: string, err: Error) {
    sb := strings.builder_make() or_return
    defer strings.builder_destroy(&sb)

    s := fmt.sbprint(&sb, ..args, sep=sep)
    hash_v := hash.murmur64a(transmute([]byte)s)
    hex_hash_buf: [16]byte
    hex_hash := strconv.write_uint(hex_hash_buf[:], hash_v, 16)

    filename := strings.concatenate({ hex_hash, ".txt" }) or_return
    defer delete(filename)

    path = filepath.join({ system.path, filename }) or_return

    if !os2.exists(path) do os2.write_entire_file(path, s) or_return

    return path, nil
}