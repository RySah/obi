package subprocess

import "core:os"
import "core:os/os2"
import "core:path/filepath"
import "core:strings"
import "core:io"
import "core:fmt"
import "core:terminal"

OS2_Process_Desc :: os2.Process_Desc
OS2_Error :: os2.Error

Error :: OS2_Error
State :: os2.Process_State
File :: os2.File

stdout :: #force_inline proc() -> ^File { return os2.stdout }
stderr :: #force_inline proc() -> ^File { return os2.stderr }

current_working_directory :: os2.get_working_directory
environ :: os2.environ

as_unsafe_os_handle :: #force_inline proc(f: ^File) -> os.Handle {
    return os.Handle(os2.fd(f))
}

is_terminal :: #force_inline proc(f: ^File) -> bool {
    return terminal.is_terminal(as_unsafe_os_handle(f))
}

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
    stdin: ^File,
    // The `stdout` handle to write to. It can either be a file 
    // or a readable end of a pipe. Passing a `nil` will shut down the process'
    // output.
    stdout: ^File,
    // The `stderr` handle to write to. It can either be a file 
    // or a readable end of a pipe. Passing a `nil` will shut down the process'
    // error output.
    stderr: ^File,
    // Run the command in the repsective shell for the platform
    shell: bool
}



run :: proc(cmd: Command, allocator := context.allocator) -> (state: State, stdout: []byte, stderr: []byte, err: Error) {
    context.allocator = allocator
    pdesc: OS2_Process_Desc = ---
    pdesc.working_dir = cmd.working_dir
    if cmd.shell {
        pdesc.command = make([]string, len(cmd.command)+2) or_return
        for &token, i in cmd.command do pdesc.command[i+2] = token
        when ODIN_OS == .Windows {
            pdesc.command[0] = "cmd.exe"
            pdesc.command[1] = "/c"
        } else {
            pdesc.command[0] = "/bin/sh"
            pdesc.command[1] = "-c"
        }
    } else {
        pdesc.command = cmd.command
    }
    defer if cmd.shell do delete(pdesc.command)
    free_env := false
    if e, ok := cmd.env.?; ok {
        free_env = false
        pdesc.env = e
    } else {
        free_env = true
        pdesc.env = environ(context.allocator) or_return
    }
    defer if free_env {
        for &e in pdesc.env do delete(e)
        delete(pdesc.env)
    }
    pdesc.stdin = cmd.stdin
    pdesc.stdout = cmd.stdout
    pdesc.stderr = cmd.stderr
    if pdesc.stdout == nil && pdesc.stderr == nil { // Has the conditions to be ran simply by os2.process_exec
        state, stdout, stderr = os2.process_exec(pdesc, context.allocator) or_return
        return state, stdout, stderr, nil
    } else { // Extends "pipes" to write to 2 ends. (The user and the capture)
        user_stdout_w, user_stderr_w: io.Writer = ---, ---
        user_stdout_w = os2.to_writer(pdesc.stdout)
        user_stderr_w = os2.to_writer(pdesc.stderr)
        defer os2.flush(pdesc.stdout)
        defer os2.flush(pdesc.stderr)

        stdout_r, stdout_w := os2.pipe() or_return
	    defer os2.close(stdout_r)
	    stderr_r, stderr_w := os2.pipe() or_return
	    defer os2.close(stderr_r)

	    process: os2.Process
	    {
	    	defer os2.close(stdout_w)
	    	defer os2.close(stderr_w)
	    	desc := pdesc
	    	desc.stdout = stdout_w
	    	desc.stderr = stderr_w
	    	process = os2.process_start(desc) or_return
	    }

	    {
	    	stdout_b: [dynamic]byte
	    	stdout_b.allocator = allocator

	    	stderr_b: [dynamic]byte
	    	stderr_b.allocator = allocator

	    	buf: [1024]u8 = ---
        
	    	stdout_done, stderr_done, has_data: bool
	    	for err == nil && (!stdout_done || !stderr_done) {
	    		n := 0

	    		if !stdout_done {
	    			has_data, err = os2.pipe_has_data(stdout_r)
	    			if has_data {
	    				n, err = os2.read(stdout_r, buf[:])
	    			}

	    			switch err {
	    			case nil:
	    				_, err = append(&stdout_b, ..buf[:n])
                        fmt.wprint(user_stdout_w, transmute(string)buf[:n], sep="")
	    			case .EOF, .Broken_Pipe:
	    				stdout_done = true
	    				err = nil
	    			}
	    		}

	    		if err == nil && !stderr_done {
	    			n = 0
	    			has_data, err = os2.pipe_has_data(stderr_r)
	    			if has_data {
	    				n, err = os2.read(stderr_r, buf[:])
	    			}

	    			switch err {
	    			case nil:
	    				_, err = append(&stderr_b, ..buf[:n])
                        fmt.wprint(user_stderr_w, transmute(string)buf[:n], sep="")
	    			case .EOF, .Broken_Pipe:
	    				stderr_done = true
	    				err = nil
	    			}
	    		}
	    	}

	    	stdout = stdout_b[:]
	    	stderr = stderr_b[:]
	    }

	    if err != nil {
	    	state, _ = os2.process_wait(process, timeout=0)
	    	if !state.exited {
	    		_ = os2.process_kill(process)
	    		state, _ = os2.process_wait(process)
	    	}
	    	return
	    }

	    state, err = os2.process_wait(process)
	    return state, stdout, stderr, nil
    }
}

// Cross platform method to ensure you can find or ensure the existence of a program.  
// **NOTE**: The local search, after the global, will only search the `cwd` and will NOT walk subdirectories for safety.
which :: proc(name: string, allocator := context.allocator, cwd := "",  search_local := false) -> (path: string, found: bool, err: Error) {
    cwd := cwd
    
    cmd := Command{
        working_dir=cwd,
        command={"where" when ODIN_OS == .Windows else "which", name},
        env=nil,
        stdin=nil
    }
    state, stdout, stderr := run(cmd, allocator) or_return
    defer delete(stderr)
    //defer delete(stdout)

    path = transmute(string)stdout
    for len(path) > 0 {
        last := path[len(path)-1]
        if last == '\n' || last == '\r' {
            path = path[0:len(path)-1]
        } else {
            break
        }
    }
    
    found = (state.exit_code == 0 when ODIN_OS == .Windows else state.success) && os2.exists(path)

    if !found && search_local {
        if len(cwd) == 0 do cwd = "."

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
    context.allocator = allocator
    path: string
    path, found = which(name, context.allocator, cwd=cwd, search_local=search_local) or_return
    defer delete(path)
    return found, nil
}
