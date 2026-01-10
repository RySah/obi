package obi

VERBOSE      :: #config(VERBOSE, false)
//THREAD_COUNT :: #config(J, 0)

import "core:fmt"
import "core:os/os2"
import "core:path/filepath"
import "core:terminal/ansi"
import "core:strings"
import "core:slice"
import "core:mem/virtual"
import hash_algo "core:hash"
import "core:math/bits"
import "core:log"
import "core:strconv"
import "core:time"
import "core:thread"
import "core:sync"
import "core:os"
import "core:flags"
import thread_safe_allocator "thread_safe/allocator"
import thread_safe_array "thread_safe/array"
import thread_safe_logger "thread_safe/logger"

import "base:runtime"

import "core:mem"
Allocator :: mem.Allocator
Allocator_Error :: mem.Allocator_Error

import bindgen "bindgen"
Bindgen_Factory :: bindgen.Factory
Bindgen_Emit_Options :: bindgen.Emit_Options
Bindgen_Foreign_Get :: bindgen.Foreign_Get
Bindgen_Foreign_Import_Expr :: bindgen.Foreign_Import_Expr
Bindgen_Foreign_Import_Path :: bindgen.Foreign_Import_Path
import cbindgen "bindgen/c"
C_Bindgen_Parser_Error :: cbindgen.Parser_Error
C_Bindgen_Parser_Options :: cbindgen.Parse_Options

import cachefs "cache_fs"
Cache_File_System_Error :: cachefs.Error
Cache_File_System :: cachefs.File_System

import subprocess "subprocess"
Sub_Process_File :: subprocess.File
Sub_Process_Error :: subprocess.Error
Sub_Process_Command :: subprocess.Command

import ia "intern_arena"
IA_Error :: ia.Error
Intern_Arena :: ia.Arena

General_Error :: enum u8 {
    None,
    Failed_To_Parse_User_Args
}

Error :: union #shared_nil {
    General_Error,
    C_Bindgen_Parser_Error,
    Cache_File_System_Error,
    Sub_Process_Error,
    Allocator_Error,
    Make_Error,
    CMake_Error,
    VS_Error
}

DEFAULT_CACHE_FILE_SYSTEM_PATH :: ".obi-cache"
DEFAULT_C_EXPORT_PATH :: "c_export"

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
    AMD64,
    I386,
    ARM32,
    ARM64,
    WASM32,
    WASM64p32,
    RISCV64,
}

OS_Specific_Sub_Process :: [OS_Type]Maybe(Sub_Process_Command)
Arch_Specific_Sub_Process :: [Arch_Type]Maybe(Sub_Process_Command)
OS_Arch_Specific_Sub_Process :: [OS_Type][Arch_Type]Maybe(Sub_Process_Command)

Step :: struct {
    name: string,
    procedure: #type proc(ctx: ^Build_Context, client_data: rawptr) -> (success: bool, err: Error),
    client_data: rawptr,
    success_required: bool,
    children: [dynamic]^Step,
    // Set during `build`    
    build_time_flags: bit_field u8 {
        completed: bool | 1
    }
}

empty_step_procedure :: proc(^Build_Context,rawptr) -> (bool, Error) { return true, nil }

empty_step := Step {
    name="",
    procedure=empty_step_procedure,
    client_data=nil,
    success_required=false,
    children=nil
}

OS_Specific_Step :: [OS_Type]^Step
Arch_Specific_Step :: [Arch_Type]^Step
OS_Arch_Specific_Step :: [OS_Type][Arch_Type]^Step

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
resolve_os_arch_specific_subprocess :: #force_inline proc(s: ^OS_Arch_Specific_Sub_Process) -> ^Maybe(Sub_Process_Command) {
    return &s[transmute(OS_Type)ODIN_OS][transmute(Arch_Type)ODIN_ARCH]
}

resolve_os_specific_step :: #force_inline proc(s: ^OS_Specific_Step) -> ^Step {
    return s[transmute(OS_Type)ODIN_OS]
}
resolve_arch_specific_step :: #force_inline proc(s: ^Arch_Specific_Step) -> ^Step {
    return s[transmute(Arch_Type)ODIN_ARCH]
}
resolve_os_arch_specific_step :: #force_inline proc(s: ^OS_Arch_Specific_Step) -> ^Step {
    return s[transmute(OS_Type)ODIN_OS][transmute(Arch_Type)ODIN_ARCH]
}

resolve_os_specific :: proc{resolve_os_specific_step,resolve_os_specific_subprocess}
resolve_arch_specific :: proc{resolve_arch_specific_step,resolve_arch_specific_subprocess}
resolve_os_arch_specific :: proc{resolve_os_arch_specific_step,resolve_os_arch_specific_subprocess}

Global_Build_Context :: struct {
    // Helps trace reasons for errors
    error_loc_trace: Location_Trace
}

global_ctx: Global_Build_Context

@private _User_Args_Options :: struct {
    job_count: int `args:"name=j" usage:"Number of parallel jobs / threads"`,
    target_step_name: string `args:"pos=0,required" usage:"Step to run"`,
    overflow: [dynamic]string `usage:"Extra arguments"`,
}

@(private) _start_trace :: #force_inline proc() { lt_start_trace(&global_ctx.error_loc_trace) }
@(private) _backtrace :: #force_inline proc() { lt_backtrace(&global_ctx.error_loc_trace) }
@(private) _trace :: #force_inline proc(caller_location := #caller_location) { lt_trace_location(&global_ctx.error_loc_trace, caller_location) }

@(cold)
init :: proc(allocator := context.allocator) -> Error {
    context.allocator = allocator
    lt_init_location_trace(&global_ctx.error_loc_trace, context.allocator) or_return
    return nil
}

@(cold)
deinit :: proc() -> Error {
    lt_destroy_location_trace(&global_ctx.error_loc_trace)
    return nil
}

Build_Context :: struct {
    // Allocator
    allocator: Allocator,
    // Logger
    logger: log.Logger,
    // Intern arena for deduplicating and owning resources.
    intern_arena: Intern_Arena,
    // The cache file system.
    cache_file_system: Cache_File_System,
    // Default parent directory for C imports.  
    // **NOTE:** You are not forced to use this for C imports, simply change `C_Import_Info.output_directory` to customize it for that specific object.
    c_export_path: string,
    // Output handle for all subprocess commands.    
    // **NOTE:** Set to the system stdout (`subprocess.stdout`) by default.
    stdout: ^Sub_Process_File, 
    // Error output handle for all subprocess commands.    
    // **NOTE:** Set to the system stderr (`subprocess.stderr`) by default.
    stderr: ^Sub_Process_File,
    // Current working directory
    working_dir: string,
    // This is the hasher that provides a unique value to planned steps, based off the state of its environment.  
    // The **default** hasher will hash all items in the `cache_file_system`, this ensures planned steps will only be
    // ran, if not only provided the fingerprint is the same, but the state of the cache is also the same. Change this value
    // if other states should be taken into account. The **default** is defined at `Default_State_Hasher`.
    state_fingerprint: Hasher,
    // Context data specific to windows. This will only be managed when `ODIN_OS == .Windows`
    windows: struct {
        visual_studio_releases: VS_Releases,
        visual_studio_cmake_path: Maybe(string)
    },
    // Data used internally
    _internal: struct {
        step_collection: [dynamic]^Step,
        using user_args_options: _User_Args_Options
    }
}

