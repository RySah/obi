package obi

import vs "visual_studio"
import gc "garbage_collector"

VS_Error :: vs.Error
VS_General_Error :: vs.General_Error
VS_Release_Version :: vs.Release_Version
VS_Release_Info :: vs.Release_Info
VS_Release_Compare_Options :: vs.Release_Compare_Options
VS_Releases :: vs.Releases

vs_is_better_version :: vs.is_better_version
vs_is_better_release :: vs.is_better_release
vs_get_best_release :: vs.get_best_release
vs_get_vsdevcmd_path :: proc(ctx: ^Build_Context, release: VS_Release_Info, caller_location := #caller_location) -> (path: string, err: Allocator_Error) #optional_allocator_error {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    return vs.get_vsdevcmd_path(release, gc.allocator(&ctx.garbage_collector))
}
vs_get_release_infos :: proc(ctx: ^Build_Context, caller_location := #caller_location) -> (infos: VS_Releases, err: VS_Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    return vs.get_release_infos(gc.allocator(&ctx.garbage_collector))
}
vs_clone_release_info :: proc(info: VS_Release_Info, allocator := context.allocator, caller_location := #caller_location) -> (output: VS_Release_Info, err: Allocator_Error) #optional_allocator_error {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    return vs.clone_release_info(info, allocator)
}
vs_which :: proc(ctx: ^Build_Context, release: VS_Release_Info, name: string, cwd := "", caller_location := #caller_location) -> (path: string, found: bool, err: VS_Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    return vs.which(release, name, gc.allocator(&ctx.garbage_collector), cwd=cwd)
}
vs_which_b :: proc(ctx: ^Build_Context, release: VS_Release_Info, name: string, cwd := "", caller_location := #caller_location) -> (found: bool, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    return vs.which_b(release, name, gc.allocator(&ctx.garbage_collector), cwd=cwd)
}
