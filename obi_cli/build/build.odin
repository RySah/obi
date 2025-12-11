package build

import obi "../.."

build :: proc() -> obi.Error {
    ctx := obi.create_build_context(context.allocator) or_return
    defer obi.destroy_build_context(&ctx) 

    cmd := obi.Shell_Command{
        working_dir="",
        command={"echo", "Hi from OBI"},
        env=nil
    }
    cmd_step := obi.shell_command_to_step(&ctx, &cmd) or_return

    append(&ctx.pre_build_steps, cmd_step) or_return

    obi.build(&ctx) or_return
    
    return nil
}

main :: proc() {
    err := build()
}