get_thread_count :: proc(ctx: ^Build_Context) -> int { return ctx._internal.job_count }
set_thread_count :: proc(ctx: ^Build_Context, v: int) { ctx._internal.job_count = v }

get_target_step_name :: proc(ctx: ^Build_Context) -> string { return ctx._internal.target_step_name }

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
            full_path := info.fullpath

            if exclude, ok := maybe_exclude.?; ok {
                if strings.compare(full_path, exclude) == 0 do continue
            }

            result |= hash_algo.murmur64a(transmute([]u8)full_path)
            content, content_err := os2.read_entire_file(full_path, context.allocator)
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

Debug_Mode_Lowest_Build_Logger_Level :: log.Level.Debug
Release_Mode_Lowest_Build_Logger_Level :: log.Level.Info

Debug_Mode_Build_Logger_Opts :: log.Options{
    .Level,
    .Terminal_Color,
    .Short_File_Path,
    .Line,
    .Procedure,
}
Release_Mode_Build_Logger_Opts :: log.Options{
    .Level,
    .Terminal_Color,
    .Short_File_Path,
    .Procedure,
}

when ODIN_DEBUG {
    Default_Lowest_Build_Logger_Level :: Debug_Mode_Lowest_Build_Logger_Level
} else {
    Default_Lowest_Build_Logger_Level :: Release_Mode_Lowest_Build_Logger_Level
}

when ODIN_DEBUG {
    Default_Build_Logger_Opts :: Debug_Mode_Build_Logger_Opts
} else {
    Default_Build_Logger_Opts :: Release_Mode_Build_Logger_Opts
}

create_build_logger :: #force_inline proc(ctx: ^Build_Context, subdomain := "", lowest := Default_Lowest_Build_Logger_Level, opt := Default_Build_Logger_Opts, caller_location := #caller_location) -> (logger: log.Logger, err: Allocator_Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    return log.create_console_logger(
        lowest=lowest, 
        opt=opt, 
        ident=len(subdomain) > 0 ? strings.concatenate({ "build-", subdomain }, ia.allocator(&ctx.intern_arena)) or_return : "build", 
        allocator=ctx.allocator
    ), nil
}

destroy_build_logger :: #force_inline proc(ctx: ^Build_Context, logger: log.Logger) {
    log.destroy_console_logger(logger, ctx.allocator)
}

/* Creates a `Build_Context`, essential for any builds.
*/
create_build_context :: proc(
    user_args: []string,
    is_main := false,
    allocator := context.allocator, 
    logger := context.logger,
    cache_file_system_path := DEFAULT_CACHE_FILE_SYSTEM_PATH, 
    c_export_path := DEFAULT_C_EXPORT_PATH,
    caller_location := #caller_location
) -> (ctx: Build_Context, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    ctx.allocator = allocator
    ctx.logger = logger

    user_opts_parsing_style := flags.Parsing_Style.Unix
    user_opts_parse_err := flags.parse(&ctx._internal.user_args_options, user_args, user_opts_parsing_style, allocator=ctx.allocator)
    if user_opts_parse_err != nil {
        if is_main {
            program := os.args[0]
		    stderr := os.stream_from_handle(os.stderr)
            
		    if len(user_args) == 0 {
		    	// No arguments entered, and there was an error; show the usage,
		    	// specifically on STDERR.
		    	flags.write_usage(stderr, _User_Args_Options, program, user_opts_parsing_style)
		    	fmt.wprintln(stderr)
		    }

		    flags.print_errors(_User_Args_Options, user_opts_parse_err, program, user_opts_parsing_style)
        }

        return ctx, General_Error.Failed_To_Parse_User_Args
	}
    when thread.IS_SUPPORTED {
        if ctx._internal.user_args_options.job_count == 0 do ctx._internal.user_args_options.job_count = os.processor_core_count()
    }
    ia.init_growing(&ctx.intern_arena, ctx.allocator) or_return
    ctx.cache_file_system = cachefs.from(cache_file_system_path, ctx.allocator) or_return
    ctx.c_export_path = c_export_path
    ctx.stdout = subprocess.stdout()
    ctx.stderr = subprocess.stderr()
    ctx.working_dir = ta_os2_get_working_directory(ia.allocator(&ctx.intern_arena)) or_return
    ctx.state_fingerprint=Default_State_Hasher
    when ODIN_OS == .Windows {
        vs_err: VS_Error
        if ctx.windows.visual_studio_releases, vs_err = vs_get_release_infos(&ctx); vs_err == nil {
            best_visual_studio_release := vs_get_best_release(ctx.windows.visual_studio_releases)
            found_cmake: bool
            ctx.windows.visual_studio_cmake_path, found_cmake, vs_err = vs_which(&ctx, best_visual_studio_release^, "cmake", cwd=ctx.working_dir)
            if vs_err == VS_General_Error.Missing_Program || vs_err == nil {
                if !found_cmake do ctx.windows.visual_studio_cmake_path = nil
            } else {
                return ctx, vs_err
            }
        } else if vs_err != VS_General_Error.Missing_Program {
            return ctx, vs_err
        }
    }
    ctx._internal.step_collection = make([dynamic]^Step, ctx.allocator) or_return
    return ctx, nil
}

/* Destroy the contents of an `Build_Context` object, essential for memory safety.
*/
destroy_build_context :: proc(ctx: ^Build_Context, caller_location := #caller_location) -> (err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    context.logger = ctx.logger

    log.infof("[START] Destroying build context.")
    defer if err != nil do log.errorf("[FAIL] Destroying build context.")

    log.debugf("[START] Destroying build context file system.")
    cachefs.destroy(&ctx.cache_file_system) or_return
    log.debugf("[DONE] Destroying build context file system.")

    log.debugf("[START] Destroying build context step collection.")
    _traverse_steps(ctx._internal.step_collection[:], nil, proc(step: ^Step, _: rawptr) -> ^Step {
        if step.children != nil {
            delete(step.children)
            step.children = nil
        }
        return nil
    })
    delete(ctx._internal.step_collection) or_return
    log.debugf("[DONE] Destroying build context step collection.")

    log.debugf("[START] Destroying build context garbage collector.")
    ia.destroy(&ctx.intern_arena) or_return
    log.debugf("[DONE] Destroying build context garbage collector.")

    log.infof("[DONE] Destroying build context.")
    return nil
}

