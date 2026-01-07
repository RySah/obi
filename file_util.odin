package obi

import "core:os/os2"
import gc "garbage_collector"

File_Create :: struct {
    path: string,
    data: []byte,
    no_truncate: bool
}

file_create_to_step :: proc(ctx: ^Build_Context, fc: ^File_Create, caller_location := #caller_location) -> (step: ^Step, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    owned_fc := gc.manage_mut(&ctx.garbage_collector, fc) or_return
    owned_fc.path = gc.manage_immut(&ctx.garbage_collector, fc.path) or_return
    owned_fc.data = gc.manage_immut_slice(&ctx.garbage_collector, fc.data, false) or_return
    step = create_step(ctx) or_return
    step.client_data = owned_fc
    step.procedure = proc(ctx: ^Build_Context, client_data: rawptr) -> (success: bool, err: Error) {
        fc := transmute(^File_Create)client_data
        ta_os2_write_entire_file(fc.path, fc.data, truncate=!fc.no_truncate) or_return
        return true, nil
    }
    return step, err
}

MkDir :: struct {
    path: string,
    // If set to true, makes a new directory, creating new intervening directories when needed.
    all: bool
}

mkdir_to_step :: proc(ctx: ^Build_Context, mkdir: ^MkDir, caller_location := #caller_location) -> (step: ^Step, err: Allocator_Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    owned_mkdir := gc.manage_mut(&ctx.garbage_collector, mkdir) or_return
    owned_mkdir.path = gc.manage_immut(&ctx.garbage_collector, mkdir.path) or_return
    step = create_step(ctx) or_return
    step.client_data = owned_mkdir
    step.procedure = proc(ctx: ^Build_Context, client_data: rawptr) -> (success: bool, err: Error) {
        mkdir := transmute(^MkDir)client_data
        if mkdir.all {
            ta_os2_make_directory_all(mkdir.path) or_return
        } else {
            ta_os2_make_directory(mkdir.path) or_return
        }
        return true, nil
    }
    return step, err
}