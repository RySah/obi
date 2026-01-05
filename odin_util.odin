package obi

import "core:strings"

import gc "garbage_collector"

//TODO(rysah): Use `ta_subprocess_which` or `subprocess.which` to find the odin executable.

Odin_Build_Mode_Type :: enum int {
    Executable,
    Dynamic,
    Static,
    Object,
    Assembly,
    LLVM_IR,
}

Odin_Build_File_Path :: distinct string
Odin_Build_Dir_Path :: distinct string

Odin_Build_Path :: union {
    Odin_Build_File_Path,
    Odin_Build_Dir_Path
}

Odin_Build :: struct {
    // Sets the build mode
    mode: Odin_Build_Mode_Type,

    // File or directory to build
    path: Odin_Build_Path,

    // Extra build flags
    extra_flags: []string
}

Odin_Run :: struct {
    // File or directory to build
    path: Odin_Build_Path,

    // Extra build flags
    extra_flags: []string
}

// Construct an `Sub_Process_Command` that expresses the specified `Odin_Build` object.
odin_build_to_subprocess :: proc(ctx: ^Build_Context, b: ^Odin_Build, caller_location := #caller_location) -> (cmd_p: ^Sub_Process_Command, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    command_size := 2 // odin build
    switch _ in b.path {
        case Odin_Build_File_Path: command_size += 2 // <file> -file
        case Odin_Build_Dir_Path: command_size += 1 // <dir>
    }
    command_size += 1 // -build-mode:<mode>
    command_size += len(b.extra_flags)
    cmd: Sub_Process_Command = {
        working_dir = _manage_mem(ctx, ctx.working_dir) or_return,
        command = make([]string, command_size, gc.allocator(&ctx.garbage_collector)) or_return,
        env=nil,
        stdin=nil
    }
    cmd.command[0] = _manage_mem(ctx, "odin") or_return // TODO(rysah): This uneccessarily creates duplicates in memory, perhaps create storage for string literals
    cmd.command[1] = _manage_mem(ctx, "build") or_return
    i := 2
    switch v in b.path {
        case Odin_Build_File_Path:
            cmd.command[i] = _manage_mem(ctx, transmute(string)v) or_return
            i += 1
            cmd.command[i] = _manage_mem(ctx, "-file") or_return
            i += 1
        case Odin_Build_Dir_Path:
            cmd.command[i] = _manage_mem(ctx, transmute(string)v) or_return
            i += 1
    }
    switch b.mode {
        case .Executable:
            cmd.command[i] = _manage_mem(ctx, "-build-mode:exe") or_return
            i += 1
        case .Dynamic:
            cmd.command[i] = _manage_mem(ctx, "-build-mode:dynamic") or_return
            i += 1
        case .Static:
            cmd.command[i] = _manage_mem(ctx, "-build-mode:static") or_return
            i += 1
        case .Object:
            cmd.command[i] = _manage_mem(ctx, "-build-mode:object") or_return
            i += 1
        case .Assembly:
            cmd.command[i] = _manage_mem(ctx, "-build-mode:assembly") or_return
            i += 1
        case .LLVM_IR:
            cmd.command[i] = _manage_mem(ctx, "-build-mode:llvm-ir") or_return
            i += 1
    }
    extra_flags := _manage_mem(ctx, b.extra_flags, clone_strings=true) or_return
    for &fl, j in extra_flags do cmd.command[i+j] = fl
    cmd_p = _manage_mem(ctx, &cmd, clone_members=false) or_return
    return cmd_p, nil
}

odin_build_to_step :: proc(ctx: ^Build_Context, b: ^Odin_Build, caller_location := #caller_location) -> (step: ^Step, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    cmd := odin_build_to_subprocess(ctx, b) or_return
    return subprocess_to_step(ctx, cmd)
}

// Construct an `Sub_Process_Command` that expresses the specified `Odin_Run` object.
odin_run_to_subprocess :: proc(ctx: ^Build_Context, r: ^Odin_Run, caller_location := #caller_location) -> (cmd_p: ^Sub_Process_Command, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    command_size := 2 // odin build
    switch _ in r.path {
        case Odin_Build_File_Path: command_size += 2 // <file> -file
        case Odin_Build_Dir_Path: command_size += 1 // <dir>
    }
    command_size += len(r.extra_flags)
    cmd: Sub_Process_Command = {
        working_dir = _manage_mem(ctx, ctx.working_dir) or_return,
        command = make([]string, command_size, gc.allocator(&ctx.garbage_collector)) or_return,
        env=nil,
        stdin=nil
    }
    cmd.command[0] = _manage_mem(ctx, "odin") or_return // TODO(rysah): This uneccessarily creates duplicates in memory, perhaps create storage for string literals
    cmd.command[1] = _manage_mem(ctx, "build") or_return
    i := 2
    switch v in r.path {
        case Odin_Build_File_Path:
            cmd.command[i] = _manage_mem(ctx, transmute(string)v) or_return
            i += 1
            cmd.command[i] = _manage_mem(ctx, "-file") or_return
            i += 1
        case Odin_Build_Dir_Path:
            cmd.command[i] = _manage_mem(ctx, transmute(string)v) or_return
            i += 1
    }
    extra_flags := _manage_mem(ctx, r.extra_flags, clone_strings=true) or_return
    for &fl, j in extra_flags do cmd.command[i+j] = fl
    cmd_p = _manage_mem(ctx, &cmd, clone_members=false) or_return
    return cmd_p, nil
}

odin_run_to_step :: proc(ctx: ^Build_Context, b: ^Odin_Run, caller_location := #caller_location) -> (step: ^Step, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    cmd := odin_run_to_subprocess(ctx, b) or_return
    return subprocess_to_step(ctx, cmd)
}

odin_default_build_step :: proc(
    ctx: ^Build_Context, 
    extra_flags: ..string, 
    planned := false, 
    caller_location := #caller_location
) -> (step: ^Step, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    cmd := Odin_Build{
        mode=.Executable,
        path=Odin_Build_Dir_Path("."),
        extra_flags=extra_flags
    }
    step = to_step(ctx, &cmd) or_return

    if planned {
        step = plan_step(
            ctx,
            files_fingerprint(ctx, ".", "third_party", 
                dir_glob_patterns={ include={ "*" }, exclude={ctx.cache_file_system.path} },
                file_glob_patterns={ include={ "*.odin", "*.sjson" }, exclude={} }
            ) or_return,
            step
        ) or_return
    }

    return step, nil
}

odin_default_run_step :: proc(
    ctx: ^Build_Context, 
    extra_flags: ..string, 
    planned := false, 
    caller_location := #caller_location
) -> (step: ^Step, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    cmd := Odin_Run{
        path=Odin_Build_Dir_Path("."),
        extra_flags=extra_flags
    }
    step = to_step(ctx, &cmd) or_return

    if planned {
        step = plan_step(
            ctx,
            files_fingerprint(ctx, ".", "third_party", 
                dir_glob_patterns={ include={ "*" }, exclude={ctx.cache_file_system.path} },
                file_glob_patterns={ include={ "*.odin", "*.sjson" }, exclude={} }
            ) or_return,
            step
        ) or_return
    }

    return step, nil
}