run_step :: proc(ctx: ^Build_Context, step: ^Step, caller_location := #caller_location) -> (success: bool, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

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
run_subprocess :: proc(ctx: ^Build_Context, cmd: ^Sub_Process_Command, caller_location := #caller_location) -> (success: bool, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

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
subprocess_to_step :: proc(ctx: ^Build_Context, cmd: ^Sub_Process_Command, caller_location := #caller_location) -> (step: ^Step, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()
    
    owned_cmd := ia.clone_ptr(&ctx.intern_arena, cmd) or_return
    owned_cmd.working_dir = ia.intern_string(&ctx.intern_arena, cmd.working_dir) or_return
    owned_cmd.command = ia.clone_slice(&ctx.intern_arena, cmd.command) or_return
    for &token, i in cmd.command do owned_cmd.command[i] = ia.intern_string(&ctx.intern_arena, token) or_return
    if env, env_exists := cmd.env.?; env_exists {
        owned_cmd.env = ia.clone_slice(&ctx.intern_arena, env) or_return
        for &token, i in env do owned_cmd.env.?[i] = ia.intern_string(&ctx.intern_arena, token) or_return
    }
    step = create_step(ctx) or_return
    step.client_data = owned_cmd
    step.procedure = proc(ctx: ^Build_Context, client_data: rawptr) -> (success: bool, err: Error) {
        cmd := transmute(^Sub_Process_Command)client_data
        return run_subprocess(ctx, cmd)
    }
    return step, err
}
os_specific_subprocess_to_step :: proc(ctx: ^Build_Context, cmd: ^OS_Specific_Sub_Process, caller_location := #caller_location) -> (step: ^Step, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    maybe_actual := resolve_os_specific_subprocess(cmd)
    if actual, ok := maybe_actual.?; ok {
        step = subprocess_to_step(ctx, &actual) or_return
    } else {
        step = nil
    }
    return step, nil
}
arch_specific_subprocess_to_step :: proc(ctx: ^Build_Context, cmd: ^Arch_Specific_Sub_Process, caller_location := #caller_location) -> (step: ^Step, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    maybe_actual := resolve_arch_specific_subprocess(cmd)
    if actual, ok := maybe_actual.?; ok {
        step = subprocess_to_step(ctx, &actual) or_return
    } else {
        step = nil
    }
    return step, nil
}
os_arch_specific_subprocess_to_step :: proc(ctx: ^Build_Context, cmd: ^OS_Arch_Specific_Sub_Process, caller_location := #caller_location) -> (step: ^Step, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    maybe_actual := resolve_os_arch_specific_subprocess(cmd)
    if actual, ok := maybe_actual.?; ok {
        step = subprocess_to_step(ctx, &actual) or_return
    } else {
        step = nil
    }
    return step, nil
}

os_specific_subprocess_to_subprocess :: #force_inline proc(ctx: ^Build_Context, cmd: ^OS_Specific_Sub_Process, caller_location := #caller_location) -> (subprocess: Maybe(Sub_Process_Command), err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()
    return resolve_os_specific_subprocess(cmd)^, nil
}
arch_specific_subprocess_to_subprocess :: #force_inline proc(ctx: ^Build_Context, cmd: ^Arch_Specific_Sub_Process, caller_location := #caller_location) -> (subprocess: Maybe(Sub_Process_Command), err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()
    return resolve_arch_specific_subprocess(cmd)^, nil
}
os_arch_specific_subprocess_to_subprocess :: #force_inline proc(ctx: ^Build_Context, cmd: ^OS_Arch_Specific_Sub_Process, caller_location := #caller_location) -> (subprocess: Maybe(Sub_Process_Command), err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()
    return resolve_os_arch_specific_subprocess(cmd)^, nil
}

