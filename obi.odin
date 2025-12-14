package obi

import "core:fmt"
import "core:os/os2"
import "core:os"
import "core:path/filepath"
import "core:time"
import "core:terminal"
import "core:terminal/ansi"
import "core:strings"
import "core:slice"
import "core:mem/virtual"
import hash_algo "core:hash"
import "core:math/bits"
import "core:log"
import "core:strconv"

import "base:runtime"

import "core:mem"
Allocator :: mem.Allocator
Allocator_Error :: mem.Allocator_Error

import ci "cimport"
C_Import_Error :: ci.Error
C_Import_Info :: ci.Import_Info

import cachefs "cache_fs"
Cache_File_System_Error :: cachefs.Error
Cache_File_System :: cachefs.File_System

import subprocess "subprocess"
Sub_Process_File :: subprocess.File
Sub_Process_Error :: subprocess.Error
Sub_Process_Command :: subprocess.Command

import gc "garbage_collector"
GC_Error :: gc.Error
Garbage_Collector :: gc.Garbage_Collector

Error :: union #shared_nil {
    C_Import_Error,
    Cache_File_System_Error,
    Sub_Process_Error,
    Allocator_Error,
    Make_Error
}

DEFAULT_CACHE_FILE_SYSTEM_PATH :: ".obi-cache"
DEFAULT_C_IMPORT_OUTPUT_PATH :: "c_api"

// Same as Odin_OS_Type
OS_Type :: enum int {
    Unknown,
    Windows,
    Darwin,
    Linux,
    Essence,
    FreeBSD,
    OpenBSD,
    NetBSD,
    Haiku,
    WASI,
    JS,
    Orca,
    Freestanding
}

// Same as `Odin_Arch_Type`
Arch_Type :: enum int {
    Unknown,
    amd64,
    i386,
    arm32,
    arm64,
    wasm32,
    wasm64p32,
    riscv64,
}

OS_Specific_Sub_Process :: [OS_Type]Maybe(Sub_Process_Command)
Arch_Specific_Sub_Process :: [Arch_Type]Maybe(Sub_Process_Command)

Step :: struct {
    name: string,
    procedure: #type proc(ctx: ^Build_Context, client_data: rawptr) -> (success: bool, err: Error),
    client_data: rawptr,
    success_required: bool
}

empty_step_procedure :: proc(^Build_Context,rawptr) -> (bool, Error) { return true, nil }

Empty_Step :: Step{
    name="empty",
    procedure=empty_step_procedure,
    client_data=nil,
    success_required=false
}

OS_Specific_Step :: [OS_Type]Maybe(Step)
Arch_Specific_Step :: [Arch_Type]Maybe(Step)

Hasher :: struct {
    procedure: #type proc(client_data: rawptr) -> u64,
    client_data: rawptr
}

// This is left intentionally non-deterministic.
empty_hasher_procedure :: proc(rawptr) -> u64 {
    @(static) unique_v: u64 = 0
    if unique_v == bits.U64_MAX do unique_v = 0
    unique_v += 1
    return unique_v
}

Empty_Hasher :: Hasher{
    procedure=empty_hasher_procedure,
    client_data=nil
}

run_hasher :: #force_inline proc(hasher: Hasher) -> u64 { return hasher.procedure(hasher.client_data) }

resolve_os_specific_subprocess :: #force_inline proc(s: ^OS_Specific_Sub_Process) -> ^Maybe(Sub_Process_Command) {
    return &s[transmute(OS_Type)ODIN_OS]
}
resolve_arch_specific_subprocess :: #force_inline proc(s: ^Arch_Specific_Sub_Process) -> ^Maybe(Sub_Process_Command) {
    return &s[transmute(Arch_Type)ODIN_ARCH]
}

resolve_os_specific_step :: #force_inline proc(s: ^OS_Specific_Step) -> ^Maybe(Step) {
    return &s[transmute(OS_Type)ODIN_OS]
}
resolve_arch_specific_step :: #force_inline proc(s: ^Arch_Specific_Step) -> ^Maybe(Step) {
    return &s[transmute(Arch_Type)ODIN_ARCH]
}

