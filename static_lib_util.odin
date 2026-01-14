package obi

import "core:strings"
import "core:path/filepath"
import ia "intern_arena"
import promise "promise"

STATIC_LIB_EXT :: ".lib" when ODIN_OS == .Windows else ".a"

Static_Lib_Path :: distinct string

Static_Lib_Source :: union {
    C_Path,
    Object_Path
}

Static_Lib_Spec :: struct {
    sources: []Static_Lib_Source,
    output: Static_Lib_Path,
    optimization: Optimization_Level
}

Static_Lib_Error :: enum int {
    None,
    // Failed to locate any compatible linker programs
    Incompatible_Or_No_Linker_Program=1
}

static_lib_spec_to_step :: proc(ctx: ^Build_Context, sl: ^Static_Lib_Spec, caller_location := #caller_location) -> (step: ^Step, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    c_paths := make([dynamic]C_Path) or_return
    defer delete(c_paths)
    obj_paths := make([dynamic]Object_Path) or_return
    defer delete(obj_paths)

    for &source in sl.sources {
        switch &internal in source {
            case C_Path:
                append(&c_paths, internal) or_return
            case Object_Path:
                append(&obj_paths, internal) or_return
        }
    }

    c_paths_step: ^Step = nil
    if len(c_paths) > 0 {
        spec := C_Object_Spec {
            input_paths=c_paths[:],
            optimization=sl.optimization
        }
        c_paths_step = to_step(ctx, &spec) or_return
        append(&obj_paths, ..get_expected_output_object_paths(ctx, &spec) or_return) or_return
    }

    when ODIN_OS == .Windows {
        if lib_path, lib_path_exists := promise.get_ref(&ctx.windows.visual_studio_lib_path).?; lib_path_exists {
            output_path := transmute(string)sl.output
            if filepath.ext(output_path) != STATIC_LIB_EXT {
                output_path = strings.concatenate({ output_path, STATIC_LIB_EXT }, allocator=ia.allocator(&ctx.intern_arena)) or_return
            }

            command_size := 1 // lib
            command_size += len(obj_paths)
            command_size += 1 // /OUT:

            cmd := Sub_Process_Command {
                working_dir = ia.intern_string(&ctx.intern_arena, ctx.working_dir) or_return,
                command = make([]string, command_size, ia.allocator(&ctx.intern_arena)) or_return,
                env=nil,
                stdin=nil
            }

            cmd.command[0] = lib_path
            i := 1
            for &path, j in obj_paths do cmd.command[i+j] = ia.intern_by_value(&ctx.intern_arena, transmute(string)path) or_return
            i += len(obj_paths)
            cmd.command[i] = strings.concatenate({ "/OUT:\"", output_path, "\"" }, allocator=ia.allocator(&ctx.intern_arena)) or_return
            step = to_step(ctx, &cmd) or_return
            if c_paths_step != nil do step = merge_steps(ctx, c_paths_step, step) or_return
            return step, nil
        } else {
            if llvm_lib_path, llvm_lib_path_found := ta_subprocess_which("llvm-lib") or_return; llvm_lib_path_found {
                defer delete(llvm_lib_path)

                output_path := transmute(string)sl.output
                if filepath.ext(output_path) != STATIC_LIB_EXT {
                    output_path = strings.concatenate({ output_path, STATIC_LIB_EXT }, allocator=ia.allocator(&ctx.intern_arena)) or_return
                }

                command_size := 1 // llvm-lib
                command_size += len(obj_paths)
                command_size += 1 // /OUT:

                cmd := Sub_Process_Command {
                    working_dir = ia.intern_string(&ctx.intern_arena, ctx.working_dir) or_return,
                    command = make([]string, command_size, ia.allocator(&ctx.intern_arena)) or_return,
                    env=nil,
                    stdin=nil
                }

                cmd.command[0] = llvm_lib_path
                i := 1
                for &path, j in obj_paths do cmd.command[i+j] = ia.intern_by_value(&ctx.intern_arena, transmute(string)path) or_return
                i += len(obj_paths)
                cmd.command[i] = strings.concatenate({ "/OUT:\"", output_path, "\"" }, allocator=ia.allocator(&ctx.intern_arena)) or_return
                
                step = to_step(ctx, &cmd) or_return
                if c_paths_step != nil do step = merge_steps(ctx, c_paths_step, step) or_return
                return step, nil
            }
        }
    } else {
        if ar_path, ar_path_found := ta_subprocess_which("ar") or_return; ar_path_found {
            defer delete(ar_path)

            output_path := transmute(string)sl.output
            if filepath.ext(output_path) != STATIC_LIB_EXT {
                output_path = strings.concatenate({ output_path, STATIC_LIB_EXT }, allocator=ia.allocator(&ctx.intern_arena)) or_return
            }

            command_size := 1 // ar
            command_size += 1 // rcs
            command_size += 1 // *.a
            command_size += len(obj_paths)

            cmd := Sub_Process_Command {
                working_dir = ia.intern_string(&ctx.intern_arena, ctx.working_dir) or_return,
                command = make([]string, command_size, ia.allocator(&ctx.intern_arena)) or_return,
                env=nil,
                stdin=nil
            }

            cmd.command[0] = ar_path
            cmd.command[1] = "rcs"
            cmd.command[2] = output_path
            i := 3
            for &path, j in obj_paths do cmd.command[i+j] = ia.intern_by_value(&ctx.intern_arena, transmute(string)path) or_return

            step = to_step(ctx, &cmd) or_return
            if c_paths_step != nil do step = merge_steps(ctx, c_paths_step, step) or_return
            return step, nil
        }
    }

    return step, Static_Lib_Error.Incompatible_Or_No_Linker_Program
}