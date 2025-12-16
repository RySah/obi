package obi

import "core:strings"
import "core:fmt"

import subprocess "subprocess"
import gc "garbage_collector"

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
make_to_subprocess :: proc(ctx: ^Build_Context, m: ^Make) -> (cmd_p: ^Sub_Process_Command, err: Error) {
    make_path: string = ---
    {
        found := false
        compatible := card(m.compatibility) == 0 ? ASSUMED_DEFAULT_MAKE_TYPES : m.compatibility
        if card(compatible) > 0 {
            if .GNU in compatible {
                make_path, found = subprocess.which("make", gc.allocator(&ctx.garbage_collector), search_local=true) or_return
            }
            if .BSD in compatible && !found {
                make_path, found = subprocess.which("bmake", gc.allocator(&ctx.garbage_collector), search_local=true) or_return
            }
            if .MingW32 in compatible && !found {
                make_path, found = subprocess.which("mingw32-make", gc.allocator(&ctx.garbage_collector), search_local=true) or_return
                if !found {
                    make_path, found = subprocess.which("make", gc.allocator(&ctx.garbage_collector), search_local=true) or_return
                }
            }
        }

        if !found do return nil, Make_Error.Incompatible_Or_No_Make_Program
    }

    for len(make_path) > 0 {
        last := make_path[len(make_path)-1]
        if last == '\n' || last == '\r' {
            make_path = make_path[0:len(make_path)-1]
        } else {
            break
        }
    }

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
        working_dir = _manage_mem(ctx, ctx.working_dir) or_return,
        command = make([]string, command_size, gc.allocator(&ctx.garbage_collector)) or_return,
        env=nil,
        stdin=nil
    }
    cmd.command[0] = make_path
    i := 1
    switch v in m.path {
        case Make_File_Path:
            cmd.command[i] = _manage_mem(ctx, "-f") or_return
            i += 1
            cmd.command[i] = _manage_mem(ctx, transmute(string)v) or_return
            i += 1
        case Make_CWD_Path:
            cmd.command[i] = _manage_mem(ctx, "-C") or_return
            i += 1
            cmd.command[i] = _manage_mem(ctx, transmute(string)v) or_return
            i += 1
    }
    if count, ok := m.job_count.?; ok {
        cmd.command[i] = fmt.aprint("-j", count, sep="", allocator=gc.allocator(&ctx.garbage_collector))
        i += 1
    }
    if m.continue_after_errors {
        cmd.command[i] = _manage_mem(ctx, "-k") or_return
        i += 1
    }
    if m.ignore_errors {
        cmd.command[i] = _manage_mem(ctx, "-i") or_return
        i += 1
    }
    if m.print_only_commands {
        cmd.command[i] = _manage_mem(ctx, "-n") or_return
        i += 1
    }
    if m.silent {
        cmd.command[i] = _manage_mem(ctx, "-s") or_return
        i += 1
    }
    if m.mark_targets {
        cmd.command[i] = _manage_mem(ctx, "-t") or_return
        i += 1
    }

    extra_flags := _manage_mem(ctx, m.extra_flags, clone_strings=true) or_return
    for &fl, j in extra_flags do cmd.command[i+j] = fl
    cmd_p = _manage_mem(ctx, &cmd, clone_members=false) or_return
    return cmd_p, nil
}

make_to_step :: proc(ctx: ^Build_Context, m: ^Make) -> (step: Step, err: Error) {
    cmd := make_to_subprocess(ctx, m) or_return
    return subprocess_to_step(ctx, cmd)
}