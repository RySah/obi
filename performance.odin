// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ryan Mensah

/*
Package obi — performance.odin

This file defines `Performance_Tracker`, purposed to track memory allocation and program duration.
Implemented to be used in favor of `mem.Tracking_Allocator`.
*/

package obi

import "core:mem"
import "core:time"
import "core:fmt"
import "core:strings"
import "core:unicode/utf8"

Performance_Tracker :: struct {
    memory_tracker: mem.Tracking_Allocator,
    start_time: time.Time,
    duration: time.Duration
}

/*
**Description**:
- Initializes a `Performance_Tracker`.

*Allocates Using Provided Allocator*

**Params**:
- `track: Performance_Tracker` — Memory location of tracker to initialize.
- `backing_allocator: mem.Allocator` — Allocator used to initialize the tracker.
- `internals_allocator: mem.Allocator` - Allocator used to allocate memory for tracker data.
*/
@(no_sanitize_address)
performance_tracker_init :: proc(
    track: ^Performance_Tracker,
    backing_allocator: mem.Allocator,
    internals_allocator := context.allocator
) {
    context.allocator = internals_allocator
    mem.tracking_allocator_init(&track.memory_tracker, backing_allocator)
}

/*
**Description**:
- Destroys `Performance_Tracker`, making it unusable.
- Frees associated memory.

**Params**:
- `track: Performance_Tracker` — Memory location of tracker to destroy.
*/
@(no_sanitize_address)
performance_tracker_destroy :: proc(
    track: ^Performance_Tracker
) {
    mem.tracking_allocator_destroy(&track.memory_tracker)
}

/*
**Description**:
- Gets an allocator wrapper that tracks memory allocations.

**Params**:
- `track: Performance_Tracker` — Memory location of tracker to query.

**Returns**:
- `mem.Allocator` - Allocator wrapper
*/
@(require_results, no_sanitize_address)
performance_tracker_allocator :: proc(
    track: ^Performance_Tracker
) -> mem.Allocator {
    return mem.tracking_allocator(&track.memory_tracker)
}

/*
**Description**:
- Starts tracking for `Performance_Tracker`.

**Params**:
- `track: Performance_Tracker` — Memory location of tracker to start.
*/
@(no_sanitize_address)
performance_tracker_start :: proc(
    track: ^Performance_Tracker
) {
    track.start_time = time.now()
}

/*
**Description**:
- Stops tracking for `Performance_Tracker`.

**Params**:
- `track: Performance_Tracker` — Memory location of tracker to end.
*/
@(no_sanitize_address)
performance_tracker_end :: proc(
    track: ^Performance_Tracker
) {
    track.duration = time.since(track.start_time)
}