run_step_tree :: proc(ctx: ^Build_Context, step: ^Step, caller_location := #caller_location) -> (err: Error)  {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    _single_thread_impl :: proc(ctx: ^Build_Context, target_step: ^Step, colour_enabled: bool) -> (err: Error) {
        context.allocator = ctx.allocator
        context.logger = ctx.logger

        if target_step.children != nil && len(target_step.children) > 0 {
            for step in target_step.children do _single_thread_impl(ctx, step, colour_enabled) or_return
        }
        
        if success := run_step(ctx, target_step) or_return; !success && target_step.success_required {
            log.errorf(
                "The step %[0]q was %[1]sREQUIRED%[2]s to pass, but %[1]sfailed%[2]s. %[1]sNO MORE STEPS WILL BE RAN%[2]s",
                target_step.name,
                colour_enabled ? ansi.CSI + ansi.BOLD + ansi.SGR : "",
                colour_enabled ? ansi.CSI + ansi.RESET + ansi.SGR : ""
            )
            return nil
        }

        return nil
    }

    // _multi_thread_impl :: proc(ctx: ^Build_Context, target_step: ^Step, colour_enabled: bool, thread_count: int) -> (err: Error) {
    //     context.logger = ctx.logger
    //     context.allocator = ctx.allocator

    //     if target_step.children != nil && len(target_step.children) > 0 {
    //         _Basic_Thread_Safe :: struct($U: typeid) {
    //             data: ^U,
    //             mutex: sync.Mutex
    //         }

    //         tsa: thread_safe_allocator.Thread_Safe_Allocator
    //         thread_safe_allocator.init(&tsa, context.allocator)
    //         context.allocator = tsa

    //         tsl: thread_safe_logger.Thread_Safe_Logger
    //         thread_safe_logger.init(&tsl, context.logger)
    //         context.logger = tsl

    //         ts_build_ctx: _Basic_Thread_Safe(Build_Context)
    //         ts_build_ctx.data = ctx

    //         pool: thread.Pool
    //         thread.pool_init(&pool, context.allocator, thread_count)
    //         defer thread.pool_destroy(&pool)

    //         _task_factory :: proc(
    //             ctx: ^_Basic_Thread_Safe(Build_Context), 
    //             step: ^Step, 
    //             colour_enabled: bool, 
    //             thread_pool: ^thread.Pool
    //         ) -> (err: Error) {
    //             _Task_Data :: struct {
    //                 ctx: ^_Basic_Thread_Safe(Build_Context),
    //                 step: ^Step,
    //                 colour_enabled: bool,
    //                 thread_pool: ^thread.Pool
    //             }

    //             if step.children != nil && len(step.children) > 0 {
    //                 task_data_storage := make([]_Task_Data, len(step.children)) or_return
    //                 defer delete(task_data_storage)

    //                 for child, i in step.children {
    //                     task_data := &task_data_storage[i]
    //                     task_data^ = _Task_Data{
    //                         ctx = ctx,
    //                         step = child,
    //                         colour_enabled = colour_enabled,
    //                         thread_pool = thread_pool,
    //                     }

    //                     thread.pool_add_task(
    //                         thread_pool, 
    //                         context.allocator,
    //                         proc(task: thread.Task) {
    //                             context.allocator = task.allocator
    //                             data := transmute(^_Task_Data)task.data

    //                             _task_factory(data.ctx, data.step, data.colour_enabled, data.thread_pool)
    //                         },
    //                         task_data,
    //                         user_index=i
    //                     )

    //                     thread.pool_finish(thread_pool)

    //                     for &data in task_data_storage {
    //                         if !data.step.build_time_flags.completed {
    //                             log.errorf(
    //                                 "Children of the step %[0]q was %[1]sREQUIRED%[2]s to pass, but %[1]sfailed%[2]s. %[1]sNO MORE STEPS WILL BE RAN%[2]s",
    //                                 step.name,
    //                                 colour_enabled ? ansi.CSI + ansi.BOLD + ansi.SGR : "",
    //                                 colour_enabled ? ansi.CSI + ansi.RESET + ansi.SGR : ""
    //                             )
    //                             return nil
    //                         }
    //                     }
    //                 }
    //             }

    //             if sync.mutex_guard(&ctx.mutex) {
    //                 if success := run_step(ctx.data, step) or_return; !success && step.success_required {
    //                     log.errorf(
    //                         "The step %[0]q was %[1]sREQUIRED%[2]s to pass, but %[1]sfailed%[2]s. %[1]sNO MORE STEPS WILL BE RAN%[2]s",
    //                         step.name,
    //                         colour_enabled ? ansi.CSI + ansi.BOLD + ansi.SGR : "",
    //                         colour_enabled ? ansi.CSI + ansi.RESET + ansi.SGR : ""
    //                     )
    //                     step.build_time_flags.completed = false
    //                     return nil
    //                 } else {
    //                     step.build_time_flags.completed = true
    //                 }
    //             }

    //             return nil
    //         }

    //         context.logger = thread_safe_logger.original(&tsl)
    //         context.allocator = thread_safe_allocator.original(&tsa)
    //     }

    //     if success := run_step(ctx, target_step) or_return; !success && target_step.success_required {
    //         log.errorf(
    //             "The step %[0]q was %[1]sREQUIRED%[2]s to pass, but %[1]sfailed%[2]s. %[1]sNO MORE STEPS WILL BE RAN%[2]s",
    //             target_step.name,
    //             colour_enabled ? ansi.CSI + ansi.BOLD + ansi.SGR : "",
    //             colour_enabled ? ansi.CSI + ansi.RESET + ansi.SGR : ""
    //         )
    //         return nil
    //     }

    //     return nil
    // }

    _multi_thread_impl :: proc(
        ctx: ^Build_Context,
        target_step: ^Step,
        colour_enabled: bool,
        thread_count: int
    ) -> (err: Error) {

        context.logger = ctx.logger
        context.allocator = ctx.allocator

        _Basic_Thread_Safe :: struct($U: typeid) {
            data: ^U,
            mutex: sync.Mutex
        }

        tsa: thread_safe_allocator.Thread_Safe_Allocator
        thread_safe_allocator.init(&tsa, context.allocator)
        context.allocator = tsa
        ctx.allocator = context.allocator

        tsl: thread_safe_logger.Thread_Safe_Logger
        thread_safe_logger.init(&tsl, context.logger)
        context.logger = tsl
        ctx.logger = context.logger

        ts_build_ctx: _Basic_Thread_Safe(Build_Context)
        ts_build_ctx.data = ctx

        pool: thread.Pool
        thread.pool_init(&pool, context.allocator, thread_count)
        defer thread.pool_destroy(&pool)

        _Task_Data :: struct {
            ctx: ^_Basic_Thread_Safe(Build_Context),
            step: ^Step,
            colour_enabled: bool,
            thread_pool: ^thread.Pool
        }

        _task_proc : thread.Task_Proc : proc(task: thread.Task) {
            data := transmute(^_Task_Data)task.data

            // Just run the step
            success := false
            if sync.mutex_guard(&data.ctx.mutex) {
                success, _ = run_step(data.ctx.data, data.step)
                data.step.build_time_flags.completed = success
            }
        
            if !success && data.step.success_required {
                log.errorf(
                    "The step %[0]q was %[1]sREQUIRED%[2]s to pass, but %[1]sfailed%[2]s.",
                    data.step.name,
                    data.colour_enabled ? ansi.CSI + ansi.BOLD + ansi.SGR : "",
                    data.colour_enabled ? ansi.CSI + ansi.RESET + ansi.SGR : ""
                )
                data.step.build_time_flags.completed = false
            } else {
                data.step.build_time_flags.completed = true
            }
        
            free(data)
        }

        _enqueue_step_tree :: proc(step: ^Step, ctx: ^_Basic_Thread_Safe(Build_Context), colour_enabled: bool, thread_pool: ^thread.Pool) {
            // Enqueue children first
            if step.children != nil && len(step.children) > 0 {
                for child in step.children {
                    _enqueue_step_tree(child, ctx, colour_enabled, thread_pool)
                }
            }
        
            data := new(_Task_Data)
            data^ = _Task_Data{
                ctx = ctx,
                step = step,
                colour_enabled = colour_enabled,
                thread_pool = thread_pool
            }
        
            thread.pool_add_task(thread_pool, context.allocator, _task_proc, data)
        }

        _enqueue_step_tree(target_step, &ts_build_ctx, colour_enabled, &pool)
        thread.pool_start(&pool)

        // Root waits
        thread.pool_finish(&pool)

        context.logger = thread_safe_logger.original(&tsl)
        ctx.logger = context.logger
        context.allocator = thread_safe_allocator.original(&tsa)
        ctx.allocator = context.allocator

        return nil
    }

    target_step := step
    colour_enabled := .Terminal_Color in context.logger.options

    when !thread.IS_SUPPORTED {
        return _single_thread_impl(ctx, target_step, colour_enabled)
    } else {
        thread_count := get_thread_count(ctx)
        if thread_count > 1 { // TODO(rysah): Perhaps provide more conditions to help optimize usage.
            return _multi_thread_impl(ctx, target_step, colour_enabled, thread_count)
        } else {
            return _single_thread_impl(ctx, target_step, colour_enabled)   
        }
    }
}

user_args :: proc() -> []string {
    return os.args[1:]
}

