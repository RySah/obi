package incremental

import "core:os/os2"
import "core:path/filepath"
import "../thread_safe/allocator"
import ia "../intern_arena"

Error :: ia.Error

File_Dependency :: distinct string
Directory_Dependency :: struct {
    path: string,
    expand_options: Maybe(Expand_Options)
}

Dependency :: union {
    File_Dependency,
    Directory_Dependency
}

Dependency_Collection :: struct {
    buffer: [dynamic]Dependency,
    arena: ia.Arena
}

Expanded_Dependency_Collection :: distinct [dynamic]Dependency

init_growing :: proc(d: ^Dependency_Collection, allocator := context.allocator) -> Error {
    d.buffer = make([dynamic]Dependency, allocator=allocator) or_return
    ia.init_growing(&d.arena, allocator) or_return
    return nil
}
init_static :: proc(d: ^Dependency_Collection, allocator := context.allocator) -> Error {
    d.buffer = make([dynamic]Dependency, allocator=allocator) or_return
    ia.init_static(&d.arena, allocator) or_return
    return nil
}
init_buffer :: proc(d: ^Dependency_Collection, buffer: []byte, allocator := context.allocator) -> Error {
    d.buffer = make([dynamic]Dependency, allocator=allocator) or_return
    ia.init_buffer(&d.arena, allocator, buffer) or_return
    return nil
}

destroy :: proc(d: ^Dependency_Collection) -> Error {
    delete(d.buffer) or_return
    ia.destroy(&d.arena) or_return
    return nil
}

Expand_Options :: struct {
    include, ignore: []string
}

DEFAULT_EXPAND_OPTIONS : Expand_Options : {
    include={"*"}, ignore={}
}

expand :: proc(collection: ^Dependency_Collection, options := DEFAULT_EXPAND_OPTIONS) -> (e: ^Expanded_Dependency_Collection, err: Error) #optional_allocator_error {
    _should_include :: proc(name: string, options: ^Expand_Options) -> bool {
        for &ignore_pattern in options.ignore {
            result, err := filepath.match(ignore_pattern, name)
            if err == nil && result do return false
        }
        for &include_patten in options.include {
            result, err := filepath.match(include_patten, name)
            if err == nil && result do return true
        }
        return false
    }
    
    options := options
    cutoff_i := len(collection.buffer)
    
    for &dep in collection.buffer[:cutoff_i] {
        switch &internal_dep in dep {
        case File_Dependency:
            path := transmute(string)internal_dep
            if _should_include(path, &options) do append(&collection.buffer, File_Dependency(
                ia.intern_string(&collection.arena, path) or_return
            )) or_return
        case Directory_Dependency:
            local_options := (internal_dep.expand_options.? or_else options)

            walker := os2.walker_create(internal_dep.path)
            defer os2.walker_destroy(&walker)

            for info in os2.walker_walk(&walker) {
                if info.type == .Regular {
                    if _should_include(info.fullpath, &local_options) do append(&collection.buffer, File_Dependency(
                        ia.intern_string(&collection.arena, info.fullpath) or_return
                    )) or_return
                }
            }

            _ = os2.walker_error(&walker) or_continue
        }
    }

    remove_range(&collection.buffer, 0, cutoff_i)
    return transmute(^Expanded_Dependency_Collection)(&collection.buffer), nil
}

Fingerprint :: distinct u64

