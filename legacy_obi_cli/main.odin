package obi_cli

import obi ".."

import "core:fmt"
import "core:os"
import "core:os/os2"
import "core:path/filepath"
import "core:strings"
import "core:terminal"
import "core:terminal/ansi"
import "core:mem"

DEFAULT_CONFIG_FILENAME :: "build.sjson"

errorf :: proc(format: string, args: ..any) {
    colour_enabled := terminal.is_terminal(os.stderr) && terminal.color_enabled
    fmt.eprintf(
        "%s[ERROR] ",
        colour_enabled ? ansi.CSI + ansi.FG_RED + ansi.SGR : ""
    )
    fmt.eprintf(format, ..args)
    fmt.eprintfln(
        "%s",
        colour_enabled ? ansi.CSI + ansi.RESET + ansi.SGR : ""
    )
    os.exit(1)
}

assertf :: proc(cond: bool, format: string, args: ..any) {
    if !cond do errorf(format, ..args)
}

main :: proc() {
    args := os2.args

    if strings.compare(args[1], "build") == 0 {
        allocator_err: mem.Allocator_Error
        non_abs_config_path: string
        if os2.is_dir(args[2]) {
            non_abs_config_path, allocator_err = filepath.join({ args[2], DEFAULT_CONFIG_FILENAME })
        } else {
            non_abs_config_path, allocator_err = strings.clone(args[2])
        }
        assertf(allocator_err == nil, "Failed to allocate memory for configuration path. (%v)", allocator_err)
        defer delete(non_abs_config_path)

        assertf(os2.exists(non_abs_config_path), "Could not find path: %q", non_abs_config_path)

        config_path_ok: bool
        config_path: string
        config_path, config_path_ok = filepath.abs(non_abs_config_path)
        assertf(config_path_ok, "Failed to get the absolute config path %q.", config_path)
        defer delete(config_path)

        config: Config = ---
        config_parse_err := parse_config_from_path(config_path, &config)
        assertf(config_parse_err == nil, "Failed to parse configuration %q. (%v)", config_path, config_parse_err)

        output_dir_ok: bool
        output_dir_path: string
        output_dir_path, output_dir_ok = filepath.abs(config.output_directory)
        assertf(config_path_ok, "Failed to get the absolute output directory path %q.", output_dir_path)
        defer delete(output_dir_path)

        config_dir := filepath.dir(config_path)
        defer delete(config_dir)

        cwd := config_dir

        cwd_err := os2.set_working_directory(cwd)
        assertf(cwd_err == nil, "Failed to set the working directory to %q. (%v)", cwd, cwd_err)

        obi_err: obi.Error
        build_ctx: obi.Build_Context

        build_ctx, obi_err = obi.create_build_context()
        defer obi.destroy_build_context(&build_ctx)

        build_ctx.logger = obi.create_build_logger(&build_ctx)

        make_output_directory_err := os2.make_directory_all(output_dir_path)
        assertf(make_output_directory_err == nil, "Failed to make output directory. (%v)", make_output_directory_err)

        extra_build_flags: []string
        extra_build_flags, allocator_err = make([]string, len(config.extra_build_flags) + 1)
        assertf(allocator_err == nil, "Failed to allocate memory for extra build flags. (%v)", allocator_err)
        copy_slice(extra_build_flags[1:], config.extra_build_flags)
        defer delete(extra_build_flags)

        EXECUTABLE_FILENAME :: ODIN_OS_STRING + "-" + ODIN_ARCH_STRING + "-" + ("build.exe" when ODIN_OS == .Windows else "build")

        executable_output_path: string
        executable_output_path, allocator_err = filepath.join({ output_dir_path, EXECUTABLE_FILENAME })
        assertf(allocator_err == nil, "Failed to allocate memory for output executable path. (%v)", allocator_err)
        defer delete(executable_output_path)

        extra_build_flags[0], allocator_err = strings.concatenate({ "-out:", executable_output_path })
        assertf(allocator_err == nil, "Failed to allocate memory for output executable path flag. (%v)", allocator_err)
        defer delete(extra_build_flags[0])

        libclang_output_path: string
        libclang_output_path, allocator_err = filepath.join({ output_dir_path, "libclang.dll" })
        assertf(allocator_err == nil, "Failed to allocate memory for libclang output path. (%v)", allocator_err)
        defer delete(libclang_output_path)

        file_trunc_cmd := obi.File_Create{
            path=libclang_output_path,
            data=LIBCLANG_DLL_EMBED
        }
        file_trunc_step: obi.Step
        file_trunc_step, allocator_err = obi.to_step(&build_ctx, &file_trunc_cmd)
        assertf(allocator_err == nil, "Failed to allocate memory for file create step (%q). (%v)", file_trunc_cmd.path, allocator_err)
        file_trunc_step.success_required = true
        os_specific_file_trunc_step: obi.OS_Arch_Specific_Step = ---
        os_specific_file_trunc_step[.Windows][.AMD64] = file_trunc_step
        file_trunc_step = obi.resolve_os_arch_specific(&os_specific_file_trunc_step).? or_else obi.Empty_Step

        build_cmd := obi.Odin_Build{
            path=obi.Odin_Build_Dir_Path(config.build_directory),
            extra_flags=extra_build_flags
        }
        build_step: obi.Step
        build_step, allocator_err = obi.to_step(&build_ctx, &build_cmd)
        assertf(allocator_err == nil, "Failed to allocate memory for build step construction. (%v)", allocator_err)
        build_step.success_required = true

        run_cmd := obi.Sub_Process_Command{
            working_dir=cwd,
            command={ executable_output_path },
            shell=true
        }
        run_step: obi.Step
        run_step, allocator_err = obi.to_step(&build_ctx, &run_cmd)
        assertf(allocator_err == nil, "Failed to allocate memory for run step construction. (%v)", allocator_err)
        run_step.success_required = true

        allocator_err = obi.add_step(&build_ctx,
            // Emitting necessary binaries.
            file_trunc_step, 
            // Building the build package.
            build_step,
            // Running the build package.
            run_step
        )
        assertf(allocator_err == nil, "Failed to allocate memory for steps. (%v)", allocator_err)

        obi_err = obi.build(&build_ctx)
        assertf(obi_err == nil, "Recieved an error whilst trying to build %q. (%v)", config.build_directory, obi_err)
    }

}
