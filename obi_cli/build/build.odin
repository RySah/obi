package build
import "core:fmt"
import "core:mem"

import obi "../.."
import subprocess "../../subprocess"

build :: proc() -> (ctx: obi.Build_Context, err: obi.Error) {
    when ODIN_DEBUG {
        track: obi.Performance_Tracker

        obi.performance_tracker_init(&track, context.allocator)
        context.allocator = obi.performance_tracker_allocator(&track)

        obi.performance_tracker_start(&track)
        defer {
            obi.performance_tracker_end(&track)
            obi.performance_tracker_eprint(&track, memory_slice_capacity=nil)
            obi.performance_tracker_destroy(&track)
        }

        // track: mem.Tracking_Allocator


        // mem.tracking_allocator_init(&track, context.allocator)
        // context.allocator = mem.tracking_allocator(&track)
    
        // defer {
        //     if len(track.allocation_map) > 0 {
        //         fmt.eprintf("=== %v allocations not freed (BUILD) ===\n", len(track.allocation_map))
        //         for _, entry in track.allocation_map {
        //             fmt.eprintf("- %v bytes @ %v  %v\n", entry.size, entry.location, entry.memory)
                    
        //         }
        //     }
        //     mem.tracking_allocator_destroy(&track)
        // }
    }

    ctx = obi.create_build_context() or_return
    ctx.logger = obi.create_build_logger(&ctx, lowest=obi.Debug_Mode_Lowest_Build_Logger_Level, opt=obi.Debug_Mode_Build_Logger_Opts) or_return
    defer obi.destroy_build_logger(&ctx, ctx.logger)

    // --- C IMPORT ARGS 3.3.0 ---
    {
        make_cmd := obi.Make{
            compatibility={.MingW32,.GNU},
            path=obi.Make_CWD_Path("third_party/args-3.3.0"),
            extra_flags={ "libs" }
        }
        make_step := obi.to_step(&ctx, &make_cmd) or_return
        make_step.name = "build args-3.3.0"

        api_import_info := obi.c_import(
            &ctx, 
            "third_party/args-3.3.0/src/args.h",
            emit_options=obi.Bindgen_Emit_Options{
                package_name="args3",
                foreign_import=obi.Bindgen_Foreign_Get{
                    alias="libarg3",
                    expr=obi.Bindgen_Foreign_Import_Path("third_party/args-3.3.0/build/libargs.a")
                },
                cases= #partial {
                    .Type=.Ada,
                    .Function=.Snake
                }
            }
        ) or_return
        api_import_step := obi.to_step(&ctx, api_import_info) or_return
        api_import_step.name = "import args-3.3.0 api"

        libargs_step := obi.merge_steps(&ctx,
            make_step,
            api_import_step
        ) or_return

        planned_libargs_step := obi.plan_step(&ctx,
            obi.files_fingerprint(&ctx, "third_party/args-3.3.0",
                dir_glob_patterns={ include={ "*" }, exclude={} },
                file_glob_patterns={ include={ "*" }, exclude={} }
            ) or_return,
            libargs_step
        ) or_return

        obi.add_step(&ctx, 
            planned_libargs_step.? or_else obi.Empty_Step
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
        build_step.name = "build obi_cli"

        planned_build_step := obi.plan_step(&ctx,
            obi.files_fingerprint(&ctx, ".", "third_party", 
                dir_glob_patterns={ include={ "*" }, exclude={ctx.cache_file_system.path} },
                file_glob_patterns={ include={ "*.odin", "*.sjson" }, exclude={} }
            ) or_return,
            build_step
        ) or_return

        obi.add_step(&ctx, 
            planned_build_step.? or_else obi.Empty_Step
        ) or_return
    }   
    // ------------------

    obi.build(&ctx, obi.user_args(), ) or_return
    
    return ctx, nil
}

main :: proc() { 
    err: obi.Error
    build_ctx: obi.Build_Context

    err = obi.init()
    fmt.assertf(err == nil, "build initiation failed. (%v)", err)
    defer obi.deinit()

    build_ctx, err = build()
    fmt.assertf(err == nil, "build failed. (%v)\nTRACEBACK:\n%s\n", err, obi.blame(&build_ctx, err, allow_newlines=true))
    
}
