package visual_studio

import subprocess "../subprocess"

import "core:encoding/json"
import "core:mem"
import "core:os/os2"
import "core:strings"
import "core:strconv"
import "core:path/filepath"

General_Error :: enum int {
    None,
    // Failed to locate a program
    Missing_Program,
    VS_Where_Failed,
    Invalid_VS_Where_Format
}

Error :: union #shared_nil {
    mem.Allocator_Error,
    General_Error,
    subprocess.Error,
    json.Error
}

Release_Version :: struct {
    major, minor, build, revision: uint
}

is_better_version :: proc(a, b: Release_Version) -> bool {
    if a.major != b.major {
        return a.major > b.major
    }
    if a.minor != b.minor {
        return a.minor > b.minor
    }
    if a.build != b.build {
        return a.build > b.build
    }
    if a.revision != b.revision {
        return a.revision > b.revision
    }
    return false // they are equal
}

// Information struct to store whats necessary from the `vswhere` command.
// This represents a single visual studio release the user has installed.
Release_Info :: struct {
    // "installationVersion" in vswhere output.
    version: Release_Version,
    // "productPath" in vswhere output.
    devenv_path: string,
    // "isPrerelease" in vswhere output.
    is_prerelease: bool,
    // "displayName" in vswhere output.
    name: string
}

clone_release_info :: proc(info: Release_Info, allocator := context.allocator) -> (output: Release_Info, err: mem.Allocator_Error) #optional_allocator_error {
    context.allocator = allocator
    output.version = info.version
    output.devenv_path = strings.clone(info.devenv_path) or_return
    output.is_prerelease = info.is_prerelease
    output.name = strings.clone(info.name) or_return
    return output, nil
}

Release_Compare_Options :: struct {
    no_prerelease: bool
}

is_better_release :: proc(a, b: Release_Info, compare_opts := Release_Compare_Options{}) -> bool {
    if compare_opts.no_prerelease {
        if a.is_prerelease && !b.is_prerelease do return false
        if !a.is_prerelease && b.is_prerelease do return true
    }
    return is_better_version(a.version, b.version)
}

Releases :: distinct []Release_Info

get_best_release :: proc(releases: Releases, compare_opts := Release_Compare_Options{}) -> ^Release_Info {
    if len(releases) == 0 do panic("Empty releases.")

    best: ^Release_Info = &releases[0]

    for i := 1; i < len(releases); i += 1 {
        current := &releases[i]
        if is_better_release(current^, best^, compare_opts) {
            best = current
        }
    }

    return best
}

// **NOTE**: This does not guarantee the file exists.
get_vsdevcmd_path :: proc(release: Release_Info, allocator := context.allocator) -> (path: string, err: mem.Allocator_Error) #optional_allocator_error {
    context.allocator = allocator
    ide_dir := filepath.dir(release.devenv_path)
    defer delete(ide_dir)
    common7_dir := filepath.dir(ide_dir)
    defer delete(common7_dir)
    path = filepath.join({ common7_dir, "Tools", "VsDevCmd.bat" }) or_return
    return path, nil
}

// **NOTE:** This will only work on windows systems
which :: proc(release: Release_Info, name: string, allocator := context.allocator, cwd := "") -> (path: string, found: bool, err: Error) {
    context.allocator = allocator
    vsdevcmd_path := get_vsdevcmd_path(release)
    defer delete(vsdevcmd_path)
    if !os2.exists(vsdevcmd_path) do return path, found, General_Error.Missing_Program
    cmd := subprocess.Command{
        working_dir=cwd,
        command={vsdevcmd_path, "&&", "where", name},
        env=nil,
        stdin=nil,
        shell=true
    }
    state, stdout, stderr := subprocess.run(cmd, context.allocator) or_return
    defer delete(stderr)

    path = transmute(string)stdout
    found = (state.exit_code == 0 when ODIN_OS == .Windows else state.success) && os2.exists(path)
    return path, found, nil
}

which_b :: proc(release: Release_Info, name: string, allocator := context.allocator, cwd := "") -> (found: bool, err: Error) {
    context.allocator = allocator
    path: string
    path, found = which(release, name, context.allocator, cwd=cwd) or_return
    defer delete(path)
    return found, nil
}

free_releases :: proc(releases: Releases, allocator := context.allocator) -> Error {
    context.allocator = allocator
    for &release in releases {
        delete(release.devenv_path) or_return
        delete(release.name) or_return
    }
    delete(releases) or_return
    return nil
}

