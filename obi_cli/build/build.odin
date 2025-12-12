package build

import obi "../.."

build :: proc() -> obi.Error {
    ctx := obi.create_build_context(context.allocator) or_return
    defer obi.destroy_build_context(&ctx) 

    cmd := obi.Sub_Process_Command{
        working_dir="",
        command={"echo", "Hi from OBI"},
        env=nil
    }
    cmd_step := obi.to_step(&ctx, &cmd) or_return

    odin_run := obi.Odin_Run{
        path=obi.Odin_Build_Dir_Path("."),
        extra_flags={}
    }
    odin_run_step := obi.to_step(&ctx, &odin_run) or_return

    append(&ctx.pre_build_steps, cmd_step, odin_run_step) or_return

    obi.build(&ctx) or_return
    
    return nil
}

main :: proc() {
    err := build()
}