package build
import "core:fmt"
import "core:math/rand"
import "core:mem"
import "core:log"

import obi "../.."


// Generates GEAR data for the FastCDC based off the current deployment hash.
// NOTE(rysah): This function is expected to create a new GEAR for FastCDC, PER deployment change, meaning rebuilds will trigger on new versions 
// of this project.
fastcdc_gear_fill_step :: proc(ctx: ^obi.Build_Context) -> (step: ^obi.Step, err: obi.Error) {
    rng_state := rand.create(get_deployment_hash())
    rng := rand.default_random_generator(&rng_state)
    int_data: [256/size_of(u32)]u32
    for i := 0; i < len(int_data); i += 1 {
        int_data[i] = rand.uint32(rng)
    }
    data := mem.slice_to_bytes(int_data[:])
    log.infof("Fast CDC GEAR Data(len=%d): %v", len(data), data)
    file_create := obi.File_Create {
        path="../incremental/chunk/Fast_CDC_GEAR.bin",
        data=data
    }
    step = obi.to_step(ctx, &file_create) or_return
    step.name = "fastcdc-gear-fill"
    return step, nil
}

build :: proc(user_args: ..string) -> (ctx: obi.Build_Context, err: obi.Error) {
    when ODIN_DEBUG {
        track: obi.Performance_Tracker

        obi.performance_tracker_init(&track, context.allocator)
        context.allocator = obi.performance_tracker_allocator(&track)

        obi.performance_tracker_start(&track)
        defer {
            obi.performance_tracker_end(&track)
            obi.performance_tracker_eprint(&track, memory_leak_slice_capacity=nil)
            obi.performance_tracker_destroy(&track)
        }
    }

    ctx = obi.create_build_context(user_args, is_main=true) or_return
    defer obi.destroy_build_context(&ctx) 
    
    ctx.logger = obi.create_build_logger(&ctx, lowest=obi.Debug_Mode_Lowest_Build_Logger_Level, opt=obi.Debug_Mode_Build_Logger_Opts) or_return
    defer obi.destroy_build_logger(&ctx, ctx.logger)

    context.logger = ctx.logger

    version := get_version()
    version_str := aprint_version(version)
    defer delete(version_str)

    log.infof("VERSION: %s", version_str)

    fastcdc_gear_fill := fastcdc_gear_fill_step(&ctx) or_return
    obi.add_step(&ctx, fastcdc_gear_fill) or_return

    build_step := obi.create_step(&ctx, "build") or_return
    obi.add_step(&ctx, build_step) or_return
    obi.add_child(build_step, fastcdc_gear_fill) or_return

    obi.build(&ctx) or_return

    return ctx, nil
}

main :: proc() { 
    err: obi.Error
    build_ctx: obi.Build_Context

    err = obi.init()
    fmt.assertf(err == nil, "build initiation failed. (%v)", err)
    defer obi.deinit()

    build_ctx, err = build("build")
    fmt.assertf(err == nil, "build failed. (%v)\nTRACEBACK:\n%s\n", err, obi.blame(&build_ctx, err, allow_newlines=true))
    
}
