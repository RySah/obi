package obi

import "core:strings"
import "core:fmt"

import subprocess "subprocess"
import ia "intern_arena"

Make_Type :: enum u8 {
    // Linux / WSL (GNU Make), macOS if GNU Make installed
    GNU=1,
    // macOS system make (BSD Make), or any manually installed bmake
    BSD=2,
    // Windows MinGW/MSYS2 (mingw32-make)
    MingW32=4
}

Make_Type_Set :: bit_set[Make_Type]

Make_File_Path :: distinct string
Make_CWD_Path :: distinct string

Make_Path :: union {
    Make_File_Path,
    Make_CWD_Path
}

when ODIN_OS == .Windows {
    ASSUMED_DEFAULT_MAKE_TYPES :: Make_Type_Set{ .MingW32 }
} else when ODIN_OS == .Linux {
    ASSUMED_DEFAULT_MAKE_TYPES :: Make_Type_Set { .GNU }
} else when ODIN_OS == .FreeBSD || ODIN_OS == .OpenBSD || ODIN_OS == .Darwin {
    ASSUMED_DEFAULT_MAKE_TYPES :: Make_Type_Set { .GNU, .BSD }
} else {
    //TODO(rysah): Consider making this panic
    ASSUMED_DEFAULT_MAKE_TYPES :: Make_Type_Set {}
}

Make :: struct {
    // Set of `Make_Type`, indicating what will work building this.  
    // If empty, the program will search for GNU make first before more platform specific versions e.g. mingw32-make.
    compatibility: Make_Type_Set,

    // The file path or required current working directory
    path: Make_Path,

    // Specify the number of jobs that should be ran in parallel.  
    // If `job_count` is `nil`, unlimited jobs are allowed.
    job_count: Maybe(int),

    // Continue building as much as possible even if a target fails.
    continue_after_errors: bool,

    // Ignore all errors in commands.
    ignore_errors: bool,

    // Print what would be executed, but do not run commands.
    print_only_commands: bool,

    // Suppress command echoing.
    silent: bool,

    // Mark targets as updated by setting their timestamps, without running commands.
    mark_targets: bool,

    // Extra flags
    extra_flags: []string
}

Make_Error :: enum int {
    None,
    // Failed to locate any compatible `make` programs
    Incompatible_Or_No_Make_Program=1
}

// Construct an `Sub_Process_Command` that expresses the specified `Make` object.
make_to_subprocess :: proc(ctx: ^Build_Context, m: ^Make, caller_location := #caller_location) -> (cmd_p: ^Sub_Process_Command, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    nonintern_make_path: string = ---
    {
        found := false
        compatible := card(m.compatibility) == 0 ? ASSUMED_DEFAULT_MAKE_TYPES : m.compatibility
        if card(compatible) > 0 {
            if .GNU in compatible {
                nonintern_make_path, found = ta_subprocess_which("make", search_local=true) or_return
            }
            if .BSD in compatible && !found {
                nonintern_make_path, found = ta_subprocess_which("bmake", search_local=true) or_return
            }
            if .MingW32 in compatible && !found {
                nonintern_make_path, found = ta_subprocess_which("mingw32-make", search_local=true) or_return
                if !found {
                    nonintern_make_path, found = ta_subprocess_which("make", search_local=true) or_return
                }
            }
        }

        if !found do return nil, Make_Error.Incompatible_Or_No_Make_Program
    }
    defer delete(nonintern_make_path)
    make_path := ia.intern_string(&ctx.intern_arena, nonintern_make_path) or_return

    command_size := 1 // make
    command_size += 2 // -C <dir> // -f <file>

    if _, ok := m.job_count.?; ok {
        command_size += 1 // -j<N>
    }

    command_size += 1 if m.continue_after_errors else 0
    command_size += 1 if m.ignore_errors else 0
    command_size += 1 if m.print_only_commands else 0
    command_size += 1 if m.silent else 0
    command_size += 1 if m.mark_targets else 0
    command_size += len(m.extra_flags)
    cmd: Sub_Process_Command = {
        working_dir = ia.intern_string(&ctx.intern_arena, ctx.working_dir) or_return,
        command = make([]string, command_size, ia.allocator(&ctx.intern_arena)) or_return,
        env=nil,
        stdin=nil
    }
    cmd.command[0] = make_path
    i := 1
    switch v in m.path {
        case Make_File_Path:
            cmd.command[i] = "-f"
            i += 1
            cmd.command[i] = ia.intern_string(&ctx.intern_arena, transmute(string)v) or_return
            i += 1
        case Make_CWD_Path:
            cmd.command[i] = "-C"
            i += 1
            cmd.command[i] = ia.intern_string(&ctx.intern_arena, transmute(string)v) or_return
            i += 1
    }
    if count, ok := m.job_count.?; ok {
        cmd.command[i] = ia.iprint(&ctx.intern_arena, "-j", count, sep="") or_return
        i += 1
    }
    if m.continue_after_errors {
        cmd.command[i] = "-k"
        i += 1
    }
    if m.ignore_errors {
        cmd.command[i] = "-i"
        i += 1
    }
    if m.print_only_commands {
        cmd.command[i] = "-n"
        i += 1
    }
    if m.silent {
        cmd.command[i] = "-s"
        i += 1
    }
    if m.mark_targets {
        cmd.command[i] = "-t"
        i += 1
    }
    for &fl, j in m.extra_flags do cmd.command[i+j] = ia.intern_by_value(&ctx.intern_arena, fl) or_return
    cmd_p = ia.clone_value(&ctx.intern_arena, cmd) or_return
    return cmd_p, nil
}

make_to_step :: proc(ctx: ^Build_Context, m: ^Make, caller_location := #caller_location) -> (step: ^Step, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    cmd := make_to_subprocess(ctx, m) or_return
    return subprocess_to_step(ctx, cmd)
}