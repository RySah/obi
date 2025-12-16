package build
import "core:fmt"

import obi "../.."

build :: proc() -> obi.Error {
    ctx := obi.create_build_context() or_return 
    defer obi.destroy_build_context(&ctx)
    
    ctx.logger = obi.create_build_logger(&ctx) or_return
    
    build_cmd := obi.Odin_Build{
        mode=.Executable,
        path=obi.Odin_Build_Dir_Path("."),
        extra_flags={}
    }
    build_step := obi.to_step(&ctx, &build_cmd) or_return
    
    planned_build_step := obi.plan_step(&ctx,
        obi.files_fingerprint(&ctx, ".", file_glob_patterns={ "*.odin", "*.sjson" }) or_return,
        build_step
    ) or_return

    obi.add_step(&ctx, 
        planned_build_step.? or_else obi.Empty_Step
    ) or_return

    obi.build(&ctx) or_return
    
    return nil
}

main :: proc() { 
    err := build()
    fmt.assertf(err == nil, "Build failed. (%v)", err)
}