resolve_os_specific :: proc{resolve_os_specific_step,resolve_os_specific_subprocess}
resolve_arch_specific :: proc{resolve_arch_specific_step,resolve_arch_specific_subprocess}

Build_Context :: struct {
    // Allocator
    allocator: Allocator,
    // Logger
    logger: log.Logger,
    // Garbage collector for owned resources
    garbage_collector: Garbage_Collector,
    // The cache file system.
    cache_file_system: Cache_File_System,
    // Default parent directory for `C_Import_Info` objects.  
    // **NOTE:** You are not forced to use this for `C_Import_Info` objects, simply change `C_Import_Info.output_folder` to customize it for that specific object.
    c_import_output_path: string,
    // Sequence of steps to run, to complete the build.
    steps: [dynamic]Step,
    // Output handle for all subprocess commands.    
    // **NOTE:** Set to the system stdout (`subprocess.stdout`) by default.
    stdout: ^Sub_Process_File, 
    // Error output handle for all subprocess commands.    
    // **NOTE:** Set to the system stderr (`subprocess.stderr`) by default.
    stderr: ^Sub_Process_File,

    working_dir: string,

    verbose_debug: bool,

    // This is the hasher that provides a unique value to planned steps, based off the state of its environment.  
    // The **default** hasher will hash all items in the `cache_file_system`, this ensures planned steps will only be
    // ran, if not only provided the fingerprint is the same, but the state of the cache is also the same. Change this value
    // if other states should be taken into account. The **default** is stored at `Default_State_Hasher`.
    state_fingerprint: Hasher
}

default_state_hasher_procedure :: proc(client_data: rawptr) -> u64 {
    data := transmute(^State_Hasher_Client_Data)client_data
    ctx := data.ctx
    maybe_exclude := data.exclude

    walker := os2.walker_create(ctx.cache_file_system.path)
    defer os2.walker_destroy(&walker)

    result: u64 = 0

    for info in os2.walker_walk(&walker) {
        _ = os2.walker_error(&walker) or_continue

        if info.type == .Regular {
            rel_path := info.fullpath

            if exclude, ok := maybe_exclude.?; ok {
                if strings.compare(rel_path, exclude) == 0 do continue
            }

            result |= hash_algo.murmur64a(transmute([]u8)rel_path)
            content, content_err := os2.read_entire_file(rel_path, context.allocator)
            defer if content_err == nil do delete(content)
            result |= content_err == nil ? hash_algo.murmur64a(transmute([]u8)content) : 0
        }
    }

    return result
}

State_Hasher_Client_Data :: struct {
    ctx: ^Build_Context,
    // Set this to the cache file you will write to, to ensure procedure doesn't become self-invalidating, you can tell if its self-invalidating if the program keeps on rebuilding
    // regardless of no changes.
    exclude: Maybe(string)
}

// Expects `client_data` to be `^Default_State_Hasher_Client_Data`.  
// e.g.
// ```  
// client_data := Default_State_Hasher_Client_Data{ ... }  
// ctx.state_fingerprint.client_data = &client_data  
// ```
// 
Default_State_Hasher :: Hasher {
    procedure=default_state_hasher_procedure,
    client_data=nil
}

@(private)
_C_Import_Info_Client_Data :: struct {
    info: ^C_Import_Info,
    ctx: ^Build_Context
}

