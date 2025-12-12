package obi

import "core:strings"
import "core:fmt"

import subprocess "subprocess"

Make_Type :: enum int {
    // Linux / WSL (GNU Make), macOS if GNU Make installed
    GNU,
    // macOS system make (BSD Make), or any manually installed bmake
    BSD,
    // Windows MinGW/MSYS2 (mingw32-make)
    MingW
}

Make_Type_Set :: bit_set[Make_Type]

Make_File_Path :: distinct string
Make_CWD_Path :: distinct string

Make_Path :: union {
    Make_File_Path,
    Make_CWD_Path
}

when ODIN_OS == .Windows {
    ASSUMED_DEFAULT_MAKE_TYPES :: Make_Type_Set { .MingW }
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
    Failed_To_Find_Compatible
}

// Construct an `Sub_Process_Command` that expresses the specified `Make` object.
make_to_subprocess :: proc(ctx: ^Build_Context, m: ^Make) -> (cmd_p: ^Sub_Process_Command, err: Error) {
    make_name: string = ---
    {
        found := false
        compatible := card(m.compatibility) == 0 ? ASSUMED_DEFAULT_MAKE_TYPES : m.compatibility
        if card(compatible) > 0 {
            if .GNU in compatible {
                found = subprocess.which_b("make", ctx.allocator, search_local=true) or_return
                make_name = "make"
            }
            if .BSD in compatible && !found {
                found = subprocess.which_b("bmake", ctx.allocator, search_local=true) or_return
                make_name = "bmake"
            }
            if .MingW in compatible && !found {
                found = subprocess.which_b("ming32w-make", ctx.allocator) or_return
                if found do make_name = "ming32w-make"
                if !found {
                    found = subprocess.which_b("make", ctx.allocator) or_return
                    make_name = "make"
                }
            }
        }

        if !found do return nil, Make_Error.Failed_To_Find_Compatible
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
        working_dir = "",
        command = make([]string, command_size, ctx.allocator) or_return,
        env=nil,
        stdin=nil
    }
    cmd.command[0] = _own(ctx, make_name, clone=true) or_return // TODO(rysah): This uneccessarily creates duplicates in memory, perhaps create storage for string literals
    i := 1
    switch v in m.path {
        case Make_File_Path:
            cmd.command[i] = _own(ctx, "-f", clone=true) or_return
            i += 1
            path := strings.concatenate({ "\"", transmute(string)v, "\"" }, ctx.allocator) or_return
            cmd.command[i] = _own(ctx, path, clone=false) or_return
            i += 1
        case Make_CWD_Path:
            path := strings.concatenate({ "\"", transmute(string)v, "\"" }, ctx.allocator) or_return
            cmd.command[i] = _own(ctx, path, clone=false) or_return
            i += 1
    }
    if count, ok := m.job_count.?; ok {
        cmd.command[i] = _own(ctx, fmt.aprint("-j", count, sep="", allocator=ctx.allocator), clone=false) or_return
        i += 1
    }
    if m.continue_after_errors {
        cmd.command[i] = _own(ctx, "-k", clone=true) or_return
        i += 1
    }
    if m.ignore_errors {
        cmd.command[i] = _own(ctx, "-i", clone=true) or_return
        i += 1
    }
    if m.print_only_commands {
        cmd.command[i] = _own(ctx, "-n", clone=true) or_return
        i += 1
    }
    if m.silent {
        cmd.command[i] = _own(ctx, "-s", clone=true) or_return
        i += 1
    }
    if m.mark_targets {
        cmd.command[i] = _own(ctx, "-t", clone=true) or_return
        i += 1
    }

    extra_flags := _own(ctx, m.extra_flags, clone_slice=true, clone_strings=true) or_return
    for &fl, j in extra_flags do cmd.command[i+j] = fl
    cmd_p = _own(ctx, &cmd, clone_slice=false, clone_strings=false) or_return
    return cmd_p, nil
}