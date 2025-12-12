package obi

import "core:strings"

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
odin_build_to_subprocess :: proc(ctx: ^Build_Context, b: ^Odin_Build) -> (cmd_p: ^Sub_Process_Command, err: Allocator_Error) {
    command_size := 2 // odin build
    switch _ in b.path {
        case Odin_Build_File_Path: command_size += 2 // <file> -file
        case Odin_Build_Dir_Path: command_size += 1 // <dir>
    }
    command_size += 1 // -build-mode:<mode>
    command_size += len(b.extra_flags)
    cmd: Sub_Process_Command = {
        working_dir = "",
        command = make([]string, command_size, ctx.allocator) or_return,
        env=nil,
        stdin=nil
    }
    cmd.command[0] = _own(ctx, "odin", clone=true) or_return // TODO(rysah): This uneccessarily creates duplicates in memory, perhaps create storage for string literals
    cmd.command[1] = _own(ctx, "build", clone=true) or_return
    i := 2
    switch v in b.path {
        case Odin_Build_File_Path:
            path := strings.concatenate({ "\"", transmute(string)v, "\"" }, ctx.allocator) or_return
            cmd.command[i] = _own(ctx, path, clone=false) or_return
            i += 1
            cmd.command[i] = _own(ctx, "-file", clone=true) or_return
            i += 1
        case Odin_Build_Dir_Path:
            path := strings.concatenate({ "\"", transmute(string)v, "\"" }, ctx.allocator) or_return
            cmd.command[i] = _own(ctx, path, clone=false) or_return
            i += 1
    }
    switch b.mode {
        case .Executable:
            cmd.command[i] = _own(ctx, "-build-mode:exe", clone=true) or_return
            i += 1
        case .Dynamic:
            cmd.command[i] = _own(ctx, "-build-mode:dynamic", clone=true) or_return
            i += 1
        case .Static:
            cmd.command[i] = _own(ctx, "-build-mode:static", clone=true) or_return
            i += 1
        case .Object:
            cmd.command[i] = _own(ctx, "-build-mode:object", clone=true) or_return
            i += 1
        case .Assembly:
            cmd.command[i] = _own(ctx, "-build-mode:assembly", clone=true) or_return
            i += 1
        case .LLVM_IR:
            cmd.command[i] = _own(ctx, "-build-mode:llvm-ir", clone=true) or_return
            i += 1
    }
    extra_flags := _own(ctx, b.extra_flags, clone_slice=true, clone_strings=true) or_return
    for &fl, j in extra_flags do cmd.command[i+j] = fl
    cmd_p = _own(ctx, &cmd, clone_slice=false, clone_strings=false) or_return
    return cmd_p, nil
}

odin_build_to_step :: proc(ctx: ^Build_Context, b: ^Odin_Build) -> (step: Step, err: Allocator_Error) {
    cmd := odin_build_to_subprocess(ctx, b) or_return
    return subprocess_to_step(ctx, cmd)
}

// Construct an `Sub_Process_Command` that expresses the specified `Odin_Run` object.
odin_run_to_subprocess :: proc(ctx: ^Build_Context, r: ^Odin_Run) -> (cmd_p: ^Sub_Process_Command, err: Allocator_Error) {
    command_size := 2 // odin build
    switch _ in r.path {
        case Odin_Build_File_Path: command_size += 2 // <file> -file
        case Odin_Build_Dir_Path: command_size += 1 // <dir>
    }
    command_size += len(r.extra_flags)
    cmd: Sub_Process_Command = {
        working_dir = "",
        command = make([]string, command_size, ctx.allocator) or_return,
        env=nil,
        stdin=nil
    }
    cmd.command[0] = _own(ctx, "odin", clone=true) or_return // TODO(rysah): This uneccessarily creates duplicates in memory, perhaps create storage for string literals
    cmd.command[1] = _own(ctx, "run", clone=true) or_return
    i := 2
    switch v in r.path {
        case Odin_Build_File_Path:
            path := strings.concatenate({ "\"", transmute(string)v, "\"" }, ctx.allocator) or_return
            cmd.command[i] = _own(ctx, path, clone=false) or_return
            i += 1
            cmd.command[i] = _own(ctx, "-file", clone=true) or_return
            i += 1
        case Odin_Build_Dir_Path:
            path := strings.concatenate({ "\"", transmute(string)v, "\"" }, ctx.allocator) or_return
            cmd.command[i] = _own(ctx, path, clone=false) or_return
            i += 1
    }
    extra_flags := _own(ctx, r.extra_flags, clone_slice=true, clone_strings=true) or_return
    for &fl, j in extra_flags do cmd.command[i+j] = fl
    cmd_p = _own(ctx, &cmd, clone_slice=false, clone_strings=false) or_return
    return cmd_p, nil
}

odin_run_to_step :: proc(ctx: ^Build_Context, b: ^Odin_Run) -> (step: Step, err: Allocator_Error) {
    cmd := odin_run_to_subprocess(ctx, b) or_return
    return subprocess_to_step(ctx, cmd)
}
