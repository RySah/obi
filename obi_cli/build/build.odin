package build

import obi "../.."

import "core:mem"
import "core:fmt"
import "core:strings"

import "base:runtime"

build :: proc() -> obi.Error {
    when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed (BUILD) ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v  %v\n", entry.size, entry.location, entry.memory)
                    
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

    ctx := obi.create_build_context(context.allocator) or_return
    defer obi.destroy_build_context(&ctx)

    // make_tomlc17 := obi.Make{
    //     compatibility={ .GNU, .MingW32 },
    //     path=obi.Make_CWD_Path("third_party/tomlc17-R251129"),
    //     extra_flags={"clean"}
    // }
    // make_tomlc17_step := obi.to_step(&ctx, &make_tomlc17) or_return
    // obi.add_step(&ctx, make_tomlc17_step) or_return

    // cmd := obi.Sub_Process_Command{
    //     working_dir=ctx.working_dir,
    //     command={"ls"},
    //     env=nil
    // }
    // cmd_step := obi.to_step(&ctx, &cmd) or_return
    // obi.add_step(&ctx, cmd_step) or_return

    odin_run := obi.Odin_Run{
        path=obi.Odin_Build_Dir_Path("."),
        extra_flags={}
    }
    odin_run_step := obi.to_step(&ctx, &odin_run) or_return
    obi.add_step(&ctx, odin_run_step) or_return

    obi.build(&ctx) or_return
    
    return nil
}

main :: proc() {
    err := build()
}