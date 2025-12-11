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

import shell "shell"
Shell_Error :: shell.Error
Shell_Command :: shell.Command

Error :: union #shared_nil {
    C_Import_Error,
    Cache_File_System_Error,
    Shell_Error,
    Allocator_Error
}

DEFAULT_CACHE_FILE_SYSTEM_PATH :: ".obi-cache"
DEFAULT_C_IMPORT_OUTPUT_PATH :: "c_api"

Step :: struct {
    procedure: #type proc(ctx: ^Build_Context, client_data: rawptr) -> (success: bool, err: Error),
    client_data: rawptr,
    required_success: bool
}

Build_Context_Owned_Resources :: struct {
    s: [dynamic]string,
    sarr: [dynamic][]string,
    shell_command: [dynamic]^Shell_Command
}

Build_Context :: struct {
    // Context allocator
    allocator: Allocator,
    // Collection of resources owned by `allocator`, by which will be freed on deconstruction
    owned_resources: Build_Context_Owned_Resources,
    // The cache file system.
    cache_file_system: Cache_File_System,
    // Collection of contextual `C_Import_Info` objects, by which is freed on deconstruction.
    c_import_infos: [dynamic]^C_Import_Info,
    // Default parent directory for `C_Import_Info` objects.  
    // **NOTE:** You are not forced to use this for `C_Import_Info` objects, simply change `C_Import_Info.output_folder` to customize it for that specific object.
    c_import_output_path: string,
    // Collection of steps to run before anything is built.  
    pre_build_steps: [dynamic]Step,
    // Collection of steps to run after everything is built.  
    post_build_steps: [dynamic]Step,
    // Output handle for all respective printing procedures.    
    // **NOTE:** Set to the system stdout (`os.stdout`) by default.
    stdout: os.Handle, 
    // Error output handle for all respective printing procedures.    
    // **NOTE:** Set to the system stderr (`os.stderr`) by default.
    stderr: os.Handle
}

@(private="file")
_own_string :: proc(ctx: ^Build_Context, data: string, clone := false) -> (value: string, err: Allocator_Error) {
    value = clone ? strings.clone(data, ctx.allocator) or_return : data
    append(&ctx.owned_resources.s, value) or_return
    return value, nil
}
@(private="file")
_own_string_array :: proc(ctx: ^Build_Context, data: []string, clone_slice := false, clone_strings := false) -> (value: []string, err: Allocator_Error) {
    value = clone_slice ? slice.clone(data, ctx.allocator) or_return : data
    for &s, i in data do value[i] = _own_string(ctx, s, clone=clone_strings) or_return
    return value, nil
}
@(private="file")
_own_shell_command :: proc(ctx: ^Build_Context, cmd: ^Shell_Command, clone_slice := false, clone_strings := false) -> (value: ^Shell_Command, err: Allocator_Error) {
    value = new(Shell_Command, ctx.allocator) or_return
    append(&ctx.owned_resources.shell_command, value) or_return
    value.working_dir = _own(ctx, cmd.working_dir, clone=clone_strings) or_return
    value.command = _own(ctx, cmd.command, clone_slice=clone_slice, clone_strings=clone_strings) or_return
    if env, ok := cmd.env.?; ok {
        value.env = _own(ctx, env, clone_slice=clone_slice, clone_strings=clone_strings) or_return
    }
    return value, nil
}
@(private="file")
_own :: proc{_own_string, _own_string_array, _own_shell_command}

@(private="file")
_init_build_context_owned_resources :: proc(r: ^Build_Context_Owned_Resources, allocator: Allocator) -> Allocator_Error {
    r.s = make([dynamic]string, allocator) or_return
    r.sarr = make([dynamic][]string, allocator) or_return
    r.shell_command = make([dynamic]^Shell_Command, allocator) or_return
    return nil
}

