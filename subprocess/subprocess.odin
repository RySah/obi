package subprocess

import "core:os/os2"
import "core:path/filepath"
import "core:strings"

OS2_Process_Desc :: os2.Process_Desc
OS2_Error :: os2.Error

Error :: OS2_Error
State :: os2.Process_State
File :: os2.File

current_working_directory :: os2.get_working_directory
environ :: os2.environ

Command :: struct {
    // The working directory of the process. If the string has length 0, the
    // working directory is assumed to be the current working directory of the
    // current process.
    working_dir: string,
    // The command to run. Each element of the slice is a separate argument to
    // the process. The first element of the slice would be the executable.
    command: []string,
    // A slice of strings, each having the format `KEY=VALUE` representing the
    // full environment that the child process will receive.
    // In case this slice is `nil`, the current process' environment is used.
    // `nil` == current env, empty == empty/no env.
    env: Maybe([]string),
    // The `stdin` handle to give to the child process. It can either be a file
	// or a readable end of a pipe. Passing a `nil` will shut down the process'
	// input.
    stdin: ^File
}


run :: proc(cmd: Command, allocator := context.allocator) -> (state: State, stdout: []byte, stderr: []byte, err: Error) {
    context.allocator = allocator
    pdesc: OS2_Process_Desc = ---
    pdesc.working_dir = cmd.working_dir
    pdesc.command = cmd.command
    free_env := false
    if e, ok := cmd.env.?; ok {
        free_env = false
        pdesc.env = e
    } else {
        free_env = true
        pdesc.env = environ(context.allocator) or_return
    }
    defer if free_env do delete(pdesc.env)
    pdesc.stdin = cmd.stdin
    pdesc.stdout = nil
    pdesc.stderr = nil
    state, stdout, stderr = os2.process_exec(pdesc, context.allocator) or_return
    return state, stdout, stderr, nil
}

// **UTIL**: Cross platform method to ensure you can find or ensure the existence of a program.  
// **NOTE**: The local search, after the global, will only search the `cwd` and will NOT walk subdirectories for safety.
which :: proc(name: string, allocator := context.allocator, cwd := "",  search_local := false) -> (path: string, found: bool, err: Error) {
    cmd := Command{
        working_dir=cwd,
        command={"where" when ODIN_OS == .Windows else "which", name},
        env=nil,
        stdin=nil
    }
    state, stdout, stderr := run(cmd, allocator) or_return
    defer delete(stderr)

    path = transmute(string)stdout
    found = (state.exit_code == 0 when ODIN_OS == .Windows else state.success) && len(path) > 0

    if !found && search_local {
        f := os2.open(cwd) or_return
	    defer os2.close(f)

        it := os2.read_directory_iterator_create(f)
        defer os2.read_directory_iterator_destroy(&it)

        for info in os2.read_directory_iterator(&it) {
            _ = os2.read_directory_iterator_error(&it) or_return

            when ODIN_OS == .Windows {
                ext := filepath.ext(info.fullpath)
                if strings.compare(ext, ".exe") == 0 || strings.compare(ext, ".cmd") == 0 || strings.compare(ext, ".bat") == 0 {
                    base := filepath.base(info.fullpath)
                    found = strings.compare(base[:len(base)-len(ext)], name) == 0
                    if found do path = strings.clone(info.fullpath, allocator) or_return
                }
            } else {
                found = strings.compare(filepath.base(info.fullpath), name) == 0
                if found do path = strings.clone(info.fullpath, allocator) or_return
            }

            if found do return path, found, nil
        }
    }

    return path, found, nil
}

// **UTIL**: Cross platform method to ensure you can find or ensure the existence of a program.  
// **NOTE**: The local search, after the global, will only search the `cwd` and will NOT walk subdirectories for safety.
which_b :: proc(name: string, allocator := context.allocator, cwd := "", search_local := false) -> (found: bool, err: Error) {
    path: string
    path, found = which(name, allocator, cwd=cwd, search_local=search_local) or_return
    defer delete(path)
    return found, nil
}
