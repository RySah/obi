package obi

import ia "intern_arena"
import "core:path/filepath"
import "core:strings"

import "base:intrinsics"

GCC_Optimization_Level :: enum u8 {
    O0, O1, O2, O3, Os, Ofast, Og,

    None = O0,
    Basic = O1,
    Standard = O2, // Production_Default
    Aggressive = O3, // Enables vectorisation, unrolling, inlining heuristics
    Size = Os,
    Fast = Ofast, // Breaks strict IEEE and strict aliasing
    Debug = Og, // Meant for debugging performance sensitive code

    Production_Default = O2
}
gcc_optimization_level_flag :: proc(v: GCC_Optimization_Level) -> string {
    switch v {
        case .O0: return "-O0"
        case .O1: return "-O1"
        case .O2: return "-O2"
        case .O3: return "-O3"
        case .Os: return "-Os"
        case .Ofast: return "-Ofast"
        case .Og: return "-Og"
    }
    unimplemented()
}

CC_Optimization_Level :: enum u8 {
    O0 = u8(GCC_Optimization_Level.O0),
    O1 = u8(GCC_Optimization_Level.O1),
    O2 = u8(GCC_Optimization_Level.O2),
    O3 = u8(GCC_Optimization_Level.O3),
    Os = u8(GCC_Optimization_Level.Os),
    Ofast = u8(GCC_Optimization_Level.Ofast),

    None = O0,
    Basic = O1,
    Standard = O2, // Production_Default
    Aggressive = O3, // Enables vectorisation, unrolling, inlining heuristics
    Size = Os,
    Fast = Ofast // Breaks strict IEEE and strict aliasing
}
cc_optimization_level_flag :: proc(v: GCC_Optimization_Level) -> string {
    return gcc_optimization_level_flag(transmute(GCC_Optimization_Level)v)
}

Clang_Optimization_Level :: enum u8 {
    O0, O1, O2, O3, Os, Oz, Ofast,

    None = O0,
    Basic = O1,
    Standard = O2,
    Aggressive = O3, // Generally more aggressive on inlining and vectorisation than GCC's
    Size = Os,
    Aggressive_Size = Oz, // Clang specific, and more "size-focused" than Size
    Fast = Ofast
}
clang_optimization_level_flag :: proc(v: Clang_Optimization_Level) -> string {
    switch v {
        case .O0: return "-O0"
        case .O1: return "-O1"
        case .O2: return "-O2"
        case .O3: return "-O3"
        case .Os: return "-Os"
        case .Oz: return "-Oz"
        case .Ofast: return "-Ofast"
    }
    unimplemented()
}

MSVC_Optimization_Level :: enum u8 {
    Od, O1, O2, Ox, 

    None = Od,
    Size = O1,
    Fast = O2,
    Full = Ox
}
msvc_optimization_level_flag :: proc(v: MSVC_Optimization_Level) -> string {
    switch v {
        case .Od: return "/Od"
        case .O1: return "/O1"
        case .O2: return "/O2"
        case .Ox: return "/Ox"
    }
    unimplemented()
}

Clang_CL_Optimization_Level :: distinct MSVC_Optimization_Level
clang_cl_optimization_level_flag :: proc(v: Clang_CL_Optimization_Level) -> string {
    return msvc_optimization_level_flag(transmute(MSVC_Optimization_Level)v)
}

@(private="file") _Equiv_Optimization_Level :: struct{ 
    clang: Maybe(Clang_Optimization_Level), 
    msvc: Maybe(MSVC_Optimization_Level), 
    clang_cl: Maybe(Clang_CL_Optimization_Level),
    cc: Maybe(CC_Optimization_Level)
}

