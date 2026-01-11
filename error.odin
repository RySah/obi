package obi

import "core:strings"
import "core:os/os2"
import "core:io"
import "core:fmt"
import "core:encoding/json"
import "core:flags"

import "base:runtime"

import vs "visual_studio"
import ia "intern_arena"
import cu "bindgen/c/clang_util"
import lc "bindgen/c/clang_util/libclang"

// Takes an error and provides more context on which PACKAGE it may have come from.
sb_expand_error :: proc(err: Error, sb: ^strings.Builder) {
    switch underlying_err1 in err {
        case Object_Error:
            fmt.sbprint(sb, "obi.Object_Error -> ", underlying_err1, sep="")
        case General_Error:
            fmt.sbprint(sb, "obi.General_Error -> ", underlying_err1)
        case C_Bindgen_Parser_Error:
            fmt.sbprint(sb, "bindgen_c.Parser_Error -> ")
            switch underlying_err2 in underlying_err1 {
                case cu.Error:
                    fmt.sbprint(sb, "clang_util.Error -> ")
                    switch underlying_err3 in underlying_err2 {
                        case lc.Error_Code:
                            fmt.sbprint(sb, "clang_util.Error -> ", underlying_err3, sep="")
                        case Allocator_Error:
                            sb_expand_error(underlying_err3, sb)
                    }
                case Allocator_Error:
                    sb_expand_error(underlying_err2, sb)
            }
        case Cache_File_System_Error:
            fmt.sbprint(sb, "cachefs.Error -> ")
            switch underlying_err2 in underlying_err1 {
                case os2.Error:
                    sb_expand_error(underlying_err2, sb)
                case Allocator_Error:
                    sb_expand_error(underlying_err2, sb)
            }
        case Sub_Process_Error: // Same as `os2.Error`
            fmt.sbprint(sb, "subprocess.Error/os2.Error -> ")
            switch underlying_err2 in underlying_err1 {
                case os2.General_Error:
                    fmt.sbprint(sb, "os2.General_Error -> ", underlying_err2, sep="")
                case io.Error:
                    fmt.sbprint(sb, "io.Error -> ", underlying_err2, sep="")
                case Allocator_Error:
                    sb_expand_error(underlying_err2, sb)
                case os2.Platform_Error:
                    fmt.sbprint(sb, "os2.Platform_Error -> ", underlying_err2, sep="")
            }
        case Allocator_Error:
            fmt.sbprint(sb, "runtime.Allocator_Error -> ", underlying_err1, sep="")
        case Make_Error:
            fmt.sbprint(sb, "Make_Error -> ", underlying_err1, sep="")
        case CMake_Error:
            fmt.sbprint(sb, "CMake_Error -> ", underlying_err1, sep="")
        case VS_Error:
            fmt.sbprint(sb, "visual_studio.Error -> ")
            switch underlying_err2 in underlying_err1 {
                case Allocator_Error:
                    sb_expand_error(underlying_err2, sb)
                case vs.General_Error:
                    fmt.sbprint(sb, "visual_studio.General_Error -> ", underlying_err2, sep="")
                case os2.Error:
                    sb_expand_error(underlying_err2, sb)
                case json.Error:
                    fmt.sbprint(sb, "json.Error -> ", underlying_err2, sep="")
            }
    }
}

// (`uc`/uncontextual - Nothing is managed by the build context) Takes an error and provides more context on which PACKAGE it came from.
uc_expand_error :: proc(err: Error, allocator := context.allocator) -> string {
    sb := strings.builder_make(allocator)
    sb_expand_error(err, &sb)
    return strings.to_string(sb)
}

expand_error :: proc(ctx: ^Build_Context, err: Error) -> (output: string) {    
    expanded := uc_expand_error(err)
    defer delete(expanded)
    output = strings.clone(expanded, ia.allocator(&ctx.intern_arena))
    return output
}

// Get the full context of the error by expanding (`expand_error`) and using the global context and what its tracked to recieve the likely backtrace for this function.  
// **NOTE**: `allow_newlines` will **NOT** append a new line at the end of the builder.
sb_blame :: proc(err: Error, sb: ^strings.Builder, allow_newlines := true)  {
    if err == nil do return

    if len(global_ctx.error_loc_trace.backtrace_breakpoints) == 0 { // No breakpoints to target
        sb_expand_error(err, sb)
        return
    }

    target_blame := 0 // global_ctx.error_loc_trace.backtrace_breakpoints[len(global_ctx.error_loc_trace.backtrace_breakpoints)-1]
    locations := global_ctx.error_loc_trace.locations[target_blame:]

    if allow_newlines {
        ident_buf: []byte
        {
            ident_buf_size := 4 * len(locations)
            ident_buf = make([]byte, ident_buf_size)
        }
        ident_builder := strings.builder_from_bytes(ident_buf)

        i := 0
        for loc in locations {
            ident := strings.to_string(ident_builder)
            fmt.sbprint(sb, ident, loc, ":", i + 1 < len(locations) ? '\n': ' ', sep="")
            strings.write_string(&ident_builder, "    ")
            i += 1
        }
    } else {
        i := 0
        strings.write_string(sb, "@(")
        for loc in locations {
            fmt.sbprint(sb, loc, i + 1 < len(locations) ? " -> " : "", sep="")
            i += 1
        }
        strings.write_string(sb, ") ")
    }
    sb_expand_error(err, sb)
}

// (`uc`/uncontextual - Nothing is managed by the build context) Get the full context of the error by expanding (`expand_error`) and using the global context and what its tracked to recieve the likely backtrace for this function.  
// **NOTE**: `allow_newlines` will **NOT** append a new line at the end of the builder.
uc_blame :: proc(err: Error, allocator := context.allocator, allow_newlines := true) -> string {
    sb := strings.builder_make(allocator)
    sb_blame(err, &sb, allow_newlines=allow_newlines)
    return strings.to_string(sb)
}

blame :: proc(ctx: ^Build_Context, err: Error, allow_newlines := true) -> (output: string) {
    expanded := uc_blame(err, allow_newlines=allow_newlines)
    defer delete(expanded)
    output = strings.clone(expanded, ia.allocator(&ctx.intern_arena))
    return output
}

Location_Trace :: struct {
    backtrace_breakpoints: [dynamic]int,
    locations: [dynamic]runtime.Source_Code_Location
}
lt_start_trace :: #force_inline proc(b: ^Location_Trace) { 
    append(&b.backtrace_breakpoints, len(b.locations))
}
lt_trace_location :: #force_inline proc(b: ^Location_Trace, caller_location := #caller_location) {
    append(&b.locations, caller_location)
}
lt_backtrace :: #force_inline proc(b: ^Location_Trace) {
    if len(b.backtrace_breakpoints) > 0 {
        resize(&b.locations, pop(&b.backtrace_breakpoints))
    }
}

lt_init_location_trace :: proc(b: ^Location_Trace, allocator: Allocator) -> Allocator_Error {
    context.allocator = allocator
    b.backtrace_breakpoints = make([dynamic]int) or_return
    b.locations = make([dynamic]runtime.Source_Code_Location) or_return
    return nil
}

lt_destroy_location_trace :: proc(b: ^Location_Trace) -> Allocator_Error {
    delete(b.backtrace_breakpoints) or_return
    delete(b.locations) or_return
    return nil
}