/*
**Description**:
- Emits `Performance_Tracker` data to a `string.Builder`.

**Params**:
- `buf: ^strings.Builder` — Output string buffer.
- `track: ^Performance_Tracker` - Performance tracker to emit.
- `memory_leak_slice_capacity: Maybe(int)` - For every memory leak entry, this will set the maximum length in which the procedure can read of that 
leaked memory , If set to 0, theres no limit.

**Returns**:
- The resulting emitted string.
*/
@(no_sanitize_address)
performance_tracker_sbprint :: proc(
    buf: ^strings.Builder,
    track: ^Performance_Tracker,
    memory_leak_slice_capacity: Maybe(int) = 0
) -> string {
    // _bytes_to_kib_kb_mib_mb :: proc(count: f64) -> (kib: f64, kb: f64, mib: f64, mb: f64) {
    //     KIB := 1024.0
    //     MIB := 1024.0 * 1024.0
    //     KB := 1000.0
    //     MB := 1000.0 * 1000.0

    //     bytes := f64(count)

    //     kib = bytes / KIB
    //     kb = bytes / KB
    //     mib = bytes / MIB
    //     mb = bytes / MB

    //     return
    // }

    {
        //kib, kb, mib, mb: f64

        fmt.sbprintfln(buf, "=== Performance - %s  ===", ODIN_BUILD_PROJECT_NAME)
        fmt.sbprintfln(buf, "Duration:           %v", track.duration)
        fmt.sbprintfln(buf, "")
        fmt.sbprintfln(buf, "Memory Usage:")
        // kib, kb, mib, mb = _bytes_to_kib_kb_mib_mb(f64(track.memory_tracker.current_memory_allocated))
        // fmt.sbprintfln(buf, "  Current:          %db %fkib %fkb %fmib %fmb", 
        //     track.memory_tracker.current_memory_allocated,
        //     kib, kb, mib, mb 
        // )
        // kib, kb, mib, mb = _bytes_to_kib_kb_mib_mb(f64(track.memory_tracker.peak_memory_allocated))
        // fmt.sbprintfln(buf, "  Peak:             %db %fkib %fkb %fmib %fmb", 
        //     track.memory_tracker.peak_memory_allocated,
        //     kib, kb, mib, mb 
        // )
        // kib, kb, mib, mb = _bytes_to_kib_kb_mib_mb(f64(track.memory_tracker.total_memory_allocated))
        // fmt.sbprintfln(buf, "  Total:            %db %fkib %fkb %fmib %fmb", 
        //     track.memory_tracker.total_memory_allocated,
        //     kib, kb, mib, mb 
        // )
        // kib, kb, mib, mb = _bytes_to_kib_kb_mib_mb(f64(track.memory_tracker.total_memory_freed))
        // fmt.sbprintfln(buf, "  Freed:            %db %fkib %fkb %fmib %fmb",
        //     track.memory_tracker.total_memory_freed,
        //     kib, kb, mib, mb
        // )
        fmt.sbprintfln(buf, "  Current:          %#m", track.memory_tracker.current_memory_allocated)
        fmt.sbprintfln(buf, "  Peak:             %#m", track.memory_tracker.peak_memory_allocated)
        fmt.sbprintfln(buf, "  Total:            %#m", track.memory_tracker.total_memory_allocated)
        fmt.sbprintfln(buf, "  Freed:            %#m", track.memory_tracker.total_memory_freed)
        fmt.sbprintfln(buf, "")
        fmt.sbprintfln(buf, "Allocation Count:   %d", track.memory_tracker.total_allocation_count)
        fmt.sbprintfln(buf, "Free Count:         %d", track.memory_tracker.total_free_count)
    }
    if len(track.memory_tracker.allocation_map) > 1 /* Memory allocations aside from the performance tracker. */ {
        _mem_is_printable :: proc(b: byte) -> bool {
            return b >= 32 && b <= 126
        }
        _mem_dump :: proc(buf: ^strings.Builder, ptr: rawptr, size: int, width: int) {
            bytes := transmute([^]byte)ptr

            for i := 0; i < size; i += width {
                line_len := min(width, size - i)
            
                // Offset
                fmt.sbprintf(buf, "    %08x: ", i)
            
                // Hex view
                for j := 0; j < width; j += 1 {
                    if j < line_len {
                        fmt.sbprintf(buf, "%02x ", bytes[i+j])
                    } else {
                        fmt.sbprintf(buf, "   ")
                    }
                }
            
                fmt.sbprintf(buf, " |")
            
                // ASCII view
                for j := 0; j < line_len; j += 1 {
                    b := bytes[i+j]
                    if _mem_is_printable(b) {
                        fmt.sbprintf(buf, "%c", b)
                    } else {
                        fmt.sbprintf(buf, ".")
                    }
                }
            
                fmt.sbprintfln(buf, "|")
            }
        }

        _MEM_SLICE_WIDTH :: 24

        fmt.sbprintfln(buf, "")
        fmt.sbprintfln(buf, "WARNING: Memory leak detected.")

        for _, entry in track.memory_tracker.allocation_map {
            if entry.memory == buf || entry.memory == raw_data(buf.buf[:]) do continue
            fmt.sbprintfln(buf, "- %v bytes @ %v  %v", entry.size, entry.location, entry.memory)
        
            mem_slice_len := min(memory_leak_slice_capacity.? or_else max(int), entry.size)
            if mem_slice_len > 0 {
                _mem_dump(buf, entry.memory, mem_slice_len, _MEM_SLICE_WIDTH)
            }
        }
    }
    
    return strings.to_string(buf^)
}

/*
**Description**:
- Emits `Performance_Tracker` data to `os.stderr`.

**Params**:
- `track: ^Performance_Tracker` - Performance tracker to emit.
- `memory_leak_slice_capacity: Maybe(int)` - For every memory leak entry, this will set the maximum length in which the procedure can read of that 
leaked memory , If set to 0, theres no limit.
*/
@(no_sanitize_address)
performance_tracker_eprint :: proc(
    track: ^Performance_Tracker,
    memory_leak_slice_capacity: Maybe(int) = 0
) {
    temp_sb := strings.builder_make()
    defer strings.builder_destroy(&temp_sb)
    fmt.eprintf("%s", performance_tracker_sbprint(&temp_sb, track, memory_leak_slice_capacity))
}

/*
**Description**:
- Emits `Performance_Tracker` data to `os.stdout`.

**Params**:
- `track: ^Performance_Tracker` - Performance tracker to emit.
- `memory_leak_slice_capacity: Maybe(int)` - For every memory leak entry, this will set the maximum length in which the procedure can read of that 
leaked memory , If set to 0, theres no limit.
*/
@(no_sanitize_address)
performance_tracker_print :: proc(
    track: ^Performance_Tracker,
    memory_leak_slice_capacity: Maybe(int) = 0
) {
    temp_sb := strings.builder_make()
    defer strings.builder_destroy(&temp_sb)
    fmt.printf("%s", performance_tracker_sbprint(&temp_sb, track, memory_leak_slice_capacity))
}
