// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ryan Mensah

/*
Package obi — trace_aliases.odin

This file defines wrapper code over procedures that doesnt fit the `obi` standard model for tracing errors.

Any procedure here should be used alongside `or_return`, otherwise use the original implemenetation.

IMPLMENTATION TIPS:
- Procedures that soley return `Allocator_Error` should not be implemented here, as the tracking allocator or performance tracker, can easily identify allocator errors.
- To succesfully integrate a procedure into this model it should be modeled as such:
```
foo :: proc(..., caller_location := #caller_location) -> (..., err: Error) {
    _start_trace() // Global build context creates a new state
    _trace(caller_location) // Adds this location to the new state
    defer if err == nil do _backtrace() // In the case no error has occured, the new state will be discared in favor of the old

    return bar(...) // Backing procedure to run
} 
```
- To enforce UX, prefix all procedures with `ta_`.
*/

#+private
package obi

import "core:os/os2"
import subprocess "subprocess"

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