// Lossy equivalance table that helps map each optimization level
@(private="file", rodata) _equivalence_table := [GCC_Optimization_Level]_Equiv_Optimization_Level {
    .O0 =    { clang=.O0,    msvc=.Od, clang_cl=.Od, cc=.O0    },
    .O1 =    { clang=.O1,    msvc=nil, clang_cl=nil, cc=.O1    },
    .O2 =    { clang=.O2,    msvc=.O2, clang_cl=.O2, cc=.O2    },
    .O3 =    { clang=.O3,    msvc=.Ox, clang_cl=.Ox, cc=.O3    },
    .Os =    { clang=.Os,    msvc=.O1, clang_cl=.O1, cc=.Os    },
    .Ofast = { clang=.Ofast, msvc=nil, clang_cl=nil, cc=.Ofast },
    .Og =    { clang=nil,    msvc=nil, clang_cl=nil, cc=nil    },
}

@(private="file") _get_maybe_equiv :: proc(input: $T, $OT: typeid) -> Maybe(OT)
where (T != OT) && (
    OT == GCC_Optimization_Level || 
    OT == Clang_Optimization_Level || 
    OT == MSVC_Optimization_Level || 
    OT == Clang_CL_Optimization_Level ||
    OT == CC_Optimization_Level
) && (
    T == GCC_Optimization_Level || 
    T == Clang_Optimization_Level || 
    T == MSVC_Optimization_Level || 
    T == Clang_CL_Optimization_Level ||
    T == CC_Optimization_Level
) {
    when T == GCC_Optimization_Level {
        equiv_collection_ptr := &_equivalence_table[input]
        equiv_collection_uptr := transmute(uintptr)equiv_collection_ptr
        member_offset: uintptr
        when OT == Clang_Optimization_Level {
            member_offset = offset_of(_Equiv_Optimization_Level, clang)
        } else when OT == MSVC_Optimization_Level {
            member_offset = offset_of(_Equiv_Optimization_Level, msvc)
        } else when OT == Clang_CL_Optimization_Level {
            member_offset = offset_of(_Equiv_Optimization_Level, clang_cl)
        } else when OT == Clang_CL_Optimization_Level {
            member_offset = offset_of(_Equiv_Optimization_Level, cc)
        } else {
            #panic("[DEV ERROR]")
        }
        member_uptr := equiv_collection_uptr + member_offset
        member_ptr := transmute(^Maybe(OT))member_uptr
        return member_ptr^
    } else when OT == GCC_Optimization_Level {
        #unroll for level in GCC_Optimization_Level {
            if impl, exists := _get_maybe_equiv(level, T).?; exists && impl == input do return level
        }
    } else {
        gcc_level := _get_maybe_equiv(input, GCC_Optimization_Level).?
        return _get_maybe_equiv(gcc_level, OT)
    }
}

get_maybe_equiv_c_optimization_level :: _get_maybe_equiv

Optimization_Level :: enum u8 {
    None = (u8)(GCC_Optimization_Level.O0),
    Basic = (u8)(GCC_Optimization_Level.O1),
    Standard = (u8)(GCC_Optimization_Level.O2),
    Aggressive = (u8)(GCC_Optimization_Level.O3),
    Size = (u8)(GCC_Optimization_Level.Os),
    Fast = (u8)(GCC_Optimization_Level.Ofast)
}

@(private="file") _to_base_optimization_level :: proc(v: Optimization_Level) -> GCC_Optimization_Level {
    return transmute(GCC_Optimization_Level)v
}

OBJ_EXT :: ".obj" when ODIN_OS == .Windows else ".o"

C_Path :: distinct string
Object_Path :: distinct string

Object_Source :: union {
    C_Path
}

Object_Spec :: struct {
    sources: []Object_Source,
    optimization: Optimization_Level
}

C_Object_Spec :: struct {
    input_paths: []C_Path,
    optimization: Optimization_Level
}

Object_Error :: enum int {
    None,
    // Failed to locate any compatible compiler programs
    Incompatible_Or_No_Compiler_Program=1
}

get_expected_output_object_paths :: proc(ctx: ^Build_Context, oc: ^Object_Spec) -> (out: []Object_Path, err: Error) {
    out = make([]Object_Path, len(oc.sources), ia.allocator(&ctx.intern_arena)) or_return
    for &source, i in oc.sources {
        switch &path in source {
            case C_Path:
                _, filename := filepath.split(transmute(string)path)
                // TODO(rysah): Perhaps consider interning this concat.
                out[i] = transmute(Object_Path)strings.concatenate({ filepath.base(filename), OBJ_EXT }, ia.allocator(&ctx.intern_arena)) or_return
        }
    }
    return out, nil
}