@(private)
_manage_slice :: proc(ctx: ^Build_Context, data: $T/[]$E) -> (clone: T, err: Allocator_Error) #optional_allocator_error {
    return slice.clone(data, gc.allocator(&ctx.garbage_collector))
}
@(private)
_manage_string :: proc(ctx: ^Build_Context, data: string) -> (clone: string, err: Allocator_Error) #optional_allocator_error {
    return strings.clone(data, gc.allocator(&ctx.garbage_collector))
}
@(private)
_manage_ptr :: proc(ctx: ^Build_Context, data: $T/^$E) -> (clone: T, err: Allocator_Error) #optional_allocator_error {
    gc_allocator := gc.allocator(&ctx.garbage_collector)
    clone = new_clone(data^, gc_allocator) or_return
    return clone, nil
}
@(private)
_manage_string_slice :: proc(ctx: ^Build_Context, data: []string, clone_strings:=true) -> (clone: []string, err: Allocator_Error) #optional_allocator_error {
    clone = _manage_slice(ctx, data) or_return
    if clone_strings {
        for &s, i in data {
            clone[i] = _manage_string(ctx, s) or_return
        }
    }
    return clone, nil
}
@(private)
_manage_cmd :: proc(ctx: ^Build_Context, data: ^Sub_Process_Command, clone_members := false) -> (clone: ^Sub_Process_Command, err: Allocator_Error) #optional_allocator_error {
    clone = _manage_ptr(ctx, data) or_return
    if clone_members {
        clone.command = _manage_slice(ctx, data.command) or_return
        if env, ok := data.env.?; ok {
            clone.env = _manage_slice(ctx, env) or_return
        } else {
            clone.env = nil
        }
        clone.working_dir = _manage_string(ctx, data.working_dir) or_return
    }
    return clone, nil
}
@(private) _manage_mem :: proc{_manage_slice,_manage_string,_manage_ptr,_manage_cmd,_manage_string_slice}

when ODIN_DEBUG {
    Lowest_Build_Logger_Level :: log.Level.Debug
} else {
    Lowest_Build_Logger_Level :: log.Level.Info
}

Default_Build_Logger_Opts :: log.Options{
	.Level,
	.Terminal_Color,
	.Short_File_Path,
	.Line,
	.Procedure,
}

create_build_logger :: #force_inline proc(ctx: ^Build_Context, lowest := Lowest_Build_Logger_Level, opt := Default_Build_Logger_Opts) -> log.Logger {
    return log.create_console_logger(lowest=lowest, opt=opt, ident="build", allocator=ctx.allocator)
}

/* Creates a `Build_Context`, essential for any builds.
*/
create_build_context :: proc(
    allocator := context.allocator, 
    logger := context.logger,
    cache_file_system_path := DEFAULT_CACHE_FILE_SYSTEM_PATH, 
    c_import_output_path := DEFAULT_C_IMPORT_OUTPUT_PATH
) -> (ctx: Build_Context, err: Error) {
    ctx.allocator = allocator
    ctx.logger = logger

    gc.init_growing(&ctx.garbage_collector) or_return
    ctx.cache_file_system = cachefs.from(cache_file_system_path, ctx.allocator) or_return
    //ctx.c_import_infos = make([dynamic]^C_Import_Info, ctx.allocator) or_return
    ctx.c_import_output_path = c_import_output_path
    ctx.steps = make([dynamic]Step, ctx.allocator) or_return
    //ctx.post_build_steps = make([dynamic]Step, ctx.allocator) or_return
    ctx.stdout = subprocess.stdout()
    ctx.stderr = subprocess.stderr()
    ctx.working_dir = os2.get_working_directory(gc.allocator(&ctx.garbage_collector)) or_return
    ctx.state_fingerprint=Default_State_Hasher
    
    return ctx, nil
}

/* Destroy the contents of an `Build_Context` object, essential for memory safety.
*/
destroy_build_context :: proc(ctx: ^Build_Context) -> Error {
    context.logger = ctx.logger

    log.infof("[START] Destroying build context.")
    failed := true
    defer if failed do log.errorf("[FAIL] Destroying build context.")

    log.debugf("[START] Destroying build context file system.")
    cachefs.destroy(&ctx.cache_file_system) or_return
    log.debugf("[DONE] Destroying build context file system.")

    log.debugf("[START] Destroying build context step collection.")
    delete(ctx.steps) or_return
    log.debugf("[DONE] Destroying build context step collection.")

    log.debugf("[START] Destroying build context garbage collector.")
    gc.destroy(&ctx.garbage_collector)
    log.debugf("[DONE] Destroying build context garbage collector.")
    
    failed = false

    log.infof("[DONE] Destroying build context.")
    return nil
}

