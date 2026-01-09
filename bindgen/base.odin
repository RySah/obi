package bindgen

import "core:mem"
import "core:strings"
import "core:fmt"
import "core:os"
import vmem "core:mem/virtual"

import "base:runtime"

Value :: struct {
    raw: rawptr,
    type: typeid
}
Maybe_Value :: Maybe(Value)

// Converts a reference to a value into a `Value`` struct.  
// The value will share the same lifetime as the reference passed in.  
// If the lifetime needs to be propogated use `to_value_from_clone` followed by eventually `destroy_value` to clean up.
to_value_from_ref :: proc(ref: $T/^$E) -> Value {
    return Value{
        raw=ref,
        type=typeid_of(T)
    }
}
// Clones a value via the provided allocator and converts it into a `Value` struct.  
// The caller is responsible for eventually calling `destroy_value` to clean up the cloned value.
to_value_from_clone :: proc(data: $T, allocator := context.allocator) -> (out: Value, err: mem.Allocator_Error) {
    out = Value{
        raw=new_clone(data, allocator) or_return,
        type=typeid_of(T)
    }
    return out, nil
}
// Destroys a value created via `to_value_from_clone`.
destroy_value :: proc(value: Value, allocator := context.allocator) -> mem.Allocator_Error {
    free(value.raw, allocator) or_return
    return nil
}

value_to_any :: proc(value: Value) -> (out: any) {
    out.id = value.type
    out.data = value.raw
    return
}

values_equal :: proc(a: Value, b: Value) -> bool {
    return a.type == b.type && mem.simple_equal(a.raw, b.raw)
}

Name_Type_Field :: struct {
    name: string,
    type: ^Decl
}

Name_Value_Field :: struct {
    name: string,
    value: Value
}

Param :: struct {
    using field: Name_Type_Field,
    default_value: Maybe_Value
}

params_equal :: proc(a, b: Param) -> bool {
    v_eq := true
    if a_v, a_ok := a.default_value.?; a_ok {
        if b_v, b_ok := b.default_value.?; b_ok {
            v_eq = values_equal(a_v, b_v) 
        }
    }
    return strings.compare(a.name, b.name) == 0 && a.type == b.type && v_eq
}

Calling_Conv :: enum u8 {
    // Default calling convention generated of a procedure in C
    CDecl,
    // Default convention used for an Odin procedure, it passes all parameters larger than 16 bytes by reference and passes an implicit context pointer on each call. (Subject to change)
    Odin,
    // Same as `Odin` but without the implicit context pointer
    Odin_Contextless,
    // The stdcall convention as specified by Microsoft
    StdCall,
    // This is a compiler dependent calling convention
    FastCall,
    // This is a compiler dependent calling covnention which will do noting in parameters
    None
}

calling_conv_name :: proc(cc: Calling_Conv) -> string {
    switch cc {
        case .CDecl: return "cdecl"
        case .Odin: return "odin"
        case .Odin_Contextless: return "contextless"
        case .StdCall: return "stdcall"
        case .FastCall: return "fastcall"
        case .None: return "none"
    }
    unimplemented()
}

Struct_Info :: struct {
    fields: [dynamic]Name_Type_Field
}
Union_Info :: distinct Struct_Info
Enum_Info :: struct {
    underlying_type: ^Decl,
    fields: [dynamic]Name_Value_Field
}
// Alias for `void` in C, this has no functionality aside from being used as Builtin_Info. 
c_void :: distinct struct{}
// Alias for `char` in context of a `cstring` in C, when given a Pointer_Decl->Builtin_Info(c_char_s) it will be evaluated as `cstring`
c_char_s :: distinct struct{}
// Alias for an opaque type in C, this has no functionality aside from being used as Builtin_Info.
c_opaque :: distinct struct {}

Builtin_Info :: distinct ^runtime.Type_Info
as_builtin_info_comptime :: #force_inline proc($T: typeid) -> Builtin_Info {
    return Builtin_Info(type_info_of(T))
}
as_builtin_info :: #force_inline proc(T: typeid) -> Builtin_Info {
    return Builtin_Info(type_info_of(T))
}

