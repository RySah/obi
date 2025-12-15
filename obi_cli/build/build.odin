package build

import obi "../.."

import "core:mem"
import "core:fmt"

import "base:runtime"

build_proj :: proc() -> obi.Error {
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

    ctx := obi.create_build_context() or_return
    defer obi.destroy_build_context(&ctx)

    ctx.logger = obi.create_build_logger(&ctx)

    build := obi.Odin_Build{
        path=obi.Odin_Build_Dir_Path("."),
        extra_flags={}
    }
    build_step := obi.to_step(&ctx, &build) or_return
    build_step.success_required = true
    
    planned_build_step := obi.plan_step(&ctx,
        obi.files_fingerprint(&ctx, 
            ".",
            file_glob_patterns={"*.odin"}
        ) or_return,
        build_step
    ) or_return
    obi.add_step(&ctx, 
        planned_build_step.? or_else obi.Empty_Step
    ) or_return

    obi.build(&ctx) or_return
    
    return nil
}

main :: proc() {
    err := build_proj()
}