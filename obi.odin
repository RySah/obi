package obi

import "core:reflect"

import "base:runtime"

import "core:mem"
Allocator :: mem.Allocator
Allocator_Error :: mem.Allocator_Error

import ci "cimport"
C_Import_Error :: ci.Error
C_Import_Info :: ci.Import_Info

import cachefs "cache_fs"
Cache_File_System_Error :: cachefs.Error
Cache_File_System :: cachefs.File_System

Error :: union #shared_nil {
    C_Import_Error,
    Cache_File_System_Error,
    Allocator_Error
}

DEFAULT_CACHE_FILE_SYSTEM_PATH :: ".obi-cache"

Build_Context :: struct {
    allocator: Allocator,
    cache_file_system: Cache_File_System,
    c_import_infos: [dynamic]^C_Import_Info
}

create_build_context :: proc(allocator: Allocator, cache_file_system_path := DEFAULT_CACHE_FILE_SYSTEM_PATH) -> (ctx: Build_Context, err: Error) {
    ctx.allocator = allocator
    ctx.cache_file_system = cachefs.from(cache_file_system_path, ctx.allocator) or_return
    ctx.c_import_infos = make([dynamic]^C_Import_Info, ctx.allocator) or_return
    return ctx, nil
}

destroy_build_context :: proc(ctx: ^Build_Context) -> Error {
    cachefs.destroy(&ctx.cache_file_system) or_return
    for &p in ctx.c_import_infos do free(p, ctx.allocator) or_return
    delete(ctx.c_import_infos) or_return
    return nil
}