Record_Info :: Struct_Info
as_record_info :: proc(v: $T) -> Record_Info where T == Struct_Info || T == Union_Info {
    return transmute(Record_Info)v
}
as_struct_info :: proc(v: Record_Info) -> Struct_Info {
    return transmute(Struct_Info)v
}
as_union_info :: proc(v: Record_Info) -> Union_Info {
    return transmute(Union_Info)v
}

Func_Info :: struct {
    return_decl: ^Decl,
    param_decls: [dynamic]^Decl,
    calling_conv: Calling_Conv
}

Type_Decl :: struct {
    name: string,
    info: union {
        Struct_Info,
        Union_Info,
        Enum_Info,
        Builtin_Info,
        Func_Info
    },
    size: int,
    alignment: int
}

Func_Decl :: struct {
    name: string,
    return_type: ^Decl,
    params: [dynamic]Param,
    calling_conv: Calling_Conv
}

Alias_Decl :: struct {
    name: string,
    underlying: ^Decl
}

Pointer_Decl :: struct {
    underlying: ^Decl
}

Unknown_Alias_Decl :: struct {
    name: string,
    expr: string,
    // If set to `true`, this alias will only be used to replace an existing declaration with the same name, otherwise, it wont emit at all.
    replace_only: bool
}

Decl_Privacy :: enum u8 {
    Public,
    Package_Private,
    File_Private
}

Constant_Array_Decl :: struct {
    elem_count: int,
    underlying: ^Decl
}

Decl :: struct {
    variant: union {
        Type_Decl,
        Func_Decl,
        Alias_Decl,
        Pointer_Decl,
        Unknown_Alias_Decl,
        Constant_Array_Decl
    },
    comment: Maybe(string),
    privacy: Decl_Privacy
}

Decl_Factory :: struct {
    using arena: vmem.Arena,
    items: [dynamic]^Decl
}
decl_factory_allocator :: vmem.arena_allocator

make_decl_factory :: #force_inline proc(allocator := context.allocator) -> (factory: Decl_Factory, err: runtime.Allocator_Error) #optional_allocator_error {
    vmem.arena_init_growing(&factory) or_return
    factory.items = make([dynamic]^Decl, allocator) or_return
    return factory, nil
}
destroy_decl_factory :: proc(factory: ^Decl_Factory) -> runtime.Allocator_Error {
    delete(factory.items) or_return
    vmem.arena_destroy(factory)
    return nil
}

make_decl :: #force_inline proc(factory: ^Decl_Factory, as_item := true) -> (p: ^Decl, err: runtime.Allocator_Error) #optional_allocator_error {
    context.allocator = decl_factory_allocator(factory)
    p = new(Decl) or_return
    if as_item do append(&factory.items, p) or_return
    return p, nil
}

Factory :: struct {
    footer, header: Maybe(string),
    decls: Decl_Factory,
    nonbase_data: rawptr,
    allocator: runtime.Allocator,
    last_source_location: Maybe(runtime.Source_Code_Location)
}

make_factory :: proc(allocator := context.allocator) -> (factory: Factory, err: runtime.Allocator_Error) #optional_allocator_error {
    context.allocator = allocator
    factory.decls = make_decl_factory() or_return
    factory.allocator = context.allocator
    return factory, nil
}
destroy_factory :: proc(factory: ^Factory) -> runtime.Allocator_Error {
    context.allocator = factory.allocator
    if footer, ok := factory.footer.?; ok do delete(footer) or_return
    if header, ok := factory.header.?; ok do delete(header) or_return
    destroy_decl_factory(&factory.decls) or_return
    if last_loc, allocated := factory.last_source_location.?; allocated {
        delete(last_loc.procedure) or_return
        delete(last_loc.file_path) or_return
    }
    return nil
}

get_name :: proc(decl: ^Decl) -> string {
    switch &internal in decl.variant {
        case Type_Decl:
            return internal.name
        case Func_Decl:
            return internal.name
        case Alias_Decl:
            return internal.name
        case Pointer_Decl:
            return get_name(internal.underlying)
        case Unknown_Alias_Decl:
            return internal.name
        case Constant_Array_Decl:
            return get_name(internal.underlying)
    }
    return ""
}