@private _traverse_steps :: proc(steps: []^Step, client_data: rawptr, p: #type proc(^Step, rawptr) -> ^Step) -> (res: ^Step) {
    stack := make([dynamic]^Step, 0, len(steps))
    defer delete(stack)

    for &s in steps do append(&stack, s)

    visited := make(map[^Step]bool)
    defer delete(visited)

    for len(stack) > 0 {
        step := stack[len(stack)-1]
        pop(&stack)

        if visited[step] {
            continue
        }
        visited[step] = true

        if step.children != nil {
            for &child in step.children {
                append(&stack, child)
            }
        }

        res = p(step, client_data)
        if res != nil do return res
    }

    return nil
}

/* Use the `Build_Context` to build the respective project.
*/
build :: proc(ctx: ^Build_Context, caller_location := #caller_location) -> (err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    context.logger = ctx.logger

    log.infof("[START] Building ...")
    defer if err != nil do log.errorf("[FAIL] Building.")

    _find_step_target :: proc(target: string, steps: []^Step) -> ^Step {
        target := target
        return _traverse_steps(
            steps, 
            &target, 
            proc(step: ^Step, client_data: rawptr) -> ^Step {   
                target_ptr := transmute(^string)client_data
                if step.name == target_ptr^ do return step
                return nil
            })
    }

    step_name := get_target_step_name(ctx)
    target_step := _find_step_target(step_name, ctx._internal.step_collection[:])
    if target_step != nil {
        run_step_tree(ctx, target_step)
        log.infof("[DONE] Building.")
    } else {
        log.errorf("[FAIL] Building. Could not find step %q.", step_name)
    }
    return nil
}

C_Import_Info :: struct {
    factory: Bindgen_Factory,
    path: string,
    output_directory: string,
    emit_options: Bindgen_Emit_Options,
    parser_options: C_Bindgen_Parser_Options,

}

/*
*/
c_import :: proc(
    ctx: ^Build_Context, 
    path: string, 
    emit_options := Bindgen_Emit_Options{},
    caller_location := #caller_location
) -> (info: ^C_Import_Info, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    info = new(C_Import_Info, ia.allocator(&ctx.intern_arena))    
    info.factory = bindgen.make_factory(ctx.allocator) or_return
    info.path = path
    info.emit_options = emit_options
    type_aliases := cbindgen.make_type_aliases(allocator=ia.allocator(&ctx.intern_arena)) or_return
    info.parser_options.keep_stdlib = true
    info.parser_options.type_aliases = type_aliases
    info.parser_options.discard_comments = false
    info.parser_options.extra_imports = make(map[string]string, ctx.allocator)
    info.parser_options.opaque_type_name = nil // Auto-generated
    info.output_directory = filepath.join({ ctx.c_export_path, info.emit_options.package_name }, ia.allocator(&ctx.intern_arena)) or_return
    return info, nil
}

/* Parses the information provided, and generates the respective bindings.  
   **NOTE:** This will destroy all core resources for the specific import, meaning it can no longer be used.
*/
c_import_info :: proc(ctx: ^Build_Context, info: ^C_Import_Info, caller_location := #caller_location) -> (err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    cbindgen.parse(&info.factory, info.path, info.parser_options)
    temp_sb := strings.builder_make() or_return
    export_content := bindgen.emit_factory(&info.factory, &temp_sb, info.emit_options)
    output_filename := filepath.base(info.path)
    output_filename = output_filename[:len(output_filename)-len(filepath.long_ext(output_filename))]
    output_filename = strings.concatenate({ output_filename, ".odin" }, ctx.allocator) or_return
    defer delete(output_filename)
    output_path := filepath.join({ info.output_directory, output_filename }, ctx.allocator) or_return
    defer delete(output_path)
    if !os2.exists(info.output_directory) {
        os2.make_directory_all(info.output_directory) or_return
    }
    os2.write_entire_file(output_path, export_content) or_return
    strings.builder_destroy(&temp_sb)
    bindgen.destroy_factory(&info.factory)
    delete(info.parser_options.extra_imports)
    return nil
}

@private _C_Bindgen_Info_Client_Data :: struct {
    info: ^C_Import_Info,
    ctx: ^Build_Context
}

c_import_info_to_step :: proc(ctx: ^Build_Context, info: ^C_Import_Info, caller_location := #caller_location) -> (step: ^Step, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    client_data := _C_Bindgen_Info_Client_Data{
        info=info,
        ctx=ctx
    }
    step = create_step(ctx) or_return
    step.client_data = ia.intern_value(&ctx.intern_arena, client_data) or_return
    step.procedure = proc(ctx: ^Build_Context, client_data: rawptr) -> (success: bool, err: Error) {
        ciicd := transmute(^_C_Bindgen_Info_Client_Data)client_data
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
    arch_specific_subprocess_to_subprocess,
    os_arch_specific_subprocess_to_subprocess
}
to_step :: proc{
    subprocess_to_step,
    odin_build_to_step,
    odin_run_to_step,
    make_to_step,
    os_specific_subprocess_to_step,
    arch_specific_subprocess_to_step,
    os_arch_specific_subprocess_to_step,
    c_import_info_to_step,
    file_create_to_step,
    mkdir_to_step,
    cmake_in_source_build_to_step,
    cmake_out_of_source_build_to_step
}

create_step_without_name :: proc(ctx: ^Build_Context, caller_location := #caller_location) -> (step: ^Step, err: Allocator_Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    step = new(Step, ia.allocator(&ctx.intern_arena)) or_return
    step^ = empty_step
    step.children = make([dynamic]^Step, ctx.allocator) or_return
    return step, nil
}
create_step_with_name :: proc(ctx: ^Build_Context, name: string, caller_location := #caller_location) -> (step: ^Step, err: Allocator_Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    step = create_step_without_name(ctx) or_return
    step.name = name
    return step, nil
}
create_step :: proc{create_step_with_name,create_step_without_name}

add_step :: proc(ctx: ^Build_Context, step: ^Step, caller_location := #caller_location) -> (err: Allocator_Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    append(&ctx._internal.step_collection, step) or_return
    return nil
}

emplace_step :: proc(ctx: ^Build_Context, name: string, caller_location := #caller_location) -> (step: ^Step, err: Allocator_Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    step = create_step_with_name(ctx, name) or_return
    add_step(ctx, step) or_return
    return step, nil
}

