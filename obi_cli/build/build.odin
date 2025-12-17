package build
import "core:fmt"

import obi "../.."

build :: proc() -> obi.Error {
    ctx := obi.create_build_context() or_return 
    defer obi.destroy_build_context(&ctx)
    
    ctx.logger = obi.create_build_logger(&ctx) or_return

    // --- C IMPORT ARGS 3.3.0 ---
    {
        make_cmd := obi.Make{
            compatibility={.MingW32,.GNU},
            path=obi.Make_CWD_Path("third_party/args-3.3.0"),
            extra_flags={ "libs" }
        }
        make_step := obi.to_step(&ctx, &make_cmd) or_return
        make_step.name = "making args-3.3.0"

        api_import_info := obi.c_import(&ctx, "args3", "third_party/args-3.3.0/src/args.h") or_return
        api_import_info.type_name_case = .Ada_Case
        api_import_info.function_name_case = .Snake_Case
        api_import_info.lib = "third_party/args-3.3.0/build/libargs.a"
        api_import_step := obi.to_step(&ctx, api_import_info) or_return
        api_import_step.name = "importing api-3.3.0 api"

        obi.add_step(&ctx, 
            make_step,
            api_import_step
        ) or_return
    }
    // ---------------------------
    
    // --- BUILD STEP ---
    {
        build_cmd := obi.Odin_Build{
            mode=.Executable,
            path=obi.Odin_Build_Dir_Path("."),
            extra_flags={}
        }
        build_step := obi.to_step(&ctx, &build_cmd) or_return

        planned_build_step := obi.plan_step(&ctx,
            obi.files_fingerprint(&ctx, ".", "third_party", file_glob_patterns={ "*.odin", "*.sjson" }) or_return,
            build_step
        ) or_return

        obi.add_step(&ctx, 
            planned_build_step.? or_else obi.Empty_Step
        ) or_return
    }   
    // ------------------

    obi.build(&ctx) or_return
    
    return nil
}

main :: proc() { 
    err := build()
    fmt.assertf(err == nil, "Build failed. (%v)", err)
}
