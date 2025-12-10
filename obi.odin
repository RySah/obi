package obi

import "core:reflect"
import "core:path/filepath"

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
DEFAULT_C_IMPORT_OUTPUT_PATH :: "c_api"

Build_Context :: struct {
    allocator: Allocator,
    owned_strings: [dynamic]string,
    cache_file_system: Cache_File_System,
    c_import_infos: [dynamic]^C_Import_Info,
    c_import_output_path: string
}

create_build_context :: proc(
    allocator: Allocator, 
    cache_file_system_path := DEFAULT_CACHE_FILE_SYSTEM_PATH, 
    c_import_output_path := DEFAULT_C_IMPORT_OUTPUT_PATH
) -> (ctx: Build_Context, err: Error) {
    ctx.allocator = allocator
    ctx.owned_strings = make([dynamic]string, ctx.allocator) or_return
    ctx.cache_file_system = cachefs.from(cache_file_system_path, ctx.allocator) or_return
    ctx.c_import_infos = make([dynamic]^C_Import_Info, ctx.allocator) or_return
    ctx.c_import_output_path = c_import_output_path
    return ctx, nil
}

destroy_build_context :: proc(ctx: ^Build_Context) -> Error {
    for &s in ctx.owned_strings do delete(s, ctx.allocator) or_return
    delete(ctx.owned_strings) or_return

    cachefs.destroy(&ctx.cache_file_system) or_return
    
    for &p in ctx.c_import_infos {
        if p == nil do continue
        ci.destroy_import_info(p) or_return
        free(p, ctx.allocator) or_return
    }
    delete(ctx.c_import_infos) or_return
    
    return nil
}

build :: proc(ctx: ^Build_Context) {
    for &info in ctx.c_import_infos {
        ci.import_info(info, ctx.allocator)
    }
}

/* Include header file paths, or directory paths (all header files will be captured) to `C_Import_Info` object.
*/
c_include :: ci.include

/* Creates and manages a new `C_Import_Info` object. You can edit the properties of `info` to adjust how you want the specified headers to be parsed.
   To add more include paths later, use `c_include`.
*/
c_import :: proc(ctx: ^Build_Context, package_name: string, include_paths: ..string) -> (info: ^C_Import_Info, err: Error) {
    info = ci.make_import_info(&ctx.cache_file_system, ctx.allocator) or_return
    info.package_name = package_name
    info.output_folder = filepath.join({ ctx.c_import_output_path, info.package_name }, ctx.allocator) or_return
    append(&ctx.owned_strings, info.output_folder) or_return
    append(&ctx.c_import_infos, info) or_return
    c_include(info, ..include_paths) or_return
    return info, nil
}

