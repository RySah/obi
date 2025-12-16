package obi

import vs "visual_studio"
import gc "garbage_collector"

VS_Error :: vs.Error
VS_Release_Version :: vs.Release_Version
VS_Release_Info :: vs.Release_Info
VS_Release_Compare_Options :: vs.Release_Compare_Options
VS_Releases :: vs.Releases

vs_is_better_version :: vs.is_better_version
vs_is_better_release :: vs.is_better_release
vs_get_best_release :: vs.get_best_release
vs_get_vsdevcmd_path :: proc(ctx: ^Build_Context, release: VS_Release_Info) -> (path: string, err: Allocator_Error) #optional_allocator_error {
    return vs.get_vsdevcmd_path(release, gc.allocator(&ctx.garbage_collector))
}
vs_get_release_infos :: proc(ctx: ^Build_Context) -> (infos: VS_Releases, err: VS_Error) {
    return vs.get_release_infos(gc.allocator(&ctx.garbage_collector))
}
vs_clone_release_info :: vs.clone_release_info
vs_which :: proc(ctx: ^Build_Context, release: VS_Release_Info, name: string, cwd := "") -> (path: string, found: bool, err: VS_Error) {
    return vs.which(release, name, gc.allocator(&ctx.garbage_collector), cwd=cwd)
}
vs_which_b :: proc(ctx: ^Build_Context, release: VS_Release_Info, name: string, cwd := "") -> (found: bool, err: Error) {
    return vs.which_b(release, name, gc.allocator(&ctx.garbage_collector), cwd=cwd)
}
