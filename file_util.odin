package obi

import "core:os/os2"

File_Create :: struct {
    path: string,
    data: []byte,
    no_truncate: bool
}

file_create_to_step :: proc(ctx: ^Build_Context, fc: ^File_Create) -> (step: Step, err: Allocator_Error) {
    owned_fc := _manage_mem(ctx, fc) or_return
    step.client_data = owned_fc
    step.procedure = proc(ctx: ^Build_Context, client_data: rawptr) -> (success: bool, err: Error) {
        fc := transmute(^File_Create)client_data
        os2.write_entire_file_from_bytes(fc.path, fc.data, truncate=!fc.no_truncate) or_return
        return true, nil
    }
    return step, err
}