/*
Merges steps into a single step.  
*/
merge_steps :: proc(ctx: ^Build_Context, steps: ..^Step, caller_location := #caller_location) -> (step: ^Step, err: Allocator_Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    owned_steps := ia.clone_slice(&ctx.intern_arena, steps) or_return
    owned_steps_ptr := ia.clone_ptr(&ctx.intern_arena, &owned_steps) or_return

    step = create_step(ctx) or_return
    step.client_data = owned_steps_ptr
    step.procedure = proc(ctx: ^Build_Context, client_data: rawptr) -> (success: bool, err: Error) {
        context.logger = ctx.logger
        context.allocator = ctx.allocator

        steps := (transmute(^[]^Step)client_data)^
        for &step in steps {
            run_step_tree(ctx, step) or_return
        }

        return true, nil
    }
    return step, nil
}

add_child :: proc(parent: ^Step, children: ..^Step, caller_location := #caller_location) -> (err: Allocator_Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    append(&parent.children, ..children, loc=caller_location) or_return
    return nil
}

/*
Using the `fingerprint`, it will determine whether the step should run in the overall build. This is useful for incremental builds.  
*/
plan_step :: proc(ctx: ^Build_Context, fingerprint: Hasher, step: ^Step, caller_location := #caller_location) -> (out: ^Step, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    base_fingerprint_v := run_hasher(fingerprint)
    if cachefs.hash_exists(&ctx.cache_file_system, base_fingerprint_v) {
        path := cachefs.path_from_hash(&ctx.cache_file_system, base_fingerprint_v) or_return
        client_data := State_Hasher_Client_Data{ ctx=ctx, exclude=path }
        ctx.state_fingerprint.client_data = &client_data
        full_fingerprint_v := base_fingerprint_v ~ run_hasher(ctx.state_fingerprint)
        hex_hash_buf: [17]byte
        hex_hash := strconv.write_uint(hex_hash_buf[:], full_fingerprint_v, 16)
        orig_data := ta_os2_read_entire_file(path, context.allocator) or_return
        defer delete(orig_data)
        if strings.compare(hex_hash, transmute(string)orig_data) == 0 do return &empty_step, nil
        ta_os2_write_entire_file(path, hex_hash) or_return
        return step, nil
    } else {
        client_data := State_Hasher_Client_Data{ ctx=ctx, exclude=nil }
        ctx.state_fingerprint.client_data = &client_data
        full_fingerprint_v := base_fingerprint_v ~ run_hasher(ctx.state_fingerprint)
        path := cachefs.create_from_hash(&ctx.cache_file_system, base_fingerprint_v) or_return
        hex_hash_buf: [17]byte
        hex_hash := strconv.write_uint(hex_hash_buf[:], full_fingerprint_v, 16)
        ta_os2_write_entire_file(path, hex_hash) or_return
        return step, nil
    }
}

Fingerprint_Target :: union($T: typeid) { T, Hasher }