parse_w_case :: proc(value: string, out_case: Case, allocator := context.allocator) -> (res: string, err: mem.Allocator_Error) #optional_allocator_error {
    context.allocator = allocator
    switch out_case {
        case .Original: return strings.clone(value)
        case .Lower: return strings.to_lower(value)
        case .Upper: return strings.to_upper(value)
        case .Camel: return strings.to_camel_case(value)
        case .Pascal: return strings.to_pascal_case(value)
        case .Snake: return strings.to_snake_case(value)
        case .Screaming_Snake: return strings.to_screaming_snake_case(value)
        case .Ada:
            basic_ada := strings.to_ada_case(value) or_return
            defer delete(basic_ada) 

            segments := strings.split(basic_ada, "_") or_return
            defer delete(segments)

            out_segments := make([]string, len(segments)) or_return
            defer {
                for &seg in out_segments do delete(seg)
                delete(out_segments)
            }

            value_view := value
            upper_value := strings.to_upper(value_view) or_return
            defer delete(upper_value)
            upper_value_view := upper_value

            for &seg, i in segments {
                upper_seg := strings.to_upper(seg) or_return
                seg_view_i := strings.index(upper_value_view, upper_seg)
                delete(upper_seg)
            
                if seg_view_i == -1 {
                    out_segments[i] = strings.clone(seg) or_return
                    continue
                }
            
                view := value_view[seg_view_i : seg_view_i + len(seg)]
            
                has_letter := false
                all_caps := true
                for c in view {
                    if c >= 'A' && c <= 'Z' {
                        has_letter = true
                    } else if c >= 'a' && c <= 'z' {
                        all_caps = false
                        break
                    }
                }
                all_caps = all_caps && has_letter
            
                if all_caps {
                    out_segments[i] = strings.to_upper(seg) or_return
                } else {
                    out_segments[i] = strings.clone(seg) or_return
                }
            
                value_view = value_view[seg_view_i + len(seg):]
                upper_value_view = upper_value_view[seg_view_i + len(seg):]
            }

            result := strings.join(out_segments[:], "_") or_return
            return result, nil
    }
    unimplemented()
}

get_name_w_case :: proc(decl: ^Decl, out_case := Case.Original, allocator := context.allocator) -> (string, mem.Allocator_Error) #optional_allocator_error {
    context.allocator = allocator
    name := get_name(decl)
    return parse_w_case(name, out_case)
}

get_size :: proc(decl: ^Decl) -> int {
    if decl == nil do return 0
    #partial switch &internal in decl.variant {
        case Type_Decl:
            return internal.size
        case Func_Decl:
            return size_of(uintptr)
        case Pointer_Decl:
            return size_of(uintptr)
        case Alias_Decl:
            return get_size(internal.underlying)
        case Constant_Array_Decl:
            return get_size(internal.underlying)*internal.elem_count
    }
    unimplemented()
}

get_align :: proc(decl: ^Decl) -> int {
    if decl == nil do return 0
    #partial switch &internal in decl.variant {
        case Type_Decl:
            return internal.alignment
        case Func_Decl:
            return align_of(uintptr)
        case Pointer_Decl:
            return align_of(uintptr)
        case Alias_Decl:
            return get_align(internal.underlying)
        case Constant_Array_Decl:
            return get_align(internal.underlying)
    }
    unimplemented()
}

get_builtin :: proc(decl: ^Decl) -> ^Builtin_Info {
    if decl == nil do return nil
    #partial switch &internal in decl.variant {
        case Type_Decl:
            #partial switch &info in internal.info {
                case Builtin_Info:
                    return &info
            }
        case Alias_Decl:
            return get_builtin(internal.underlying)
    }
    return nil
}

get_unknown_alias :: proc(decl: ^Decl, shallow := false) -> ^Unknown_Alias_Decl {
    if decl == nil do return nil
    if shallow {
        if internal, exists := &decl.variant.(Unknown_Alias_Decl); exists do return internal
        return nil
    }

    #partial switch &internal in decl.variant {
        case Unknown_Alias_Decl:
            return &internal
        case Alias_Decl:
            return get_unknown_alias(internal.underlying)
    }
    return nil
}