@(private)
_get_release_infos_from_path :: proc(path: string, allocator := context.allocator) -> (infos: Releases, err: Error) {
    context.allocator = allocator

    vswhere_cmd := subprocess.Command{
        working_dir="",
        command={ path, "-format", "json", "-nocolor", "-prerelease" }
    }
    state, stdout, stderr := subprocess.run(vswhere_cmd) or_return
    defer delete(stdout)
    defer delete(stderr)

    success := state.exit_code == 0 when ODIN_OS == .Windows else state.success

    if success {
        json_data := stdout
        parsed := json.parse(json_data) or_return
        defer json.destroy_value(parsed)

        releases: json.Array = ---
        ok: bool
        releases, ok = parsed.(json.Array)
        if !ok do return infos, General_Error.Invalid_VS_Where_Format

        infos = make(Releases, len(releases)) or_return
        
        for &release, i in releases {
            release_object: json.Object
            release_object, ok = release.(json.Object)
            if !ok do return infos, General_Error.Invalid_VS_Where_Format

            {
                installation_version_str: string = ---
                {
                    installation_version_value: json.Value
                    installation_version_value, ok = release_object["installationVersion"]
                    if !ok do return infos, General_Error.Invalid_VS_Where_Format

                    installation_version_str, ok = installation_version_value.(json.String)
                    if !ok do return infos, General_Error.Invalid_VS_Where_Format
                }
                installation_version_tokens := strings.split(installation_version_str, ".") or_return
                defer delete(installation_version_tokens)

                if len(installation_version_tokens) != 4 do return infos, General_Error.Invalid_VS_Where_Format

                infos[i].version.major, ok = strconv.parse_uint(installation_version_tokens[0], base=10)
                if !ok do return infos, General_Error.Invalid_VS_Where_Format
                infos[i].version.minor, ok = strconv.parse_uint(installation_version_tokens[1], base=10)
                if !ok do return infos, General_Error.Invalid_VS_Where_Format
                infos[i].version.build, ok = strconv.parse_uint(installation_version_tokens[2], base=10)
                if !ok do return infos, General_Error.Invalid_VS_Where_Format
                infos[i].version.revision, ok = strconv.parse_uint(installation_version_tokens[3], base=10)
                if !ok do return infos, General_Error.Invalid_VS_Where_Format
            }

            {
                product_path_value: json.Value
                product_path_value, ok = release_object["productPath"]
                if !ok do return infos, General_Error.Invalid_VS_Where_Format
                product_path_str: string
                product_path_str, ok = product_path_value.(json.String)
                if !ok do return infos, General_Error.Invalid_VS_Where_Format
                infos[i].devenv_path = strings.clone(product_path_str) or_return
            }

            {
                is_prerelease_value: json.Value
                is_prerelease_value, ok = release_object["isPrerelease"]
                if !ok do return infos, General_Error.Invalid_VS_Where_Format
                infos[i].is_prerelease, ok = is_prerelease_value.(json.Boolean)
                if !ok do return infos, General_Error.Invalid_VS_Where_Format
            }

            {
                display_name_value: json.Value
                display_name_value, ok = release_object["displayName"]
                if !ok do return infos, General_Error.Invalid_VS_Where_Format
                display_name_str: string
                display_name_str, ok = display_name_value.(json.String)
                if !ok do return infos, General_Error.Invalid_VS_Where_Format
                infos[i].name = strings.clone(display_name_str) or_return
            }
        }

        return infos, nil
    } else {
        return infos, General_Error.VS_Where_Failed
    }
}

get_release_infos :: proc(allocator := context.allocator) -> (infos: Releases, err: Error) {
    context.allocator = allocator
    DEFAULT_SEARCH_PATHS :: [?]string{
        `C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe`,
        `C:\Program Files\Microsoft Visual Studio\Installer\vswhere.exe` //NOTE(rysah): Likely WONT be here
    }
    #unroll for path in DEFAULT_SEARCH_PATHS {
        if os2.exists(path) {
            infos, err = _get_release_infos_from_path(path)
            if err == nil {
                return infos, nil
            } else if err != General_Error.Invalid_VS_Where_Format {
                return infos, err
            }
        }
    }
    return infos, General_Error.Missing_Program
}