@(private="file")
_destroy_build_context_owned_resources :: proc(r: ^Build_Context_Owned_Resources, allocator: Allocator) -> Allocator_Error {
    for &s in r.sarr do delete(s, allocator) or_return
    delete(r.sarr) or_return

    for &s in r.s do delete(s, allocator) or_return
    delete(r.s) or_return

    for &p in r.shell_command do free(p, allocator) or_return
    delete(r.shell_command) or_return

    return nil
}
 
/* Creates a `Build_Context`, essential for any builds.
*/
create_build_context :: proc(
    allocator: Allocator, 
    cache_file_system_path := DEFAULT_CACHE_FILE_SYSTEM_PATH, 
    c_import_output_path := DEFAULT_C_IMPORT_OUTPUT_PATH
) -> (ctx: Build_Context, err: Error) {
    ctx.allocator = allocator
    _init_build_context_owned_resources(&ctx.owned_resources, ctx.allocator) or_return
    ctx.cache_file_system = cachefs.from(cache_file_system_path, ctx.allocator) or_return
    ctx.c_import_infos = make([dynamic]^C_Import_Info, ctx.allocator) or_return
    ctx.c_import_output_path = c_import_output_path
    ctx.pre_build_steps = make([dynamic]Step, ctx.allocator) or_return
    ctx.post_build_steps = make([dynamic]Step, ctx.allocator) or_return
    ctx.stdout = os.stdout
    ctx.stderr = os.stderr
    return ctx, nil
}

/* Destroy the contents of an `Build_Context` object, essential for memory safety.
*/
destroy_build_context :: proc(ctx: ^Build_Context) -> Error {
    _destroy_build_context_owned_resources(&ctx.owned_resources, ctx.allocator) or_return

    cachefs.destroy(&ctx.cache_file_system) or_return
    
    for &p in ctx.c_import_infos {
        if p == nil do continue
        ci.destroy_import_info(p) or_return
        free(p, ctx.allocator) or_return
    }
    delete(ctx.c_import_infos) or_return

    delete(ctx.pre_build_steps) or_return
    delete(ctx.post_build_steps) or_return
    
    return nil
}

run_step :: proc(ctx: ^Build_Context, step: Step) -> (success: bool, err: Error) {
    success = step.procedure(ctx, step.client_data) or_return
    return success, nil
}