run_step :: proc(ctx: ^Build_Context, step: Step) -> (success: bool, err: Error) {
    context.logger = ctx.logger

    log.infof("[START] Running step. %s", step.name)
    defer if !success do log.errorf("[ERROR] Running step. %s", step.name)

    success = step.procedure(ctx, step.client_data) or_return
    
    if success do log.infof("[DONE] Running step. %s", step.name)
    return success, nil
}

/* NOTE: This uses `shell.run` internally, but omits functionality on what it returns.
         If your goal is to capture the output of the shell command and other metadata, instead use `shell.run`.

   To force disable coloured output, set `terminal.color_enabled` to false.   
   To force enable coloured output, set `terminal.color_enabled` to true.
*/
run_subprocess :: proc(ctx: ^Build_Context, cmd: ^Sub_Process_Command) -> (success: bool, err: Error) {
    context.logger = ctx.logger

    // stdout_color_enabled := ctx.stdout == nil ? false : subprocess.is_terminal(ctx.stdout) && terminal.color_enabled
    // stderr_color_enabled := ctx.stderr == nil ? false : subprocess.is_terminal(ctx.stderr) && terminal.color_enabled

    colour_enabled := .Terminal_Color in context.logger.options

    {
        sb := strings.builder_make() or_return
        defer strings.builder_destroy(&sb)
        for &token, i in cmd.command {
            if len(token) > 2 && ((token[0] == '"' && token[len(token)-1] == '"') || (token[0] == '\'' && token[len(token)-1] == '\'')) {
                fmt.sbprint(&sb,
                    colour_enabled ? ansi.CSI + ansi.FG_GREEN + ansi.SGR : "",
                    token, 
                    colour_enabled ? ansi.CSI + ansi.RESET + ansi.SGR : "",
                    i + 1 < len(cmd.command) ? " " : "", 
                    sep=""
                )
            } else if (strings.contains(token, " ") && len(token) > 1) {
                fmt.sbprint(&sb,
                    colour_enabled ? ansi.CSI + ansi.FG_GREEN + ansi.SGR : "",
                    '"', token, '"',
                    colour_enabled ? ansi.CSI + ansi.RESET + ansi.SGR : "",
                    i + 1 < len(cmd.command) ? " " : "", 
                    sep=""
                )
            } else {
                fmt.sbprint(&sb, token, i + 1 < len(cmd.command) ? " " : "", sep="")
            }
        }
        log.infof(
            "%sCMD:%s %s", 
            colour_enabled ? ansi.CSI + ansi.BOLD + ansi.SGR : "", colour_enabled ? ansi.CSI + ansi.RESET + ansi.SGR : "",
            strings.to_string(sb)
        )
    }

    cmd.stdout = ctx.stdout
    cmd.stderr = ctx.stderr
    state, stdout, stderr := subprocess.run(cmd^, ctx.allocator) or_return
    defer delete(stdout, ctx.allocator)
    defer delete(stderr, ctx.allocator)

    success = state.success when ODIN_OS != .Windows else state.exit_code == 0

    log.infof(
        "Program exited with code %s%d%s",
        colour_enabled ? (success ? ansi.CSI + ansi.FG_BRIGHT_GREEN + ansi.SGR : ansi.CSI + ansi.FG_BRIGHT_RED + ansi.SGR) : "",
        state.exit_code,
        colour_enabled ? ansi.CSI + ansi.RESET + ansi.SGR : ""
    )

    return success, nil
}

// Clones `cmd` and converts it to a step.
subprocess_to_step :: proc(ctx: ^Build_Context, cmd: ^Sub_Process_Command) -> (step: Step, err: Allocator_Error) {
    owned_cmd := _manage_mem(ctx, cmd, clone_members=true) or_return
    step.client_data = owned_cmd
    step.procedure = proc(ctx: ^Build_Context, client_data: rawptr) -> (success: bool, err: Error) {
        cmd := transmute(^Sub_Process_Command)client_data
        return run_subprocess(ctx, cmd)
    }
    return step, err
}

os_specific_subprocess_to_step :: proc(ctx: ^Build_Context, cmd: ^OS_Specific_Sub_Process) -> (step: Maybe(Step), err: Allocator_Error) {
    maybe_actual := resolve_os_specific_subprocess(cmd)
    if actual, ok := maybe_actual.?; ok {
        step = subprocess_to_step(ctx, &actual) or_return
    } else {
        step = nil
    }
    return step, nil
}