c_object_spec_to_subprocess :: proc(
    ctx: ^Build_Context, 
    oc: ^C_Object_Spec, 
    caller_location := #caller_location
) -> (cmd_p: ^Sub_Process_Command, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    when ODIN_OS == .Windows {
        use_clang_msvc := true
        if cl_path, cl_path_exists := ctx.windows.visual_studio_cl_path.?; cl_path_exists {
            use_clang_msvc = false
        
            maybe_msvc_optimization_level := get_maybe_equiv_c_optimization_level(_to_base_optimization_level(oc.optimization), MSVC_Optimization_Level)
        
            command_size := 1 // cl
            if _, exists := maybe_msvc_optimization_level.?; exists do command_size += 1 // /O
            command_size += 1 // /c
            command_size += len(oc.input_paths)
        
            cmd := Sub_Process_Command {
                working_dir = ia.intern_string(&ctx.intern_arena, ctx.working_dir) or_return,
                command = make([]string, command_size, ia.allocator(&ctx.intern_arena)) or_return,
                env=nil,
                stdin=nil
            }
        
            cmd.command[0] = cl_path
            i := 1
            if msvc_optimization_level, exists := maybe_msvc_optimization_level.?; exists {
                cmd.command[i] = msvc_optimization_level_flag(msvc_optimization_level)   
                i += 1
            }
            cmd.command[i] = "/c"
            i += 1
            for &path, j in oc.input_paths do cmd.command[i+j] = ia.intern_by_value(&ctx.intern_arena, transmute(string)path) or_return
            return ia.clone_value(&ctx.intern_arena, cmd)
        } else if use_clang_msvc {
            if clang_cl_path, clang_cl_path_found := ta_subprocess_which("clang-cl") or_return; clang_cl_path_found {
                defer delete(clang_cl_path)
                maybe_clang_cl_optimization_level := get_maybe_equiv_c_optimization_level(_to_base_optimization_level(oc.optimization), Clang_CL_Optimization_Level)
            
                command_size := 1 // clang-cl
                if _, exists := maybe_clang_cl_optimization_level.?; exists do command_size += 1 // /O
                command_size += 1 // /c
                command_size += len(oc.input_paths)
            
                cmd := Sub_Process_Command {
                    working_dir = ia.intern_string(&ctx.intern_arena, ctx.working_dir) or_return,
                    command = make([]string, command_size, ia.allocator(&ctx.intern_arena)) or_return,
                    env=nil,
                    stdin=nil
                }
            
                cmd.command[0] = cl_path
                i := 1
                if msvc_optimization_level, exists := maybe_clang_cl_optimization_level.?; exists {
                    cmd.command[i] = clang_cl_optimization_level_flag(msvc_optimization_level)
                    i += 1
                }
                cmd.command[i] = "/c"
                i += 1
                for &path, j in oc.input_paths do cmd.command[i+j] = ia.intern_by_value(&ctx.intern_arena, transmute(string)path) or_return
                return ia.clone_value(&ctx.intern_arena, cmd)
            } else {
                return nil, Object_Error.Incompatible_Or_No_Compiler_Program
            }
        }
    } else when ODIN_OS == .Linux || ODIN_OS == .Darwin {
        if cc_path, cc_path_found := ta_subprocess_which("cc") or_return; cc_path_found {
            defer delete(cc_path)
            maybe_cc_optimization_level := get_maybe_equiv_c_optimization_level(_to_base_optimization_level(oc.optimization), CC_Optimization_Level)
        
            command_size := 1 // cc
            if _, exists := maybe_cc_optimization_level.?; exists do command_size += 1 // -O
            command_size += 1 // -c
            command_size += len(oc.input_paths)
        
            cmd := Sub_Process_Command {
                working_dir = ia.intern_string(&ctx.intern_arena, ctx.working_dir) or_return,
                command = make([]string, command_size, ia.allocator(&ctx.intern_arena)) or_return,
                env=nil,
                stdin=nil
            }
        
            cmd.command[0] = cc_path
            i := 1
            if cc_optimization_level, exists := maybe_cc_optimization_level.?; exists {
                cmd.command[i] = cc_optimization_level_flag(cc_optimization_level)
                i += 1
            }
            cmd.command[i] = "-c"
            i += 1
            for &path, j in oc.input_paths do cmd.command[i+j] = ia.intern_by_value(&ctx.intern_arena, transmute(string)path) or_return
            return ia.clone_value(&ctx.intern_arena, cmd)
        }
    }

    if gcc_path, gcc_path_found := ta_subprocess_which("gcc") or_return; gcc_path_found {
        defer delete(gcc_path)
        gcc_optimization_level := _to_base_optimization_level(oc.optimization)
    
        command_size := 1 // gcc
        command_size += 1 // -O
        command_size += 1 // -c
        command_size += len(oc.input_paths)
    
        cmd := Sub_Process_Command {
            working_dir = ia.intern_string(&ctx.intern_arena, ctx.working_dir) or_return,
            command = make([]string, command_size, ia.allocator(&ctx.intern_arena)) or_return,
            env=nil,
            stdin=nil
        }
    
        cmd.command[0] = gcc_path
        i := 1
        cmd.command[i] = gcc_optimization_level_flag(gcc_optimization_level)
        i += 1
        cmd.command[i] = "-c"
        i += 1
        for &path, j in oc.input_paths do cmd.command[i+j] = ia.intern_by_value(&ctx.intern_arena, transmute(string)path) or_return
        return ia.clone_value(&ctx.intern_arena, cmd)
    } else if clang_path, clang_path_found := ta_subprocess_which("clang") or_return; clang_path_found {
        defer delete(clang_path)
        maybe_clang_optimization_level := get_maybe_equiv_c_optimization_level(_to_base_optimization_level(oc.optimization), Clang_Optimization_Level)
    
        command_size := 1 // clang
        command_size += 1 // -O
        command_size += 1 // -c
        command_size += len(oc.input_paths)
    
        cmd := Sub_Process_Command {
            working_dir = ia.intern_string(&ctx.intern_arena, ctx.working_dir) or_return,
            command = make([]string, command_size, ia.allocator(&ctx.intern_arena)) or_return,
            env=nil,
            stdin=nil
        }
    
        cmd.command[0] = gcc_path
        i := 1
        if clang_optimization_level, exists := maybe_clang_optimization_level.?; exists {
            cmd.command[i] = clang_optimization_level_flag(clang_optimization_level)
            i += 1
        }
        cmd.command[i] = "-c"
        i += 1
        for &path, j in oc.input_paths do cmd.command[i+j] = ia.intern_by_value(&ctx.intern_arena, transmute(string)path) or_return
        return ia.clone_value(&ctx.intern_arena, cmd)
    }

    return nil, Object_Error.Incompatible_Or_No_Compiler_Program
}

c_object_spec_to_step :: proc(ctx: ^Build_Context, oc: ^C_Object_Spec, caller_location := #caller_location) -> (step: ^Step, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    cmd := c_object_spec_to_subprocess(ctx, oc) or_return
    return subprocess_to_step(ctx, cmd)
}

object_spec_to_step :: proc(ctx: ^Build_Context, oc: ^Object_Spec, caller_location := #caller_location) -> (step: ^Step, err: Error) {
    _start_trace()
    _trace(caller_location)
    _trace()
    defer if err == nil do _backtrace()

    c_paths := make([dynamic]C_Path) or_return
    defer delete(c_paths)

    for &source in oc.sources {
        switch &internal in source {
            case C_Path:
                append(&c_paths, internal) or_return
        }
    }

    if len(c_paths) > 0 {
        c_spec := C_Object_Spec {
            input_paths=c_paths[:],
            optimization=oc.optimization
        }
        step = to_step(ctx, &c_spec) or_return
    } else {
        step = create_step(ctx) or_return
    }
    return step, nil
}