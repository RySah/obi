package thread_safe_logger

import "core:log"
import "core:sync"

// Logger :: struct {
// 	procedure:    Logger_Proc,
// 	data:         rawptr,
// 	lowest_level: Logger_Level,
// 	options:      Logger_Options,
// }

Thread_Safe_Logger :: struct {
    using impl: log.Logger,
    backing: log.Logger,
    mutex: sync.Mutex
}

logger_proc : log.Logger_Proc : proc(
    data: rawptr, 
    level: log.Level, 
    text: string, 
    options: log.Options, 
    location := #caller_location
) {
    logger := transmute(^Thread_Safe_Logger)data
    if sync.mutex_guard(&logger.mutex) {
        logger.backing.procedure(
            logger.backing.data,
            level,
            text,
            options,
            location
        )
    }
}

init :: proc(l: ^Thread_Safe_Logger, backing: log.Logger) {
    l.backing = backing
    l.impl.data = l
    l.impl.procedure = logger_proc
    l.impl.lowest_level = l.backing.lowest_level
    l.impl.options = l.backing.options
}

original :: proc(l: ^Thread_Safe_Logger) -> log.Logger {
    return l.backing
}