fingerprint :: proc(ctx: ^Build_Context, targets: ..Hasher, caller_location := #caller_location) -> (output: Hasher, err: Allocator_Error) #optional_allocator_error {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    context.logger = ctx.logger

    log.infof("[START] Creating fingerprint for targets.")
    failed := true
    defer if failed do log.errorf("[ERROR] Creating fingerprint for targets.")
    when VERBOSE do log.debug(targets)

    managed_targets := ia.clone_slice(&ctx.intern_arena, targets) or_return
    managed_targets_ptr := ia.clone_ptr(&ctx.intern_arena, &managed_targets) or_return

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

Patterns :: struct {
    include, exclude: []string
}

files_fingerprint :: proc(
    ctx: ^Build_Context, 
    targets: ..Fingerprint_Target(string), 
    dir_glob_patterns := Patterns{ include={"*"}, exclude={} }, 
    file_glob_patterns := Patterns{ include={}, exclude={} }, 
    caller_location := #caller_location
) -> (output: Hasher, err: Allocator_Error) #optional_allocator_error {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()
    
    context.logger = ctx.logger
    
    log.infof("[START] Creating fingerprint targets from file targets.")
    defer if err != nil do log.errorf("[FAIL] Creating fingerprint for file targets.")
    log.debug(targets)

    _single_thread_impl :: proc(
        ctx: ^Build_Context, 
        targets: []Fingerprint_Target(string),
        dir_glob_patterns: Patterns,
        file_glob_patterns: Patterns
    ) -> (output: Hasher, err: Allocator_Error) #optional_allocator_error {
        context.logger = ctx.logger
        context.allocator = ctx.allocator

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
                                for &pattern in dir_glob_patterns.include {
                                    glob_match, glob_match_err := filepath.match(pattern, match_target)
                                    if glob_match_err != nil do glob_match = false
                                    if glob_match {
                                        matched = true
                                        break
                                    }
                                }
                                if !matched && len(dir_glob_patterns.include) > 0 {
                                    log.debugf("Skipping %q ...", rel_path)
                                    os2.walker_skip_dir(&walker)
                                    continue
                                } else if len(dir_glob_patterns.exclude) > 0 {
                                    for &pattern in dir_glob_patterns.exclude {
                                        glob_match, glob_match_err := filepath.match(pattern, match_target)
                                        if glob_match_err != nil do glob_match = false
                                        if glob_match {
                                            matched = true
                                            break
                                        }
                                    }
                                    if matched {
                                        log.debugf("Skipping %q (excluded) ...", rel_path)
                                        os2.walker_skip_dir(&walker)
                                        continue
                                    }
                                }
                            } else if info.type == .Regular {
                                rel_path := info.fullpath
                                matched := false
                                match_target := filepath.base(rel_path)
                                for &pattern in file_glob_patterns.include {
                                    glob_match, glob_match_err := filepath.match(pattern, match_target)
                                    if glob_match_err != nil do glob_match = false
                                    if glob_match {
                                        matched = true
                                        break
                                    }
                                }
                                if !matched && len(file_glob_patterns.include) > 0 {
                                    log.debugf("Skipping %q ...", rel_path)
                                    continue
                                } else if len(file_glob_patterns.exclude) > 0 {
                                    for &pattern in file_glob_patterns.exclude {
                                        glob_match, glob_match_err := filepath.match(pattern, match_target)
                                        if glob_match_err != nil do glob_match = false
                                        if glob_match {
                                            matched = true
                                            break
                                        }
                                    }
                                    if matched {
                                        log.debugf("Skipping %q (excluded) ...", rel_path)
                                        continue
                                    }
                                }
                                managed_fullpath := ia.intern_string(&ctx.intern_arena, info.fullpath) or_return
                                managed_fullpath_ptr := ia.clone_ptr(&ctx.intern_arena, &managed_fullpath) or_return
                                append(&sanitized_targets, Hasher{
                                    procedure=proc(client_data: rawptr) -> u64 {
                                        path_ptr := transmute(^string)client_data
                                        path := path_ptr^
                                        if !os2.exists(path) do return empty_hasher_procedure(client_data)
                                        stat, stat_err := os2.stat(path, context.allocator)
                                        defer if stat_err == nil do os2.file_info_delete(stat, context.allocator)
                                        if stat_err != nil do return empty_hasher_procedure(client_data)
                                        mod_yr, mod_month, mod_day := time.date(stat.modification_time)
                                        mod_hr, mod_min, mod_sec := time.clock(stat.modification_time)
                                        return hash_algo.murmur64a(transmute([]byte)path) ~
                                            hash_algo.murmur64a(mem.any_to_bytes(mod_yr)) ~
                                            hash_algo.murmur64a(mem.any_to_bytes(mod_month)) ~
                                            hash_algo.murmur64a(mem.any_to_bytes(mod_day)) ~
                                            hash_algo.murmur64a(mem.any_to_bytes(mod_hr)) ~
                                            hash_algo.murmur64a(mem.any_to_bytes(mod_min)) ~
                                            hash_algo.murmur64a(mem.any_to_bytes(mod_sec))
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
                        for &pattern in file_glob_patterns.include {
                            glob_match, glob_match_err := filepath.match(pattern, match_target)
                            if glob_match_err != nil do glob_match = false
                            if glob_match {
                                matched = true
                                break
                            }
                        }
                        if !matched && len(file_glob_patterns.include) > 0 {
                            log.debugf("Skipping %q ...", rel_path)
                            continue
                        } else if len(file_glob_patterns.exclude) > 0 {
                            for &pattern in file_glob_patterns.exclude {
                                glob_match, glob_match_err := filepath.match(pattern, match_target)
                                if glob_match_err != nil do glob_match = false
                                if glob_match {
                                    matched = true
                                    break
                                }
                            }
                            if matched {
                                log.debugf("Skipping %q (excluded) ...", rel_path)
                                continue
                            }
                        }
                        managed_target := ia.intern_string(&ctx.intern_arena, target) or_return
                        managed_target_ptr := ia.clone_ptr(&ctx.intern_arena, &managed_target) or_return
                        append(&sanitized_targets, Hasher{
                            procedure=proc(client_data: rawptr) -> u64 {
                                path_ptr := transmute(^string)client_data
                                path := path_ptr^
                                if !os2.exists(path) do return empty_hasher_procedure(client_data)
                                stat, stat_err := os2.stat(path, context.allocator)
                                defer if stat_err == nil do os2.file_info_delete(stat, context.allocator)
                                if stat_err != nil do return empty_hasher_procedure(client_data)
                                mod_yr, mod_month, mod_day := time.date(stat.modification_time)
                                mod_hr, mod_min, mod_sec := time.clock(stat.modification_time)
                                return hash_algo.murmur64a(transmute([]byte)path) ~
                                    hash_algo.murmur64a(mem.any_to_bytes(mod_yr)) ~
                                    hash_algo.murmur64a(mem.any_to_bytes(mod_month)) ~
                                    hash_algo.murmur64a(mem.any_to_bytes(mod_day)) ~
                                    hash_algo.murmur64a(mem.any_to_bytes(mod_hr)) ~
                                    hash_algo.murmur64a(mem.any_to_bytes(mod_min)) ~
                                    hash_algo.murmur64a(mem.any_to_bytes(mod_sec))
                            },
                            client_data=managed_target_ptr
                        }) or_return
                    }
                case Hasher:
                    append(&sanitized_targets, target) or_return
            }
        }

        log.info("[DONE] Creating fingerprint targets from file targets.")
        when VERBOSE do log.debug(sanitized_targets[:])
        
        return fingerprint(ctx, ..sanitized_targets[:])
    }

    _multi_thread_impl :: proc(
        ctx: ^Build_Context, 
        targets: []Fingerprint_Target(string),
        dir_glob_patterns: Patterns,
        file_glob_patterns: Patterns,
        thread_count: int
    ) -> (output: Hasher, err: Allocator_Error) #optional_allocator_error {
        _Basic_Thread_Safe :: struct($U: typeid) {
            data: ^U,
            mutex: sync.Mutex
        }

        _Level_0_Task_Data :: struct {
            target: Fingerprint_Target(string),
            sanitized_targets: ^thread_safe_array.Thread_Safe_Dynamic_Array(Hasher),
            dir_glob_patterns: Patterns,
            file_glob_patterns: Patterns,
            ctx: ^_Basic_Thread_Safe(Build_Context)
        }
        _level_0_task : thread.Task_Proc : proc(task: thread.Task) {
            data := transmute(^_Level_0_Task_Data)task.data
            switch &target in data.target {
                case string:
                    if os2.is_dir(target) {
                        walker := os2.walker_create(target)
                        defer os2.walker_destroy(&walker)

                        for info in os2.walker_walk(&walker) {
                            _ = os2.walker_error(&walker) or_continue

                            #partial switch info.type {
                                case .Directory:
                                    rel_path := info.fullpath
                                    matched := false
                                    match_target := filepath.base(rel_path)
                                    for pattern in data.dir_glob_patterns.include {
                                        glob_match, glob_match_err := filepath.match(pattern, match_target)
                                        if glob_match_err != nil do glob_match = false
                                        if glob_match {
                                            matched = true
                                            break
                                        }
                                    }
                                    if !matched && len(data.dir_glob_patterns.include) > 0 {
                                        os2.walker_skip_dir(&walker)
                                        continue
                                    } else if len(data.dir_glob_patterns.exclude) > 0 {
                                        for pattern in data.dir_glob_patterns.exclude {
                                            glob_match, glob_match_err := filepath.match(pattern, match_target)
                                            if glob_match_err != nil do glob_match = false
                                            if glob_match {
                                                matched = true
                                                break
                                            }
                                        }
                                        if matched {
                                            os2.walker_skip_dir(&walker)
                                            continue
                                        }
                                    }
                                case .Regular:
                                    rel_path := info.fullpath
                                    matched := false
                                    match_target := filepath.base(rel_path)
                                    for pattern in data.file_glob_patterns.include {
                                        glob_match, glob_match_err := filepath.match(pattern, match_target)
                                        if glob_match_err != nil do glob_match = false
                                        if glob_match {
                                            matched = true
                                            break
                                        }
                                    }
                                    if !matched && len(data.file_glob_patterns.include) > 0 {
                                        continue
                                    } else if len(data.file_glob_patterns.exclude) > 0 {
                                        for pattern in data.file_glob_patterns.exclude {
                                            glob_match, glob_match_err := filepath.match(pattern, match_target)
                                            if glob_match_err != nil do glob_match = false
                                            if glob_match {
                                                matched = true
                                                break
                                            }
                                        }
                                        if matched {
                                            continue
                                        }
                                    }
                                    sync.mutex_lock(&data.ctx.mutex)
                                    managed_target := ia.intern_string(&data.ctx.data.intern_arena, info.fullpath)
                                    managed_target_ptr := ia.clone_ptr(&data.ctx.data.intern_arena, &managed_target)
                                    sync.mutex_unlock(&data.ctx.mutex)
                                    thread_safe_array.read_write_lock(data.sanitized_targets)
                                    append(data.sanitized_targets.buffer, Hasher{
                                        procedure=proc(client_data: rawptr) -> u64 {
                                            path_ptr := transmute(^string)client_data
                                            path := path_ptr^
                                            if !os2.exists(path) do return empty_hasher_procedure(client_data)
                                            stat, stat_err := os2.stat(path, context.allocator)
                                            defer if stat_err == nil do os2.file_info_delete(stat, context.allocator)
                                            if stat_err != nil do return empty_hasher_procedure(client_data)
                                            mod_yr, mod_month, mod_day := time.date(stat.modification_time)
                                            mod_hr, mod_min, mod_sec := time.clock(stat.modification_time)
                                            return hash_algo.murmur64a(transmute([]byte)path) ~
                                                hash_algo.murmur64a(mem.any_to_bytes(mod_yr)) ~
                                                hash_algo.murmur64a(mem.any_to_bytes(mod_month)) ~
                                                hash_algo.murmur64a(mem.any_to_bytes(mod_day)) ~
                                                hash_algo.murmur64a(mem.any_to_bytes(mod_hr)) ~
                                                hash_algo.murmur64a(mem.any_to_bytes(mod_min)) ~
                                                hash_algo.murmur64a(mem.any_to_bytes(mod_sec))
                                        },
                                        client_data=managed_target_ptr
                                    })
                                    thread_safe_array.read_write_unlock(data.sanitized_targets)
                            }
                        }
                    } else {
                        rel_path := target
                        matched := false
                        match_target := filepath.base(rel_path)
                        for pattern in data.file_glob_patterns.include {
                            glob_match, glob_match_err := filepath.match(pattern, match_target)
                            if glob_match_err != nil do glob_match = false
                            if glob_match {
                                matched = true
                                break
                            }
                        }
                        if !matched && len(data.file_glob_patterns.include) > 0 {
                            return
                        } else if len(data.file_glob_patterns.exclude) > 0 {
                            for &pattern in data.file_glob_patterns.exclude {
                                glob_match, glob_match_err := filepath.match(pattern, match_target)
                                if glob_match_err != nil do glob_match = false
                                if glob_match {
                                    matched = true
                                    break
                                }
                            }
                            if matched {
                                return
                            }
                        }
                        sync.mutex_lock(&data.ctx.mutex)
                        managed_target := ia.intern_string(&data.ctx.data.intern_arena, target)
                        managed_target_ptr := ia.clone_ptr(&data.ctx.data.intern_arena, &managed_target)
                        sync.mutex_unlock(&data.ctx.mutex)
                        thread_safe_array.read_write_lock(data.sanitized_targets)
                        append(data.sanitized_targets.buffer, Hasher{
                            procedure=proc(client_data: rawptr) -> u64 {
                                path_ptr := transmute(^string)client_data
                                path := path_ptr^
                                if !os2.exists(path) do return empty_hasher_procedure(client_data)
                                stat, stat_err := os2.stat(path, context.allocator)
                                defer if stat_err == nil do os2.file_info_delete(stat, context.allocator)
                                if stat_err != nil do return empty_hasher_procedure(client_data)
                                mod_yr, mod_month, mod_day := time.date(stat.modification_time)
                                mod_hr, mod_min, mod_sec := time.clock(stat.modification_time)
                                return hash_algo.murmur64a(transmute([]byte)path) ~
                                    hash_algo.murmur64a(mem.any_to_bytes(mod_yr)) ~
                                    hash_algo.murmur64a(mem.any_to_bytes(mod_month)) ~
                                    hash_algo.murmur64a(mem.any_to_bytes(mod_day)) ~
                                    hash_algo.murmur64a(mem.any_to_bytes(mod_hr)) ~
                                    hash_algo.murmur64a(mem.any_to_bytes(mod_min)) ~
                                    hash_algo.murmur64a(mem.any_to_bytes(mod_sec))
                            },
                            client_data=managed_target_ptr
                        })
                        thread_safe_array.read_write_unlock(data.sanitized_targets)
                    }
                case Hasher:
                    thread_safe_array.read_write_lock(data.sanitized_targets)
                    append(data.sanitized_targets.buffer, target)
                    thread_safe_array.read_write_unlock(data.sanitized_targets)
            }
        }

        context.logger = ctx.logger
        context.allocator = ctx.allocator

        task_data := make([]_Level_0_Task_Data, len(targets))
        defer delete(task_data)

        tsa: thread_safe_allocator.Thread_Safe_Allocator
        thread_safe_allocator.init(&tsa, context.allocator)
        context.allocator = tsa

        // Made under a thread safe allocator, meaning all associated allocations should be thread safe.
        sanitized_targets := make([dynamic]Hasher, 0, len(targets)) or_return
        defer delete(sanitized_targets)

        // Thread safe regarding allocations and access to the overall array.
        ts_santized_targets: thread_safe_array.Thread_Safe_Dynamic_Array(Hasher)
        thread_safe_array.init_dyn_arr(&ts_santized_targets, &sanitized_targets)

        ts_build_ctx := _Basic_Thread_Safe(Build_Context) {
            data=ctx
        }

        pool: thread.Pool
        thread.pool_init(&pool, context.allocator, thread_count)

        for &target, i in targets {
            task_data[i].target = target
            task_data[i].ctx = &ts_build_ctx
            task_data[i].dir_glob_patterns = dir_glob_patterns
            task_data[i].file_glob_patterns = file_glob_patterns
            task_data[i].sanitized_targets = &ts_santized_targets
            thread.pool_add_task(&pool, context.allocator, _level_0_task, &task_data[i], user_index=i)
        }

        thread.pool_start(&pool)
        thread.pool_finish(&pool)
        thread.pool_shutdown(&pool)
        thread.pool_destroy(&pool)

        context.allocator = thread_safe_allocator.original(&tsa)

        return fingerprint(ctx, ..sanitized_targets[:])
    }

    when !thread.IS_SUPPORTED {
        return _single_thread_impl(ctx, targets, dir_glob_patterns, file_glob_patterns)
    } else {
        thread_count := get_thread_count(ctx)
        if thread_count > 1 { // TODO(rysah): Perhaps provide more conditions to help optimize usage.
            return _multi_thread_impl(ctx, targets, dir_glob_patterns, file_glob_patterns, thread_count)
        } else {
            return _single_thread_impl(ctx, targets, dir_glob_patterns, file_glob_patterns)   
        }
    }
}
