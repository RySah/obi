package garbage_collector

import vmem "core:mem/virtual"
import "core:mem"

Error :: vmem.Allocator_Error

Garbage_Collector :: struct {
    using arena: vmem.Arena
}

init_growing :: vmem.arena_init_growing

init_static :: vmem.arena_init_static

init_buffer :: vmem.arena_init_buffer

alloc_raw :: vmem.arena_alloc

allocator :: vmem.arena_allocator

collect :: vmem.arena_free_all

destroy :: vmem.arena_destroy