arch_specific_subprocess_to_step :: proc(ctx: ^Build_Context, cmd: ^Arch_Specific_Sub_Process) -> (step: Maybe(Step), err: Allocator_Error) {
    maybe_actual := resolve_arch_specific_subprocess(cmd)
    if actual, ok := maybe_actual.?; ok {
        step = subprocess_to_step(ctx, &actual) or_return
    } else {
        step = nil
    }
    return step, nil
}

os_specific_subprocess_to_subprocess :: #force_inline proc(ctx: ^Build_Context, cmd: ^OS_Specific_Sub_Process) -> (subprocess: Maybe(Sub_Process_Command), err: Allocator_Error) {
    return resolve_os_specific_subprocess(cmd)^, nil
}
arch_specific_subprocess_to_subprocess :: #force_inline proc(ctx: ^Build_Context, cmd: ^Arch_Specific_Sub_Process) -> (subprocess: Maybe(Sub_Process_Command), err: Allocator_Error) {
    return resolve_arch_specific_subprocess(cmd)^, nil
}

/* Use the `Build_Context` to build the respective project.
*/
build :: proc(ctx: ^Build_Context) -> (err: Error) {
    context.logger = ctx.logger

    colour_enabled := .Terminal_Color in context.logger.options

    log.infof("[START] Building.")
    failed := true
    defer if failed do log.errorf("[ERROR] Building.")

    for &c in ctx.steps {
        if success := run_step(ctx, c) or_return; !success && c.success_required {
            log.errorf(
                "This step was %[0]sREQUIRED%[1]s to pass, but %[0]sfailed%[1]s. %[0]sNO MORE STEPS WILL BE RAN%[1]s",
                colour_enabled ? ansi.CSI + ansi.BOLD + ansi.SGR : "",
                colour_enabled ? ansi.CSI + ansi.RESET + ansi.SGR : ""
            )
            break // No more steps will be ran
        }

        // if ctx.stdout != nil {
        //     oh := subprocess.as_unsafe_os_handle(ctx.stdout)
        //     fmt.fprintln(oh)
        //     fmt.fprintfln(oh, "%s", [55]u8{ 0..<55='=' })
        // }
    }

    failed = false
    log.infof("[DONE] Building.")

    return nil
}

/* Include header file paths, or directory paths (all header files will be captured) to `C_Import_Info` object.
*/
c_include :: ci.include

/* Creates and manages a new `C_Import_Info` object. You can edit the properties of `info` to adjust how you want the specified headers to be
   parsed.  
   **NOTE:** You can add more include paths, using `c_include`.
*/
c_import :: proc(ctx: ^Build_Context, package_name: string, include_paths: ..string) -> (info: ^C_Import_Info, err: Error) {
    info = ci.make_import_info(&ctx.cache_file_system, gc.allocator(&ctx.garbage_collector)) or_return
    info.package_name = package_name
    output_folder := filepath.join({ ctx.c_import_output_path, info.package_name }, ctx.allocator) or_return
    defer delete(output_folder) 
    info.output_folder = _manage_mem(ctx, output_folder) or_return
    c_include(info, ..include_paths) or_return
    return info, nil
}

/* Parses the information provided, and generates the respective bindings.  
   **NOTE:** Try to avoid using it on info provided from `c_import`, everything would work as intended, however this process would 
   uneccessarily be ran twice, instead convert it to a step (`to_step`) and add it to the build process (`add_step`)
*/
c_import_info :: proc(ctx: ^Build_Context, info: ^C_Import_Info) -> (err: Error) {
    ci.import_info(info, ctx.allocator) or_return
    return nil
}

c_import_info_to_step :: proc(ctx: ^Build_Context, info: ^C_Import_Info) -> (step: Step, err: Allocator_Error) #optional_allocator_error {
    client_data := _C_Import_Info_Client_Data{
        info=info,
        ctx=ctx
    }
    step.client_data = _manage_mem(ctx, &client_data) or_return
    step.procedure = proc(ctx: ^Build_Context, client_data: rawptr) -> (success: bool, err: Error) {
        ciicd := transmute(^_C_Import_Info_Client_Data)client_data
        c_import_info(ciicd.ctx, ciicd.info) or_return
        return true, nil
    }
    return step, nil
}

