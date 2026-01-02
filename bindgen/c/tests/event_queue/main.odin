package test

import bindgen "../../.."
import cbindgen "../.."
import "core:fmt"
import "core:mem"
import "core:log"

HEADER_PATH :: "event_queue.h"

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v  %v\n", entry.size, entry.location, entry.memory)
                    
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	if factory, factory_err := bindgen.make_factory(); factory_err != nil {
		fmt.panicf("Failed to allocate memory for factory: %v", factory_err)
	} else {
		defer bindgen.destroy_factory(&factory)

		type_aliases := cbindgen.make_type_aliases(with_suggested=true)
		defer delete(type_aliases)

		if parser_err := cbindgen.parse(&factory, HEADER_PATH, { keep_stdlib=true, type_aliases=type_aliases }); parser_err != nil {
			fmt.panicf("(%v) Failed to parse. %v", parser_err, factory.last_source_location)
		} else {
			fmt.printfln("%#v\n", factory)
			bindgen.emit_factory_stdout(
				&factory, 
				emit_info={
					cases=#partial{
						.Function = .Camel,
						.Type = .Ada
					}
				}
			)
		}
	}
}
