#+private
package obi

import "core:os/os2"
import subprocess "subprocess"

/*
This file is purposed to write wrapper code over procedures that can return errors (everything that can implicitly cast to `Error`) and we cannot necessarily edit.
Each procedure here must implement this trace "template".

Things to target:
- Anything file related that can return an error
- Anything and everything OS2/OS that returns an error
- Anything that returns errors that are far to opaque and requires more context by its location

Any function here should be used alongside `or_return` otherwise use the original implementation.

NOTE: Things that solely return `Allocator_Error` should be ignored, as a tracking allocator can track that.

```
foo :: proc(..., caller_location := #caller_location) -> (..., err: Error) {
    _start_trace()
    _trace(caller_location)
    defer if err == nil do _backtrace()
}
```
To help identify errors further.

Alias each of these procedures with `ta_`

Name formatting e.g. `strings.concatenate` -> `ta_strings_concatenate`
*/


ta_os2_get_working_directory :: #force_inline proc(allocator: Allocator, caller_location := #caller_location) -> (dir: string, err: os2.Error) {
    _start_trace()
    _trace(caller_location)
    defer if err == nil do _backtrace()
    return os2.get_working_directory(allocator)
}

ta_os2_read_entire_file_from_path :: #force_inline proc(name: string, allocator: Allocator, caller_location := #caller_location) -> (data: []byte, err: Error) {
    _start_trace()
    _trace(caller_location)
    defer if err == nil do _backtrace()
    return os2.read_entire_file_from_path(name, allocator, caller_location)
}
ta_os2_read_entire_file_from_file :: #force_inline proc(f: ^os2.File, allocator: Allocator, caller_location := #caller_location) -> (data: []byte, err: Error) {
    _start_trace()
    _trace(caller_location)
    defer if err == nil do _backtrace()
    return os2.read_entire_file_from_file(f, allocator, caller_location)
}
ta_os2_read_entire_file :: proc{ta_os2_read_entire_file_from_path,ta_os2_read_entire_file_from_file}

ta_os2_write_entire_file_from_bytes :: proc(name: string, data: []byte, perm := os2.Permissions_Read_All + {.Write_User}, truncate := true, caller_location := #caller_location) -> (err: os2.Error) {
    _start_trace()
    _trace(caller_location)
    defer if err == nil do _backtrace()
    return os2.write_entire_file_from_bytes(name, data, perm, truncate)
}
ta_os2_write_entire_file_from_string :: proc(name: string, data: string, perm := os2.Permissions_Read_All + {.Write_User}, truncate := true, caller_location := #caller_location) -> (err: os2.Error) {
    _start_trace()
    _trace(caller_location)
    defer if err == nil do _backtrace()
    return os2.write_entire_file_from_string(name, data, perm, truncate) 
}
ta_os2_write_entire_file :: proc{ta_os2_write_entire_file_from_bytes,ta_os2_write_entire_file_from_string}

ta_os2_make_directory_all :: proc(path: string, perm: int = 0o755, caller_location := #caller_location) -> (err: os2.Error) {
    _start_trace()
    _trace(caller_location)
    defer if err == nil do _backtrace()
    return os2.make_directory_all(path, perm)
}

ta_os2_make_directory :: proc(path: string, perm: int = 0o755, caller_location := #caller_location) -> (err: os2.Error) {
    _start_trace()
    _trace(caller_location)
    defer if err == nil do _backtrace()
    return os2.make_directory(path, perm)
}

ta_subprocess_which :: proc(name: string, allocator := context.allocator, cwd := "", search_local := false, caller_location := #caller_location) -> (path: string, found: bool, err: subprocess.Error) {
    _start_trace()
    _trace(caller_location)
    defer if err == nil do _backtrace()
    return subprocess.which(name, allocator, cwd, search_local)
}

