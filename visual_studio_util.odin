// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ryan Mensah

/*
Package obi — visual_studio_util.odin

This file defines wrapper code over the `visual_studio` package,
binding them to the build system's `Build_Context` allocation model.

This file intentionally contains no platform independent logic and exists solely
as a build system integration layer.
*/

package obi

import vs "visual_studio"
import gc "garbage_collector"

VS_Error :: vs.Error
VS_General_Error :: vs.General_Error
VS_Release_Version :: vs.Release_Version
VS_Release_Info :: vs.Release_Info
VS_Release_Compare_Options :: vs.Release_Compare_Options
VS_Releases :: vs.Releases

/*
**Description**:
- Alias for `visual_studio.is_better_version`.
- Compares two `VS_Release_Version` values.

**Params**:
- `a: VS_Release_Version` — Left-hand version operand.
- `b: VS_Release_Version` — Right-hand version operand.

**Returns**:
- `true` if `a` represents a better version than `b`.
*/
vs_is_better_version :: vs.is_better_version

/*
**Description**:
- Alias for `visual_studio.is_better_release`.
- Compares two `VS_Release_Info` values using comparison options.

**Params**:
- `a: VS_Release_Info` — Left-hand release operand.
- `b: VS_Release_Info` — Right-hand release operand.
- `compare_opts: VS_Release_Compare_Options` — Options controlling the comparison semantics.

**Returns**:
- `true` if `a` represents a better release than `b` under `compare_opts`.
*/
vs_is_better_release :: vs.is_better_release

/*
**Description**:
- Alias for `visual_studio.get_best_release`.
- Selects the better of two `VS_Release_Info` values.

**Params**:
- `a: VS_Release_Info` — First release candidate.
- `b: VS_Release_Info` — Second release candidate.
- `compare_opts: VS_Release_Compare_Options` — Options controlling the comparison semantics.

**Returns**:
- The better of `a` and `b` according to `compare_opts`.
*/
vs_get_best_release :: vs.get_best_release

/*
**Description**:
- Gets the `VsDevCmd.bat` path for a specific release.

**Params**:
- `ctx: Build_Context` — Build context that manages memory.
- `release: VS_Release_Info` — Release to derive the path from.

**Returns**:
- `path` — Generated path to `VsDevCmd.bat`.
- `err` — Non-nil if memory allocation for `path` fails.

**Warning**:
- This does not verify the existence of the file; it only constructs the expected path.
*/
vs_get_vsdevcmd_path :: proc(ctx: ^Build_Context, release: VS_Release_Info, caller_location := #caller_location) -> (path: string, err: Allocator_Error) #optional_allocator_error {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    return vs.get_vsdevcmd_path(release, gc.allocator(&ctx.garbage_collector))
}

/*
**Description**:
- Queries all Visual Studio releases installed on the system.

**Params**:
- `ctx: Build_Context` — Build context that manages memory.

**Returns**:
- `infos` — List of discovered releases.
- `err` — Non-nil if memory allocation or enumeration fails.
*/
vs_get_release_infos :: proc(ctx: ^Build_Context, caller_location := #caller_location) -> (infos: VS_Releases, err: VS_Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    return vs.get_release_infos(gc.allocator(&ctx.garbage_collector))
}

/*
**Description**:
- Deep clones a `VS_Release_Info`, including owned strings.

*Allocates Using Provided Allocator*

**Params**:
- `info: VS_Release_Info` — Release info to clone.
- `allocator: runtime.Allocator` — Allocator used for all cloned memory.

**Returns**:
- `output` — Cloned release info.
- `err` — Non-nil if allocation fails.
*/

vs_clone_release_info :: proc(info: VS_Release_Info, allocator := context.allocator, caller_location := #caller_location) -> (output: VS_Release_Info, err: Allocator_Error) #optional_allocator_error {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()
    
    return vs.clone_release_info(info, allocator)
}

/*
**Description**:
- Locates an executable or file associated with a specific Visual Studio release.

**Params**:
- `ctx: Build_Context` — Build context that manages memory.
- `release: VS_Release_Info` — Release whose environment is searched.
- `name: string` — Program or file name to locate.
- `cwd: string` — Optional working directory for resolution.

**Returns**:
- `path` — Resolved path if found.
- `found` — Whether the program was located.
- `err` — Non-nil on lookup or allocation failure.

**Warning**:
- This relies on `VsDevCmd.bat` and therefore works only on Windows systems.
- If `VsDevCmd.bat` is missing, this returns `General_Error.Missing_Program`.
*/
vs_which :: proc(ctx: ^Build_Context, release: VS_Release_Info, name: string, cwd := "", caller_location := #caller_location) -> (path: string, found: bool, err: VS_Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    return vs.which(release, name, gc.allocator(&ctx.garbage_collector), cwd=cwd)
}

/*
**Description**:
- Boolean variant of `vs_which` that reports existence without returning a path.
- Useful if you dont want to manage the memory for the output path.

**Params**:
- `ctx: Build_Context` — Build context that manages memory.
- `release: VS_Release_Info` — Release whose environment is searched.
- `name: string` — Program or file name to locate.
- `cwd: string` — Optional working directory for resolution.

**Returns**:
- `found` — Whether the program was located.
- `err` — Non-nil on lookup or allocation failure.
*/
vs_which_b :: proc(ctx: ^Build_Context, release: VS_Release_Info, name: string, cwd := "", caller_location := #caller_location) -> (found: bool, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    return vs.which_b(release, name, gc.allocator(&ctx.garbage_collector), cwd=cwd)
}