get_base :: proc(decl: ^Decl) -> ^Decl {
    #partial switch &internal in decl.variant {
        case Alias_Decl:
            return get_base(internal.underlying)
        case:
            return decl
    }
}

Case :: enum u8 {
    Original,
    // lowercase
    Lower,
    // UPPERCASE
    Upper,
    // camelCase
    Camel,
    // PascalCase
    Pascal,
    // snake_case
    Snake,
    // SNAKE_CASE
    Screaming_Snake,
    // Ada_Case
    Ada
}

Emit_Point :: enum u8 {
    Type,
    Function,
    Field,
    Param,
    Enum_Field
}

Foreign_Import_Expr :: distinct string
Foreign_Import_Path :: distinct string

/*
`{ alias="kernel32", expr=Foreign_Import_Expr("foreign import kernel32 \"system:kernel32.lib\"") }` equiv to  
`{ alias="kernel32", expr=Foreign_Import_Path("system:kernel32.lib") }` equiv to  
`foreign import kernel32 "system:kernel32.lib"`
*/
Foreign_Get :: struct {
    // Name of the foriegn import e.g. `kernel32`
    alias: string,
    // Expression to get the import e.g. `foreign import kernel32 "system:kernel32.lib"`
    expr: union { Foreign_Import_Expr, Foreign_Import_Path }
}

Emit_Options :: struct {
    cases: [Emit_Point]Case,
    link_prefixes: []string,
    link_suffixes: []string,
    package_name: string,
    foreign_import: Foreign_Get
}