to_subprocess :: proc{
    odin_build_to_subprocess,
    odin_run_to_subprocess,
    make_to_subprocess,
    os_specific_subprocess_to_subprocess,
    arch_specific_subprocess_to_subprocess
}
to_step :: proc{
    subprocess_to_step,
    odin_build_to_step,
    odin_run_to_step,
    make_to_step,
    os_specific_subprocess_to_step,
    arch_specific_subprocess_to_step,
    c_import_info_to_step
}

add_step :: #force_inline proc(ctx: ^Build_Context, steps: ..Step) -> Allocator_Error {
    append(&ctx.steps, ..steps) or_return
    return nil
}

// Using the `hasher`, it will determine whether the step belongs in the overall build.
plan_step :: proc(ctx: ^Build_Context, fingerprint: Hasher, s: Step) -> (step: Maybe(Step), err: Error) {
    base_fingerprint_v := run_hasher(fingerprint)
    if cachefs.hash_exists(&ctx.cache_file_system, base_fingerprint_v) {
        path := cachefs.path_from_hash(&ctx.cache_file_system, base_fingerprint_v) or_return
        client_data := State_Hasher_Client_Data{ ctx=ctx, exclude=path }
        ctx.state_fingerprint.client_data = &client_data
        full_fingerprint_v := base_fingerprint_v ~ run_hasher(ctx.state_fingerprint)
        hex_hash_buf: [17]byte
        hex_hash := strconv.write_uint(hex_hash_buf[:], full_fingerprint_v, 16)
        orig_data := os2.read_entire_file(path, context.allocator) or_return
        defer delete(orig_data)
        if strings.compare(hex_hash, transmute(string)orig_data) == 0 do return nil, nil
        os2.write_entire_file(path, hex_hash) or_return
        return s, nil
    } else {
        client_data := State_Hasher_Client_Data{ ctx=ctx, exclude=nil }
        ctx.state_fingerprint.client_data = &client_data
        full_fingerprint_v := base_fingerprint_v ~ run_hasher(ctx.state_fingerprint)
        path := cachefs.create_from_hash(&ctx.cache_file_system, base_fingerprint_v) or_return
        hex_hash_buf: [17]byte
        hex_hash := strconv.write_uint(hex_hash_buf[:], full_fingerprint_v, 16)
        os2.write_entire_file(path, hex_hash) or_return
        return s, nil
    }
}

Fingerprint_Target :: union($T: typeid) { T, Hasher }

fingerprint :: proc(ctx: ^Build_Context, targets: ..Hasher) -> (output: Hasher, err: Allocator_Error) #optional_allocator_error {
    context.logger = ctx.logger

    log.infof("[START] Creating fingerprint for targets.")
    failed := true
    defer if failed do log.errorf("[ERROR] Creating fingerprint for targets.")
    if ctx.verbose_debug do log.debug(targets)

    managed_targets := _manage_mem(ctx, targets) or_return
    managed_targets_ptr := _manage_mem(ctx, &managed_targets) or_return

    failed = false

    output.procedure = proc(client_data: rawptr) -> u64 {
        targets := transmute(^[]Hasher)client_data
        result: u64 = 0
        for &target in targets do result ~= run_hasher(target)
        return result
    }
    output.client_data = managed_targets_ptr

    log.infof("[DONE] Creating fingerprint for targets.")
    return output, nil
}

