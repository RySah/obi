package incremental

import "core:os/os2"
import "core:path/filepath"
import "core:time"
import ia "../intern_arena"
import "chunk"
import cachefs "../cache_fs"

import "base:runtime"

Error :: ia.Error

File_Dep :: distinct string
Dir_Dep :: struct {
    path: string,
    expand_options: Maybe(Expand_Options)
}

Dep :: union {
    File_Dep,
    Dir_Dep
}

Dep_Collection :: struct {
    buffer: [dynamic]Dep,
    arena: ia.Arena
}

Expanded_Dep_Collection :: struct {
    buffer: [dynamic]Dep,
    mtime_buffer: [dynamic]time.Time
}

Preprocessed_Dep_Collection :: distinct [dynamic]Dep

init_growing :: proc(d: ^Dep_Collection, allocator := context.allocator) -> Error {
    d.buffer = make([dynamic]Dep, allocator=allocator) or_return
    ia.init_growing(&d.arena, allocator) or_return
    return nil
}
init_static :: proc(d: ^Dep_Collection, allocator := context.allocator) -> Error {
    d.buffer = make([dynamic]Dep, allocator=allocator) or_return
    ia.init_static(&d.arena, allocator) or_return
    return nil
}
init_buffer :: proc(d: ^Dep_Collection, buffer: []byte, allocator := context.allocator) -> Error {
    d.buffer = make([dynamic]Dep, allocator=allocator) or_return
    ia.init_buffer(&d.arena, allocator, buffer) or_return
    return nil
}

destroy_collection :: proc(d: ^Dep_Collection) -> Error {
    delete(d.buffer) or_return
    ia.destroy(&d.arena) or_return
    return nil
}

destroy_expanded :: proc(d: ^Expanded_Dep_Collection) -> Error {
    delete(d.buffer) or_return
    delete(d.mtime_buffer) or_return
    return nil
}

destroy_preprocessed :: proc(d: ^Preprocessed_Dep_Collection) -> Error {
    delete(d^) or_return
    return nil
}

destroy :: proc{destroy_collection,destroy_expanded,destroy_preprocessed}

Expand_Options :: struct {
    include, ignore: []string
}

DEFAULT_EXPAND_OPTIONS : Expand_Options : {
    include={"*"}, ignore={}
}

expand :: proc(
    collection: ^Dep_Collection, 
    allocator := context.allocator, 
    options := DEFAULT_EXPAND_OPTIONS
) -> (out: Expanded_Dep_Collection, err: Error) #optional_allocator_error {
    context.allocator = allocator
    
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

    out.buffer = make([dynamic]Dep, 0, len(collection.buffer)/4) or_return
    out.mtime_buffer = make([dynamic]time.Time, 0, len(collection.buffer)/4) or_return
    
    for &dep in collection.buffer {
        switch &internal_dep in dep {
        case File_Dep:
            path := transmute(string)internal_dep
            if _should_include(path, &options) {
                mtime, mtime_err := os2.modification_time_by_path(path)
                if mtime_err != nil do mtime = time.now() 
                append(&out.buffer, File_Dep(
                    ia.intern_string(&collection.arena, path) or_return
                )) or_return
                append(&out.mtime_buffer, mtime) or_return
            }
        case Dir_Dep:
            local_options := (internal_dep.expand_options.? or_else options)

            walker := os2.walker_create(internal_dep.path)
            defer os2.walker_destroy(&walker)

            for info in os2.walker_walk(&walker) {
                if info.type == .Regular {
                    if _should_include(info.fullpath, &local_options) {
                        append(&out.buffer, File_Dep(
                            ia.intern_string(&collection.arena, info.fullpath) or_return
                        )) or_return
                        append(&out.mtime_buffer, info.modification_time) or_return
                    }
                }
            }

            _ = os2.walker_error(&walker) or_continue
        }
    }

    return out, nil
}

preprocess_expanded :: proc(
    collection: ^Expanded_Dep_Collection,
    old_mtimes: []time.Time,
    allocator := context.allocator
) -> (out: Preprocessed_Dep_Collection, err: Error) #optional_allocator_error {
    context.allocator = allocator
    out = make(Preprocessed_Dep_Collection) or_return

    assert(len(collection.mtime_buffer) == len(collection.buffer))

    for &dep, i in collection.buffer {
        if time.duration_microseconds(time.diff(old_mtimes[i], collection.mtime_buffer[i])) > 0 { // Maybe changed
            append(&out, dep) or_return
        }
    }

    return out, nil
}


