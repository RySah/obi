
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ryan Mensah

/*
Package obi — odin_util.odin

This file defines build utilites for the odin programming language.
*/

package obi

import "core:strings"

import ia "intern_arena"

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

/*
**Description**:
- Converts `Odin_Build` to a subprocess command (`Sub_Process_Command`).

**Params**:
- `ctx: ^Build_Context` — Memory location of build context.
- `b: ^Odin_Build` — Memory location of `Odin_Build`.

**Returns**:
- `cmd_p: ^Sub_Process_Command` - Resulting subprocess command.
- `err: Error` - Non-nil if memory allocation failed.
*/
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
        working_dir = ia.intern_string(&ctx.intern_arena, ctx.working_dir) or_return,
        command = make([]string, command_size, ia.allocator(&ctx.intern_arena)) or_return,
        env=nil,
        stdin=nil
    }
    cmd.command[0] = "odin"
    cmd.command[1] = "build"
    i := 2
    switch v in b.path {
        case Odin_Build_File_Path:
            cmd.command[i] = ia.intern_string(&ctx.intern_arena, transmute(string)v) or_return
            i += 1
            cmd.command[i] = "-file"
            i += 1
        case Odin_Build_Dir_Path:
            cmd.command[i] = ia.intern_string(&ctx.intern_arena, transmute(string)v) or_return
            i += 1
    }
    switch b.mode {
        case .Executable:
            cmd.command[i] = "-build-mode:exe"
            i += 1
        case .Dynamic:
            cmd.command[i] = "-build-mode:dynamic"
            i += 1
        case .Static:
            cmd.command[i] = "-build-mode:static"
            i += 1
        case .Object:
            cmd.command[i] = "-build-mode:object"
            i += 1
        case .Assembly:
            cmd.command[i] = "-build-mode:assembly"
            i += 1
        case .LLVM_IR:
            cmd.command[i] = "-build-mode:llvm-ir"
            i += 1
    }
    for &fl, j in b.extra_flags do cmd.command[i+j] = ia.intern_string(&ctx.intern_arena, fl) or_return
    cmd_p = ia.clone_value(&ctx.intern_arena, cmd) or_return
    return cmd_p, nil
}

/*
**Description**:
- Converts `Odin_Build` to a build step (`Step`).

**Params**:
- `ctx: ^Build_Context` — Memory location of build context.
- `b: ^Odin_Build` — Memory location of `Odin_Build`.

**Returns**:
- `step: ^Step` - Resulting build step.
- `err: Error` - Non-nil if memory allocation failed.
*/
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
        working_dir = ia.intern_string(&ctx.intern_arena, ctx.working_dir) or_return,
        command = make([]string, command_size, ia.allocator(&ctx.intern_arena)) or_return,
        env=nil,
        stdin=nil
    }
    cmd.command[0] = "odin"
    cmd.command[1] = "build"
    i := 2
    switch v in r.path {
        case Odin_Build_File_Path:
            cmd.command[i] = ia.intern_string(&ctx.intern_arena, transmute(string)v) or_return
            i += 1
            cmd.command[i] = "-file"
            i += 1
        case Odin_Build_Dir_Path:
            cmd.command[i] = ia.intern_string(&ctx.intern_arena, transmute(string)v) or_return
            i += 1
    }
    for &fl, j in r.extra_flags do cmd.command[i+j] = ia.intern_string(&ctx.intern_arena, fl) or_return
    cmd_p = ia.clone_ptr(&ctx.intern_arena, &cmd) or_return
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