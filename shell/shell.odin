package shell

import "core:os/os2"

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
    state, stdout, stderr = os2.process_exec(pdesc, context.allocator) or_return
    return state, stdout, stderr, nil
}