emit_factory_decls :: proc(factory: ^Decl_Factory, sb: ^strings.Builder, emit_opts := Emit_Options{}) -> string {
    eval_type_name :: proc(decl: ^Decl, out_case: Case, allocator := context.allocator) -> (name: string, err: mem.Allocator_Error) #optional_allocator_error {
        context.allocator = allocator
        if decl == nil do return strings.clone("<nil>")
        if pointer_decl, is_pointer := decl.variant.(Pointer_Decl); is_pointer {
            if pointer_decl.underlying != nil {
                if type_decl, is_type_decl := pointer_decl.underlying.variant.(Type_Decl); is_type_decl {
                    if builtin_info, is_builtin_info := type_decl.info.(Builtin_Info); is_builtin_info {
                        if builtin_info.id == typeid_of(c_void) {
                            return strings.clone("rawptr")
                        } else if builtin_info.id == typeid_of(c_char_s) {
                            return strings.clone("cstring")
                        }
                    }
                }
                underlying_name := eval_type_name(pointer_decl.underlying, out_case) or_return
                defer delete(underlying_name)
                return strings.concatenate({ "[^]", underlying_name })
            }
        }
        if builtin_info_ptr := get_builtin(decl); builtin_info_ptr != nil {
            builtin_info := builtin_info_ptr^
            if builtin_info.id == typeid_of(c_void) {
                return strings.clone("")
            } else if builtin_info.id == typeid_of(c_char_s) {
                return strings.clone("c.char")
            }
        }
        if type_decl, is_type_decl := decl.variant.(Type_Decl); is_type_decl {
            if builtin_info, is_builtin_info := type_decl.info.(Builtin_Info); is_builtin_info {
                return strings.clone(type_decl.name)
            }
        }
        if constant_array_decl, is_constant_array_decl := decl.variant.(Constant_Array_Decl); is_constant_array_decl {
            underlying_name := eval_type_name(constant_array_decl.underlying, out_case) or_return
            defer delete(underlying_name)
            return fmt.aprintf("[%d]%s", constant_array_decl.elem_count, underlying_name), nil
        }
        if unknown_alias_ptr := get_unknown_alias(decl, shallow=true); unknown_alias_ptr != nil {
            return strings.clone(unknown_alias_ptr.name)
        }
        return get_name_w_case(decl, out_case)
    }
    funcs_to_emit := make([dynamic]^Decl, 0, 16)
    defer delete(funcs_to_emit)
    for decl in factory.items {
        if decl == nil {
            strings.write_string(sb, "<nil>\n")
            continue
        }
        switch decl.privacy {
            case .Public:
                // Nothing to emit
            case .Package_Private:
                strings.write_string(sb, "@(private) ")
            case .File_Private:
                strings.write_string(sb, "@(private=\"file\") ")
        }
        switch &internal in decl.variant {
            case Type_Decl:
                if comment, ok := decl.comment.?; ok do fmt.sbprintfln(sb, "%s", comment)
                is_builtin := false
                switch &info in internal.info {
                    case Struct_Info:
                        name := parse_w_case(internal.name, emit_opts.cases[.Type])
                        defer delete(name)
                        fmt.sbprintfln(sb, "%s :: struct #align(%d)", name, internal.alignment)
                        strings.write_string(sb, "{\n")
                        for &field, i in info.fields {
                            type_name := eval_type_name(field.type, emit_opts.cases[.Type])
                            defer delete(type_name)
                            field_name := parse_w_case(field.name, emit_opts.cases[.Field])
                            defer delete(field_name)
                            fmt.sbprintf(sb, "    %s: %s", field_name, type_name)
                            if i + 1 < len(info.fields) do strings.write_string(sb, ",\n")
                            else do strings.write_byte(sb, '\n')
                        }
                        strings.write_string(sb, "}\n")
                    case Union_Info:
                        name := parse_w_case(internal.name, emit_opts.cases[.Type])
                        defer delete(name)
                        fmt.sbprintfln(sb, "%s :: struct #align(%d) #raw_union", name, internal.alignment)
                        strings.write_string(sb, "{\n")
                        for &field, i in info.fields {
                            type_name := eval_type_name(field.type, emit_opts.cases[.Type])
                            defer delete(type_name)
                            field_name := parse_w_case(field.name, emit_opts.cases[.Field])
                            defer delete(field_name)
                            fmt.sbprintf(sb, "    %s: %s", field_name, type_name)
                            if i + 1 < len(info.fields) do strings.write_string(sb, ",\n")
                            else do strings.write_byte(sb, '\n')
                        }
                        strings.write_string(sb, "}\n")
                    case Enum_Info:
                        name := parse_w_case(internal.name, emit_opts.cases[.Type])
                        defer delete(name)
                        underlying_type_name := eval_type_name(info.underlying_type, emit_opts.cases[.Type])
                        defer delete(underlying_type_name)
                        fmt.sbprintfln(sb, "%s :: enum %s", name, underlying_type_name)
                        strings.write_string(sb, "{\n")
                        for &field, i in info.fields {
                            field_name := parse_w_case(field.name, emit_opts.cases[.Enum_Field])
                            defer delete(field_name)
                            fmt.sbprint(sb, "    ", field_name, " = ", value_to_any(field.value), sep="")
                            if i + 1 < len(info.fields) do strings.write_string(sb, ",\n")
                            else do strings.write_byte(sb, '\n')
                        }
                        strings.write_string(sb, "}\n")
                    case Builtin_Info:
                        is_builtin = true
                        // Nothing to print for builtin
                    case Func_Info:
                        name := parse_w_case(internal.name, emit_opts.cases[.Type])
                        defer delete(name)
                        fmt.sbprintf(sb, "%s :: #type proc %q (", name, calling_conv_name(info.calling_conv))
                        for decl, i in info.param_decls {
                            type_name := eval_type_name(decl, emit_opts.cases[.Type])
                            defer delete(type_name)
                            fmt.sbprintf(sb, "%s", type_name)
                            if i + 1 < len(info.param_decls) do strings.write_string(sb, ", ")
                        }
                        strings.write_byte(sb, ')')
                        return_type_name := eval_type_name(info.return_decl, emit_opts.cases[.Type])
                        defer delete(return_type_name)
                        if len(return_type_name) > 0 {
                            fmt.sbprintf(sb, " -> %s", return_type_name)
                        }
                        strings.write_string(sb, "\n")
                }
            case Pointer_Decl:
                // Nothing to print for pointer
            case Constant_Array_Decl:
                // Nothing to print for constant array
            case Alias_Decl:
                if comment, ok := decl.comment.?; ok do fmt.sbprintfln(sb, "%s", comment)
                underlying_type_name := eval_type_name(internal.underlying, emit_opts.cases[.Type])
                defer delete(underlying_type_name)
                if p := get_unknown_alias(internal.underlying); p != nil {
                    fmt.sbprintfln(sb, "%s :: %s", internal.name, underlying_type_name)
                } else {
                    name := parse_w_case(internal.name, emit_opts.cases[.Type])
                    defer delete(name)
                    fmt.sbprintfln(sb, "%s :: %s", name, underlying_type_name)
                }
            case Func_Decl:
                append(&funcs_to_emit, decl)
            case Unknown_Alias_Decl:
                if comment, ok := decl.comment.?; ok do fmt.sbprintfln(sb, "%s", comment)
                fmt.sbprintfln(sb, "%s :: %s", internal.name, internal.expr)
        }

    }
    foreign_import_expr: string
    switch &expr in emit_opts.foreign_import.expr {
        case Foreign_Import_Expr:
            foreign_import_expr = strings.clone(transmute(string)expr)
        case Foreign_Import_Path:
            foreign_import_expr = fmt.aprintf("foreign import %s %q", emit_opts.foreign_import.alias, transmute(string)expr)
    }
    fmt.sbprintfln(sb, "%s\nforeign %s", foreign_import_expr, emit_opts.foreign_import.alias)
    delete(foreign_import_expr)
    strings.write_string(sb, "{\n")
    for &func in funcs_to_emit {
        #partial switch &internal in func.variant {
            case Func_Decl:
                if comment, ok := func.comment.?; ok do fmt.sbprintfln(sb, "%s", comment)
                link_name := internal.name
                name: string
                {
                    active_name := internal.name
                    for &prefix in emit_opts.link_prefixes {
                        if strings.has_prefix(active_name, prefix) {
                            active_name = active_name[len(prefix):]
                            break
                        }
                    }
                    for &suffix in emit_opts.link_suffixes {
                        if strings.has_suffix(active_name, suffix) {
                            active_name = active_name[:len(active_name)-len(suffix)]
                            break
                        }
                    }
                    name = parse_w_case(active_name, emit_opts.cases[.Function])
                }
                defer delete(name)

                fmt.sbprintf(sb, "@(link_name=\"%s\") %s :: proc %q (", link_name, name, calling_conv_name(internal.calling_conv))
                for &param, i in internal.params {
                    type_name := eval_type_name(param.type, emit_opts.cases[.Type])
                    defer delete(type_name)
                    param_name := parse_w_case(param.name, emit_opts.cases[.Param])
                    defer delete(param_name)
                    fmt.sbprintf(sb, "%s: %s", param_name, type_name)
                    if value, has_default_value := param.default_value.?; has_default_value {
                        fmt.sbprint(sb, " =", value_to_any(value))
                    }
                    if i + 1 < len(internal.params) do strings.write_string(sb, ", ")
                }
                strings.write_byte(sb, ')')
                return_type_name := eval_type_name(internal.return_type, emit_opts.cases[.Type])
                defer delete(return_type_name)
                if len(return_type_name) > 0 {
                    fmt.sbprintf(sb, " -> %s", return_type_name)
                }
                strings.write_string(sb, " ---\n")
        }
    }
    strings.write_string(sb, "}\n")
    return strings.to_string(sb^)
}

emit_factory :: proc(factory: ^Factory, sb: ^strings.Builder, emit_opts := Emit_Options{}) -> string {
    fmt.sbprintfln(sb, "package %s", emit_opts.package_name)
    if header, ok := factory.header.?; ok do fmt.sbprintfln(sb, "%s", header)
    
    emit_factory_decls(&factory.decls, sb, emit_opts)

    if footer, ok := factory.footer.?; ok do fmt.sbprintfln(sb, "%s", footer)
    return strings.to_string(sb^)
}

emit_factory_decls_stdout :: proc(factory: ^Decl_Factory, emit_info := Emit_Options{}) {
    sb := strings.builder_make(0, len(factory.items)*16)
    defer strings.builder_destroy(&sb)
    fmt.print(emit_factory_decls(factory, &sb, emit_info))
}

emit_factory_stdout :: proc(factory: ^Factory, emit_info := Emit_Options{}) {
    sb := strings.builder_make(0, (len(factory.decls.items)*24)+32)
    defer strings.builder_destroy(&sb)
    fmt.print(emit_factory(factory, &sb, emit_info))
}