/* NOTE: This uses `shell.run` internally, but omits functionality on what it returns.
         If your goal is to capture the output of the shell command and other metadata, instead use `shell.run`.

   To force disable coloured output, set `terminal.color_enabled` to false.   
   To force enable coloured output, set `terminal.color_enabled` to true.
*/
run_shell_command :: proc(ctx: ^Build_Context, cmd: ^Shell_Command) -> (success: bool, err: Error) {
    stdout_color_enabled := terminal.is_terminal(ctx.stdout) && terminal.color_enabled
    stderr_color_enabled := terminal.is_terminal(ctx.stderr) && terminal.color_enabled

    state, stdout, stderr := shell.run(cmd^, ctx.allocator) or_return
    defer delete(stdout, ctx.allocator)
    defer delete(stderr, ctx.allocator)

    fmt.fprint(ctx.stdout, "CMD: ", sep="")
    for &token, i in cmd.command {
        fmt.fprint(ctx.stdout, token, i + 1 < len(cmd.command) ? " " : "", sep="", flush=false)
    }
    fmt.fprintln(ctx.stdout)

    fmt.fprintln(ctx.stdout, 
        stdout_color_enabled ? ansi.CSI + ansi.BOLD + ansi.SGR : "", 
        "OUT:", 
        stdout_color_enabled ? ansi.CSI + ansi.RESET + ansi.SGR : "",
        "\n",
        transmute(string)stdout,
        sep=""
    )
    fmt.fprintln(ctx.stderr, 
        stderr_color_enabled ? ansi.CSI + ansi.FG_RED + ";" + ansi.BOLD + ansi.SGR : "", 
        "ERR:", 
        stderr_color_enabled ? ansi.CSI + ansi.RESET + ansi.SGR : "",
        "\n",
        transmute(string)stderr,
        sep=""
    )
    success = state.success when ODIN_OS != .Windows else state.exit_code == 0
    fmt.fprintln(ctx.stdout,
        "\n",
        "Program exited with code ",
        stdout_color_enabled ? (success ? ansi.CSI + ansi.FG_BRIGHT_GREEN + ansi.SGR : ansi.CSI + ansi.FG_BRIGHT_RED + ansi.SGR) : "",
        state.exit_code,
        stderr_color_enabled ? ansi.CSI + ansi.RESET + ansi.SGR : "",
        sep=""
    )
    fmt.fprintln(ctx.stdout, "Time elapsed:")

    system_time_ms := time.duration_milliseconds(state.system_time)
    system_time_ns := time.duration_nanoseconds(state.system_time)
    user_time_ms := time.duration_milliseconds(state.user_time)
    user_time_ns := time.duration_nanoseconds(state.user_time)
    system_time_ms_len, user_time_ms_len := 0, 0
    {
        temp_sb := strings.builder_make(ctx.allocator) or_return
        defer strings.builder_destroy(&temp_sb)
        
        system_time_ms_len  = len(fmt.sbprint(&temp_sb, system_time_ms, sep=""))
        strings.builder_reset(&temp_sb)

        user_time_ms_len  = len(fmt.sbprint(&temp_sb, user_time_ms, sep=""))        
    }
    max_ms_len := max(system_time_ms_len, user_time_ms_len)

    fmt.fprintfln(ctx.stdout, "  System time: %dms%*s%dns", system_time_ms, (max_ms_len-system_time_ms_len)+1, "", system_time_ns)
    fmt.fprintfln(ctx.stdout, "  User time:   %dms%*s%dns", user_time_ms, (max_ms_len-user_time_ms_len)+1, "", user_time_ns)
    

    return success, nil
}

// Clones `cmd` and converts it to a step.
shell_command_to_step :: proc(ctx: ^Build_Context, cmd: ^Shell_Command) -> (step: Step, err: Allocator_Error) {
    owned_cmd := _own(ctx, cmd, clone_slice=true, clone_strings=true) or_return
    step.client_data = owned_cmd
    step.procedure = proc(ctx: ^Build_Context, client_data: rawptr) -> (success: bool, err: Error) {
        cmd := transmute(^Shell_Command)client_data
        return run_shell_command(ctx, cmd)
    }
    return step, err
}

/* Use the `Build_Context` to build the respective project.
*/
build :: proc(ctx: ^Build_Context) -> (err: Error) {
    for &c in ctx.pre_build_steps {
        if success := run_step(ctx, c) or_return; !success && c.required_success {
            break // No more steps will be ran
        }
        fmt.fprintln(ctx.stdout)
    }

    for &info in ctx.c_import_infos {
        c_import_info(ctx, info) or_return
    }

    for &c in ctx.post_build_steps {
        if success := run_step(ctx, c) or_return; !success && c.required_success {
            break // No more steps will be ran
        }
        fmt.fprintln(ctx.stdout)
    }
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
    info = ci.make_import_info(&ctx.cache_file_system, ctx.allocator) or_return
    info.package_name = package_name
    info.output_folder = filepath.join({ ctx.c_import_output_path, info.package_name }, ctx.allocator) or_return
    info.output_folder = _own(ctx, info.output_folder, clone=false) or_return
    append(&ctx.c_import_infos, info) or_return
    c_include(info, ..include_paths) or_return
    return info, nil
}

/* Parses the information provided, and generates the respective bindings.  
   **NOTE:** Try to avoid using it on info provided from `c_import`, everything would work as intended, however this process would 
   uneccessarily be ran twice.
*/
c_import_info :: proc(ctx: ^Build_Context, info: ^C_Import_Info) -> (err: Error) {
    ci.import_info(info, ctx.allocator) or_return
    return nil
}