files_fingerprint :: proc(ctx: ^Build_Context, targets: ..Fingerprint_Target(string), dir_glob_patterns: []string = { "*" }, file_glob_patterns: []string = {}) -> (output: Hasher, err: Allocator_Error) #optional_allocator_error {
    context.logger = ctx.logger
    
    log.infof("[START] Creating fingerprint targets from file targets.")
    failed := true
    defer if failed do log.errorf("[FAIL] Creating fingerprint for file targets.")
    log.debug(targets)

    sanitized_targets := make([dynamic]Hasher, 0, len(targets), ctx.allocator) or_return
    defer delete(sanitized_targets)

    for &unknown_target in targets {
        switch target in unknown_target {
            case string:
                if os2.is_dir(target) {
                    log.debugf("Found directory: %q", target)
                    walker := os2.walker_create(target)
                    defer os2.walker_destroy(&walker)

                    log.debugf("[START] Walking ...")
                    walking_failed := true
                    defer if walking_failed do log.errorf("[FAIL] Walking ...")

                    for info in os2.walker_walk(&walker) {
                        _ = os2.walker_error(&walker) or_continue

                        if info.type == .Directory {
                            rel_path := info.fullpath
                            matched := false
                            match_target := filepath.base(rel_path)
                            for &pattern in dir_glob_patterns {
                                glob_match, glob_match_err := filepath.match(pattern, match_target)
                                if glob_match_err != nil do glob_match = false
                                if glob_match {
                                    matched = true
                                    break
                                }
                            }
                            log.debugf("Skipping: %t, Relative path: %q", !matched, rel_path)
                            if !matched && len(dir_glob_patterns) > 0 {
                                os2.walker_skip_dir(&walker)
                                continue
                            }
                        } else if info.type == .Regular {
                            rel_path := info.fullpath
                            matched := false
                            match_target := filepath.base(rel_path)
                            for &pattern in file_glob_patterns {
                                glob_match, glob_match_err := filepath.match(pattern, match_target)
                                if glob_match_err != nil do glob_match = false
                                if glob_match {
                                    matched = true
                                    break
                                }
                            }
                            log.debugf("Skipping: %t, Relative path: %q", !matched, rel_path)
                            if !matched && len(file_glob_patterns) > 0 {
                                continue
                            }

                            managed_fullpath := _manage_mem(ctx, info.fullpath) or_return
                            managed_fullpath_ptr := _manage_mem(ctx, &managed_fullpath) or_return
                            append(&sanitized_targets, Hasher{
                                procedure=proc(client_data: rawptr) -> u64 {
                                    path_ptr := transmute(^string)client_data
                                    path := path_ptr^
                                    if !os2.exists(path) do return empty_hasher_procedure(client_data)
                                    b, b_err := os2.read_entire_file(path, context.allocator)
                                    if b_err != nil do return empty_hasher_procedure(client_data)
                                    return hash_algo.murmur64a(b)
                                },
                                client_data=managed_fullpath_ptr
                            }) or_return
                        }
                    }

                    walking_failed = false
                    log.debugf("[DONE] Walking.")
                } else {
                    log.debugf("Found file: %q", target)
                    rel_path := target
                    matched := false
                    match_target := filepath.base(rel_path)
                    for &pattern in file_glob_patterns {
                        glob_match, glob_match_err := filepath.match(pattern, match_target)
                        if glob_match_err != nil do glob_match = false
                        if glob_match {
                            matched = true
                            break
                        }
                    }
                    log.debugf("Skipping: %t, Relative path: %q", !matched, rel_path)
                    if !matched && len(file_glob_patterns) > 0 {
                        continue
                    }

                    managed_target := _manage_mem(ctx, target) or_return
                    managed_target_ptr := _manage_mem(ctx, &managed_target) or_return
                    append(&sanitized_targets, Hasher{
                        procedure=proc(client_data: rawptr) -> u64 {
                            path_ptr := transmute(^string)client_data
                            path := path_ptr^
                            if !os2.exists(path) do return empty_hasher_procedure(client_data)
                            b, b_err := os2.read_entire_file(path, context.allocator)
                            if b_err != nil do return empty_hasher_procedure(client_data)
                            return hash_algo.murmur64a(b)
                        },
                        client_data=managed_target_ptr
                    }) or_return
                }
            case Hasher:
                append(&sanitized_targets, target) or_return
        }
    }
    
    failed = false
    log.info("[DONE] Creating fingerprint targets from file targets.")
    if ctx.verbose_debug do log.debug(sanitized_targets[:])

    return fingerprint(ctx, ..sanitized_targets[:])
}