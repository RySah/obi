package obi

import subprocess "subprocess"
import ia "intern_arena"
import promise "promise"

import "core:path/filepath"
import "core:os/os2"

CMake_Error :: enum int {
    None,
    // Could not find any `cmake` program 
    Missing_Program,

    Failed_To_Get_Abs_Path
}

/*
Indicates what should take priority when searching for `cmake`.

- `.User` Checks if cmake was installed system wide, or in the current working directory.
- `.Visual_Studio` Checks if visual studio is installed and its respective `cmake`.
*/
CMake_Program_Priority :: enum u8 {
    User,
    Visual_Studio
}

@(private="file")
_which_cmake :: proc(ctx: ^Build_Context, priority: CMake_Program_Priority, caller_location := #caller_location) -> (path: string, found: bool, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    switch priority {
        case .User: 
            path, found = ta_subprocess_which("cmake", allocator=ia.allocator(&ctx.intern_arena), cwd=ctx.working_dir, search_local=true) or_return
            when ODIN_OS == .Windows {
                if !found {
                    path, found = promise.get_ref(&ctx.windows.visual_studio_cmake_path).?
                }
            }
        case .Visual_Studio:
            when ODIN_OS == .Windows {
                path, found = promise.get_ref(&ctx.windows.visual_studio_cmake_path).?
            }
            if !found {
                path, found = ta_subprocess_which("cmake", allocator=ia.allocator(&ctx.intern_arena), cwd=ctx.working_dir, search_local=true) or_return
            }
    }
    return path, found, nil
}

/*
**Workflow description**:
- Build artifacts are generated directly in the source tree.
- Configuration and build stage occur in the same directory.  
- ```
  cmake <source_directory>
  cmake --build <source_directory>
  ```

**NOTE:** This workflow is legacy and discouraged as it pollutes the source tree.
*/
CMake_In_Source_Build :: struct {
    source_directory: string,
    // Set to `.User` by default, `.Visual_Studio` is disregarded when NOT on Windows and parsed as `.User`
    program_priority: CMake_Program_Priority
}

cmake_in_source_build_to_step :: proc(ctx: ^Build_Context, c: ^CMake_In_Source_Build, caller_location := #caller_location) -> (step: ^Step, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    context.allocator = ctx.allocator
    cmake_directory := c.source_directory
    
    cmake_path: string
    cmake_found: bool
    //cmake_path, cmake_found := subprocess.which("cmake", ctx.allocator, search_local=true) or_return
    program_priority: CMake_Program_Priority = .User when ODIN_OS != .Windows else c.program_priority
    cmake_path, cmake_found = _which_cmake(ctx, program_priority) or_return
    if !cmake_found do return step, CMake_Error.Missing_Program

    config_stage_cmd := Sub_Process_Command{
        working_dir=cmake_directory,
        command={ cmake_path, "."  }
    }
    config_stage_step := to_step(ctx, &config_stage_cmd) or_return
    config_stage_step.name = "config-stage"

    build_stage_cmd := Sub_Process_Command{
        working_dir=cmake_directory,
        command={ cmake_path, "--build", "." }
    }
    build_stage_step := to_step(ctx, &build_stage_cmd) or_return
    build_stage_step.name = "build-stage"

    return merge_steps(ctx, config_stage_step, build_stage_step)
}

/*
**Workflow description**:
- Source and build artifacts are kept seperate.
- Configuration and build stage occur in the seperate directories.  
- ```
  mkdir <build_directory>
  cd <build_directory>
  cmake ..
  cmake --build .
  ```

**NOTE:** This workflow is standard and recommended
*/
CMake_Out_Of_Source_Build :: struct {
    source_directory: string,
    build_directory: string,
    // Set to `.User` by default, `.Visual_Studio` is disregarded when NOT on Windows and parsed as `.User`
    program_priority: CMake_Program_Priority
}

cmake_out_of_source_build_to_step :: proc(ctx: ^Build_Context, c: ^CMake_Out_Of_Source_Build, caller_location := #caller_location) -> (step: ^Step, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    context.allocator = ctx.allocator

    mk_build_dir := MkDir{
        path=c.build_directory,
        all=true
    }
    mk_build_dir_step := to_step(ctx, &mk_build_dir) or_return
    mk_build_dir_step.name = "make-build-directory"

    full_source_dir, full_source_dir_ok := filepath.abs(c.source_directory)
    if !full_source_dir_ok do return step, CMake_Error.Failed_To_Get_Abs_Path
    defer delete(full_source_dir)
    
    cmake_path: string
    cmake_found: bool
    //cmake_path, cmake_found := subprocess.which("cmake", ctx.allocator, search_local=true) or_return
    program_priority: CMake_Program_Priority = .User when ODIN_OS != .Windows else c.program_priority
    cmake_path, cmake_found = _which_cmake(ctx, program_priority) or_return
    if !cmake_found do return step, CMake_Error.Missing_Program

    config_stage_cmd := Sub_Process_Command{
        working_dir=c.build_directory,
        command={ cmake_path, full_source_dir  }
    }
    config_stage_step := to_step(ctx, &config_stage_cmd) or_return
    config_stage_step.name = "config-stage"

    build_stage_cmd := Sub_Process_Command{
        working_dir=c.build_directory,
        command={ cmake_path, "--build", full_source_dir }
    }
    build_stage_step := to_step(ctx, &build_stage_cmd) or_return
    build_stage_step.name = "build-stage"

    return merge_steps(ctx, mk_build_dir_step, config_stage_step, build_stage_step)
}

CMake_Build :: CMake_Out_Of_Source_Build
