package bindgen_c

import gb ".."
import cu "clang_util"
import clang "clang_util/libclang"
import "core:strings"
import "core:mem"
import "core:c"
import "core:hash"
import "core:slice"
import "core:log"
import "core:fmt"
import "core:strconv"

import "base:runtime"

VERBOSE_LOG :: #config(VERBOSE, false)

Clang_Error :: cu.Error
Allocator_Error :: mem.Allocator_Error

Parser_Error :: union #shared_nil {
    Clang_Error,
    Allocator_Error
}

Type_Alias_Import :: struct {
    expr: string,
    
}

Parse_Options :: struct {
    // If true, the generated C code will include standard library headers.
    keep_stdlib: bool,
    // If true, comments from the original C code will be discarded in the generated code.    
    discard_comments: bool,
    // Additional flags to pass to the C parser. (Ensure they're consistent with whats available for clang)
    extra_flags: []string,
    // Alias map for typedef declarations. Given an typedef identifier (before any transformations) as an **key**, and an expression as its **value**
    // , the alias would be added to the result (if already existing -> replaced).
    // 
    // Some_Record_Or_Enum_Or_Function :: [NEW_CONTENT]
    //
    // **TIP**: Use `make_type_aliases(defaults=...)` to set this field rather than leaving it empty, to cleanup some names from the included C standard libaries if naming cases are changed during emission.
    type_aliases: []gb.Unknown_Alias_Decl,
    // If set, the main opaque type alias would have this name, otherwise, the name will be automatically generated.
    opaque_type_name: Maybe(string),
    // key=alias, value=import
    extra_imports: map[string]string
}

Default_Type_Alias :: enum u8 {
    None,
    // <stdint.h>
    Std_Int,
    // e.g. size_t, ptrdiff_t, intptr_t, take a look at `make_type_aliases` for full lists.
    Std_Core
}
Default_Type_Alias_Set :: bit_set[Default_Type_Alias]

Basic_Default_Type_Alias :: Default_Type_Alias_Set {
    .Std_Int,
    .Std_Core
} 

make_type_aliases :: proc(
    a: ..gb.Unknown_Alias_Decl, 
    allocator := context.allocator, 
    defaults := Basic_Default_Type_Alias
) -> (arr: []gb.Unknown_Alias_Decl, err: mem.Allocator_Error) #optional_allocator_error {
    context.allocator = allocator
    _STD_INT :: [?]gb.Unknown_Alias_Decl {
        { name="int8_t", expr="c.int8_t", replace_only=true },
        { name="int16_t", expr="c.int16_t", replace_only=true },
        { name="int32_t", expr="c.int32_t", replace_only=true },
        { name="int64_t", expr="c.int64_t", replace_only=true },
        { name="uint8_t", expr="c.uint8_t", replace_only=true },
        { name="uint16_t", expr="c.uint16_t", replace_only=true },
        { name="uint32_t", expr="c.uint32_t", replace_only=true },
        { name="uint64_t", expr="c.uint64_t", replace_only=true },
        { name="int_least8_t", expr="c.int_least8_t", replace_only=true },
        { name="int_least16_t", expr="c.int_least16_t", replace_only=true },
        { name="int_least32_t", expr="c.int_least32_t", replace_only=true },
        { name="int_least64_t", expr="c.int_least64_t", replace_only=true },
        { name="uint_least8_t", expr="c.uint_least8_t", replace_only=true },
        { name="uint_least16_t", expr="c.uint_least16_t", replace_only=true },
        { name="uint_least32_t", expr="c.uint_least32_t", replace_only=true },
        { name="uint_least64_t", expr="c.uint_least64_t", replace_only=true },
        { name="int_fast8_t", expr="c.int_fast8_t", replace_only=true },
        { name="int_fast16_t", expr="c.int_fast16_t", replace_only=true },
        { name="int_fast32_t", expr="c.int_fast32_t", replace_only=true },
        { name="int_fast64_t", expr="c.int_fast64_t", replace_only=true },
        { name="uint_fast8_t", expr="c.uint_fast8_t", replace_only=true },
        { name="uint_fast16_t", expr="c.uint_fast16_t", replace_only=true },
        { name="uint_fast32_t", expr="c.uint_fast32_t", replace_only=true },
        { name="uint_fast64_t", expr="c.uint_fast64_t", replace_only=true },
        { name="intmax_t", expr="c.intmax_t", replace_only=true },
        { name="uintmax_t", expr="c.uintmax_t", replace_only=true }
    }
    _STD_CORE :: [?]gb.Unknown_Alias_Decl {
        { name="size_t", expr="c.size_t", replace_only=true },
        { name="ssize_t", expr="c.ssize_t", replace_only=true },
        { name="ptrdiff_t", expr="c.ptrdiff_t", replace_only=true },
        { name="intptr_t", expr="c.intptr_t", replace_only=true },
        { name="uintptr_t", expr="c.uintptr_t", replace_only=true },
        { name="wchar_t", expr="c.wchar_t", replace_only=true }
    }

    extra_len := 0
    if .Std_Int in defaults do extra_len += len(_STD_INT)
    if .Std_Core in defaults do extra_len += len(_STD_CORE)
    
    arr = make([]gb.Unknown_Alias_Decl, len(a)+extra_len) or_return
    copy(arr, a)
    i := len(a)
    if .Std_Int in defaults {
        content := _STD_INT
        copy(arr[i:], content[:])
        i += len(_STD_INT)
    }
    if .Std_Core in defaults {
        content := _STD_CORE
        copy(arr[i:], content[:])
        i += len(_STD_CORE)
    }
    return arr, nil
}

Non_Base_Data :: struct {
    handled_comment_source_hash: [dynamic]u32,
    seen_usr: map[string]bool,
    resolving_usr: map[string]bool,
    last_loc: Maybe(runtime.Source_Code_Location),
    public_func_ptrs: [dynamic]^gb.Decl
}

make_non_base_data :: proc(allocator := context.allocator) -> (data: Non_Base_Data, err: Allocator_Error) #optional_allocator_error {
    log.info("Making non-base data ...")
    defer {
        if err == nil do log.infof("[DONE] %v", data)
        else do log.errorf("[FAIL] (%v) %v", err, data)
    }
    context.allocator = allocator
    data.handled_comment_source_hash = make([dynamic]u32, 0, 16) or_return
    data.seen_usr = make(map[string]bool)
    data.resolving_usr = make(map[string]bool)
    data.public_func_ptrs = make([dynamic]^gb.Decl, 0, 4) or_return
    return data, nil
}
destroy_non_base_data :: proc(data: ^Non_Base_Data) -> (err: Allocator_Error) {
    log.info("Destroying non-base data ...")
    //when VERBOSE_LOG do log.debugf("%#v", data)
    defer {
        if err == nil do log.infof("[DONE]")
        else do log.errorf("[FAIL]")
    }
    delete(data.handled_comment_source_hash) or_return
    delete(data.seen_usr) or_return
    delete(data.resolving_usr) or_return
    delete(data.public_func_ptrs) or_return
    return nil
}

get_comment :: proc(nonbase: ^Non_Base_Data, cursor: cu.Cursor, sm: ^cu.String_Manager) -> (comment: Maybe(string)) {
    log.infof("Trying to get comment from `%v` ...", cursor)
    defer {
        if comment == nil do log.info("[DONE] No comment to capture.")
        else {
            log.info("[DONE] Captured comment.")
            log.debugf("[DONE] %q", comment.?)
        }
    }
    source_range: cu.Source_Range
    comment, source_range = cu.Cursor_getComment(cursor, sm)
    b: [size_of(source_range.begin_int_data)+size_of(source_range.end_int_data)]byte
    mem.copy(raw_data(b[:]), &source_range.begin_int_data, size_of(source_range.begin_int_data))
    mem.copy(raw_data(b[size_of(source_range.begin_int_data):]), &source_range.end_int_data, size_of(source_range.end_int_data))
    h := hash.murmur32(b[:])
    if slice.contains(nonbase.handled_comment_source_hash[:], h) do return nil
    append(&nonbase.handled_comment_source_hash, h)
    return comment
}

is_unsigned :: proc(T: cu.Type) -> bool {
    #partial switch T.kind {
        case .UChar: fallthrough
        case .UShort: fallthrough
        case .UInt: fallthrough
        case .ULong: fallthrough
        case .ULongLong: fallthrough
        case .UInt128: return true
    }
    return false
}

is_valid_builtin :: proc(T: cu.Type) -> bool {
    #partial switch T.kind {
        case .Complex:
            ct := clang.getElementType(T)
            return ct.kind == .Float || ct.kind == .Double
        case .Void: fallthrough
        case .Bool: fallthrough
        case .UChar: fallthrough
        case .UShort: fallthrough
        case .UInt: fallthrough
        case .ULong: fallthrough
        case .ULongLong: fallthrough
        case .Char_S: fallthrough
        case .SChar: fallthrough
        case .WChar: fallthrough
        case .Short: fallthrough
        case .Int: fallthrough
        case .Long: fallthrough
        case .LongLong: fallthrough
        case .Float: fallthrough
        case .Double: return true
    }
    return false
}

parse_builtin_as_typeid :: proc(T: cu.Type) -> typeid {
    #partial switch T.kind {
        case .Complex:
            ct := clang.getElementType(T)
            #partial switch ct.kind {
                case .Float: return typeid_of(c.complex_float)
                case .Double: return typeid_of(c.complex_double)
            }
        case .Void: return typeid_of(gb.c_void)
        case .Bool: return typeid_of(c.bool)
        case .UChar: return typeid_of(c.uchar)
        case .UShort: return typeid_of(c.ushort)
        case .UInt: return typeid_of(c.uint)
        case .ULong: return typeid_of(c.ulong)
        case .ULongLong: return typeid_of(c.ulonglong)
        case .Char_S: return typeid_of(gb.c_char_s)
        case .SChar: return typeid_of(c.schar)
        case .WChar: return typeid_of(c.wchar_t)
        case .Short: return typeid_of(c.short)
        case .Int: return typeid_of(c.int)
        case .Long: return typeid_of(c.long)
        case .LongLong: return typeid_of(c.longlong)
        case .Float: return typeid_of(c.float)
        case .Double: return typeid_of(c.double)
    }
    unimplemented()
}

builtin_typeid_alias :: proc(T: typeid, allocator := context.allocator) -> (string, mem.Allocator_Error) #optional_allocator_error {
    context.allocator = allocator
    switch T {
        case gb.c_void: return strings.clone("/*void-placeholder*/")
        case gb.c_char_s: return strings.clone("/*char-placeholder*/")
        case c.complex_float: return strings.clone("c.complex_float")
        case c.complex_double: return strings.clone("c.complex_double")
        case c.bool: return strings.clone("c.bool")
        case c.uchar: return strings.clone("c.uchar")
        case c.ushort: return strings.clone("c.ushort")
        case c.uint: return strings.clone("c.uint")
        case c.ulong: return strings.clone("c.ulong")
        case c.ulonglong: return strings.clone("c.ulonglong")
        case c.char: return strings.clone("c.char")
        case c.schar: return strings.clone("c.schar")
        case c.wchar_t: return strings.clone("c.wchar_t")
        case c.short: return strings.clone("c.short")
        case c.int: return strings.clone("c.int")
        case c.long: return strings.clone("c.long")
        case c.longlong: return strings.clone("c.longlong")
        case c.float: return strings.clone("c.float")
        case c.double: return strings.clone("c.double")
    }
    unimplemented()
}

cx_calling_conv_to_calling_conv :: proc(cc: cu.Calling_Conv) -> Maybe(gb.Calling_Conv) {
    #partial switch cc {
        case .Default, .C, .AAPCS, .AAPCS_VFP, .X86_64Win64, .X86_64SysV:
            return .CDecl
        case .X86StdCall:
            return .StdCall
        case .X86FastCall:
            return .FastCall
        case:
            return nil
    }
}

DEFAULT_VISITOR_OPTIONS :: cu.Visitor_Options{
    skip_transparent_tag_typedefs=true
}

get_decl :: proc(factory: ^gb.Factory, T: cu.Type) -> (out_decl: ^gb.Decl, err: cu.Visitor_Error) {
    log.infof("Attempting to get declaration for `%v` ...", T)
    defer {
        if err == nil { when VERBOSE_LOG { log.infof("[DONE] Result: %#v", out_decl) } else { log.infof("[DONE] Attempting to get declaration.") } }
        else { log.errorf("[FAIL] (%v)", err) }
    }
    ident := is_valid_builtin(T) ? builtin_typeid_alias(parse_builtin_as_typeid(T)) or_return : strings.clone(T.ident) or_return
    defer delete(ident)
    for decl in factory.decls.items {
        decl_name := gb.get_name(decl)
        if strings.compare(decl_name, ident) == 0 do return decl, nil
    }
    return nil, nil
}

resolve_decl :: proc(factory: ^gb.Factory, T: cu.Type, sm: ^cu.String_Manager) -> (out_decl: ^gb.Decl, err: cu.Visitor_Error) {
    T := cu.Type_resolveElaborated(T, sm)

    log.infof("Attempting to resolve declaration for `%v` ...", T)
    defer {
        if err == nil { when VERBOSE_LOG { log.infof("[DONE] Result: %#v", out_decl) } else { log.infof("[DONE] Attempting to resolve declaration.") } }
        else { log.errorf("[FAIL] (%v)", err) }
    }
    nonbase := transmute(^Non_Base_Data)factory.nonbase_data
    
    out_decl = get_decl(factory, T) or_return
    if out_decl != nil do return out_decl, nil

    log.infof("Failed to find existing representations for the type. Creating one now.")

    if is_valid_builtin(T) {
        builtin_typeid := parse_builtin_as_typeid(T)
        builtin_info := gb.as_builtin_info(builtin_typeid)
        log.infof("`%v` identified as valid builtin type. (TID=%v, TI=%v)", T, builtin_typeid, builtin_info)
        out_decl = gb.make_decl(&factory.decls) or_return
        out_decl.variant = gb.Type_Decl {
            name=builtin_typeid_alias(builtin_typeid, gb.decl_factory_allocator(&factory.decls)) or_return,
            info=builtin_info,
            size=builtin_info.size,
            alignment=builtin_info.align
        }
        return out_decl, nil
    } else if T.kind == .Pointer {
        pointee_type := cu.getPointeeType(T, sm)
        pointee_decl := resolve_decl(factory, pointee_type, sm) or_return
        if pointee_decl == nil do return nil, nil
        out_decl = gb.make_decl(&factory.decls) or_return
        out_decl.variant = gb.Pointer_Decl {
            underlying=pointee_decl
        }
        return out_decl, nil
    } else if T.kind == .FunctionProto {
        return_type := cu.getResultType(T, sm)
        param_count := cu.getNumArgTypes(T)
        maybe_calling_conv := cx_calling_conv_to_calling_conv(cu.getFunctionTypeCallingConv(T))
        if calling_conv, ok := maybe_calling_conv.?; ok {
            info := gb.Func_Info {
                return_decl=resolve_decl(factory, return_type, sm) or_return,
                param_decls=make(
                    [dynamic]^gb.Decl, 
                    0, param_count, 
                    gb.decl_factory_allocator(&factory.decls)
                ) or_return,
                calling_conv=calling_conv
            }
            for i in 0..<cast(uint)param_count {
                param_type := cu.getArgType(T, i, sm)
                append(&info.param_decls, resolve_decl(factory, param_type, sm) or_return) or_return
            }
            out_decl = gb.make_decl(&factory.decls) or_return
            out_decl.variant = gb.Type_Decl {
                name=strings.clone(T.ident, gb.decl_factory_allocator(&factory.decls)) or_return,
                info=info,
                size=size_of(uintptr),
                alignment=align_of(uintptr)
            }
            // out_decl.privacy = .File_Private
            return out_decl, nil
        } else do return nil, nil
    } else if T.kind == .ConstantArray {
        elem_type := cu.getArrayElementType(T, sm)
        elem_decl := resolve_decl(factory, elem_type, sm) or_return
        if elem_decl == nil do return nil, nil
        out_decl = gb.make_decl(&factory.decls) or_return
        out_decl.variant = gb.Constant_Array_Decl {
            underlying=elem_decl,
            elem_count=cast(int)clang.getArraySize(T)
        }
        return out_decl, nil
    } else {
        decl_cursor := cu.getTypeDeclaration(T, sm)
        log.infof("Falling back to visit type declaration... %v", decl_cursor)

        usr_str: string
        usr := cu.getCursorUSR(decl_cursor)
        nil_usr_fl := cu.getCString(usr) == nil
        if !nil_usr_fl {
            usr_str = cu.getString(usr)
            fl, exists := nonbase.resolving_usr[usr_str]
            when VERBOSE_LOG do log.infof("Checking against USR string... (%q, can_visit=%t)", usr_str, !(exists && fl))
            if exists && fl {
                // Recursive reference, return placeholder or nil
                return nil, nil
            }
            nonbase.resolving_usr[usr_str] = true
        }
        defer if !nil_usr_fl do delete_key(&nonbase.resolving_usr, usr_str)

        // if seen, exists := nonbase.seen_usr[usr_str]; exists && seen {
        //     return get_decl(factory, T)
        // }

        log.infof("Visiting children ...")
        cu.visitChildren(decl_cursor, visit_type, sm, factory, DEFAULT_VISITOR_OPTIONS) or_return

        if !nil_usr_fl {
            when VERBOSE_LOG do log.infof("Setting the USR %q as seen.", usr_str)
            nonbase.seen_usr[usr_str] = true
        }

        return get_decl(factory, T)
    }
    return nil, nil
}

visit_type :: proc(cursor, parent: cu.Cursor, sm: ^cu.String_Manager, client_data: cu.Client_Data) -> (result: cu.Child_Visit_Result, err: cu.Visitor_Error) {
    log.infof("Visiting type ... (parent=%v, current=%v)", parent, cursor)
    defer {
        if err == nil do log.infof("[DONE] %v", result)
        else do log.errorf("[FAIL] (%v) %v", err, result)
    }

    //if strings.compare(cursor.ident, "payload") == 0 do log.infof("FOUND PAYLOAD FINALLY! %v", cursor)

    factory := transmute(^gb.Factory)client_data
    nonbase := transmute(^Non_Base_Data)factory.nonbase_data

    usr_str: string
    usr := cu.getCursorUSR(cursor)
    nil_usr_fl := cu.getCString(usr) == nil
    if !nil_usr_fl {
        usr_str = cu.getString(usr)
        fl, exists := nonbase.seen_usr[usr_str]
        when VERBOSE_LOG do log.infof("Checking against USR string... (%q, can_visit=%t)", usr_str, !(exists && fl))
        if exists && fl {
            return .Continue, nil
        }
    }

    kind := cu.getCursorKind(cursor)
    #partial switch kind {
        case .EnumDecl:
            if !cu.isCursorDefinition(cursor) do return .Continue, nil

            maybe_comment := get_comment(nonbase, cursor, sm)

            info := gb.Enum_Info{
                underlying_type=nil,
                fields=make([dynamic]gb.Name_Value_Field, gb.decl_factory_allocator(&factory.decls)) or_return
            }

            _Fields_Client_Data :: struct {
                factory: ^gb.Factory,
                fields: ^[dynamic]gb.Name_Value_Field,
                unsigned_fl: bool
            }

            type := cu.getCursorType(cursor, sm)
            underlying_type := cu.Type_resolve(cu.getEnumIntegerType(cursor, sm), sm)
            info.underlying_type = resolve_decl(factory, underlying_type, sm) or_return

            fields_client_data := _Fields_Client_Data{
                factory=factory,
                fields=&info.fields,
                unsigned_fl=is_unsigned(underlying_type)
            }
            cu.Type_visitEnumConstantDecls(
                type,
                proc(cursor: cu.Cursor, sm: ^cu.String_Manager, client_data: cu.Client_Data) -> (result: cu.Visitor_Result, err: cu.Visitor_Error) {
                    client_data := transmute(^_Fields_Client_Data)client_data
                    factory: ^gb.Factory = client_data.factory
                    fields: ^[dynamic]gb.Name_Value_Field = client_data.fields
                    unsigned_fl: bool = client_data.unsigned_fl

                    nvf: gb.Name_Value_Field
                    nvf.name = strings.clone(cursor.ident, gb.decl_factory_allocator(&factory.decls)) or_return
                    if unsigned_fl {
                        nvf.value = gb.to_value_from_clone(cu.getEnumConstantDeclUnsignedValue(cursor), gb.decl_factory_allocator(&factory.decls)) or_return
                    } else {
                        nvf.value = gb.to_value_from_clone(cu.getEnumConstantDeclValue(cursor), gb.decl_factory_allocator(&factory.decls)) or_return
                    }
                    log.infof("Parsed enum constant declaration: %v", nvf)
                    append(fields, nvf) or_return

                    return .Continue, nil
                },
                sm,
                &fields_client_data,
                options=DEFAULT_VISITOR_OPTIONS
            ) or_return

            out_decl := gb.make_decl(&factory.decls) or_return
            out_decl.variant = gb.Type_Decl {
                name=strings.clone(cursor.ident, gb.decl_factory_allocator(&factory.decls)) or_return,
                info=info,
                size=cu.Type_getSizeOf(type),
                alignment=cu.Type_getAlignOf(type)
            }
            if comment, ok := maybe_comment.?; ok do out_decl.comment = strings.clone(comment, gb.decl_factory_allocator(&factory.decls)) or_return

            when VERBOSE_LOG {
                log.infof("Parsed enum: %#v", out_decl)
            } else {
                log.infof("Parsed enum: %q", cursor.ident)
            }

            if !nil_usr_fl {
                when VERBOSE_LOG do log.infof("Setting the USR %q as seen.", usr_str)
                nonbase.seen_usr[usr_str] = true
            }

        case .StructDecl: fallthrough
        case .UnionDecl:
            if !cu.isCursorDefinition(cursor) do return .Continue, nil

            maybe_comment := get_comment(nonbase, cursor, sm)
            info := gb.Record_Info{
                fields=make([dynamic]gb.Name_Type_Field, gb.decl_factory_allocator(&factory.decls)) or_return
            }

            _Fields_Client_Data :: struct {
                factory: ^gb.Factory,
                fields: ^[dynamic]gb.Name_Type_Field
            }

            type := cu.getCursorType(cursor, sm)

            fields_client_data := _Fields_Client_Data{
                factory=factory,
                fields=&info.fields
            }
            cu.visitChildren(
                cursor,
                proc(cursor, parent: cu.Cursor, sm: ^cu.String_Manager, client_data: cu.Client_Data) -> (result: cu.Child_Visit_Result, err: cu.Error) {
                    client_data := transmute(^_Fields_Client_Data)client_data
                    factory: ^gb.Factory = client_data.factory
                    fields: ^[dynamic]gb.Name_Type_Field = client_data.fields

                    kind := cu.getCursorKind(cursor)
                    #partial switch kind {
                        case .FieldDecl:
                            ntf: gb.Name_Type_Field
                            ntf.name = strings.clone(cursor.ident, gb.decl_factory_allocator(&factory.decls)) or_return
                            type := cu.getCursorType(cursor, sm)
                            log.infof("Resolving type for field (%q: %s).", ntf.name, type.ident)
                            ntf.type = resolve_decl(factory, type, sm) or_return
                            log.infof("Parsed record field declaration: %v", ntf)
                            append(fields, ntf) or_return
                        
                        case .TypedefDecl: fallthrough
                        case .StructDecl: fallthrough
                        case .UnionDecl: fallthrough
                        case .EnumDecl: 
                            log.infof("Identified nested type %q, visiting then assigning to field %q.", cursor.ident, cursor.ident)
                            exit_by_break := cu.visitChildren(
                                parent, 
                                visit_type, 
                                sm, 
                                factory, 
                                options=DEFAULT_VISITOR_OPTIONS
                            ) or_return
                            if exit_by_break do return .Break, nil

                    }
                    return .Continue, nil
                },
                sm,
                &fields_client_data,
                options=DEFAULT_VISITOR_OPTIONS
            )
            
            out_decl := gb.make_decl(&factory.decls) or_return
            if kind == .UnionDecl {
                out_decl.variant = gb.Type_Decl {
                    name=strings.clone(cursor.ident, gb.decl_factory_allocator(&factory.decls)) or_return,
                    info=gb.as_union_info(info),
                    size=cu.Type_getSizeOf(type),
                    alignment=cu.Type_getAlignOf(type)
                }
            } else {
                out_decl.variant = gb.Type_Decl {
                    name=strings.clone(cursor.ident, gb.decl_factory_allocator(&factory.decls)) or_return,
                    info=gb.as_struct_info(info),
                    size=cu.Type_getSizeOf(type),
                    alignment=cu.Type_getAlignOf(type)
                }
            }
            if comment, ok := maybe_comment.?; ok do out_decl.comment = strings.clone(comment, gb.decl_factory_allocator(&factory.decls)) or_return

            when VERBOSE_LOG {
                log.infof("Parsed record: %#v", out_decl)
            } else {
                log.infof("Parsed record: %q", cursor.ident)
            }

            if !nil_usr_fl {
                when VERBOSE_LOG do log.infof("Setting the USR %q as seen.", usr_str)
                nonbase.seen_usr[cu.getString(usr)] = true
            }

        case .TypedefDecl:
            if cu.Cursor_isTypedefOpaque(cursor) {
                builtin_info := gb.as_builtin_info_comptime(gb.c_opaque)
                underlying := gb.make_decl(&factory.decls) or_return
                underlying.variant = gb.Type_Decl {
                    name=strings.clone("/*opaque-placeholder*/", gb.decl_factory_allocator(&factory.decls)) or_return,
                    info=builtin_info,
                    size=builtin_info.size,
                    alignment=builtin_info.align
                }

                maybe_comment := get_comment(nonbase, cursor, sm)

                out_decl := gb.make_decl(&factory.decls) or_return
                out_decl.variant = gb.Alias_Decl {
                    name=strings.clone(cursor.ident, gb.decl_factory_allocator(&factory.decls)) or_return,
                    underlying=underlying
                }
                if comment, ok := maybe_comment.?; ok do out_decl.comment = strings.clone(comment, gb.decl_factory_allocator(&factory.decls)) or_return
                
                when VERBOSE_LOG {
                    log.infof("Parsed opaque typedef: %#v", out_decl)
                } else {
                    log.infof("Parsed opaqeue typedef: %q", cursor.ident)
                }

                if !nil_usr_fl {
                    when VERBOSE_LOG do log.infof("Setting the USR %q as seen.", usr_str)
                    nonbase.seen_usr[cu.getString(usr)] = true
                }
                
                return .Continue, nil
            }

            if !cu.isCursorDefinition(cursor) do return .Continue, nil

            maybe_comment := get_comment(nonbase, cursor, sm)

            underlying_type := cu.getTypedefDeclUnderlyingType(cursor, sm)

            underlying_decl: ^gb.Decl
            underlying_decl = resolve_decl(factory, underlying_type, sm) or_return
            
            out_decl := gb.make_decl(&factory.decls) or_return
            out_decl.variant = gb.Alias_Decl {
                name=strings.clone(cursor.ident, gb.decl_factory_allocator(&factory.decls)) or_return,
                underlying=underlying_decl
            }
            if comment, ok := maybe_comment.?; ok do out_decl.comment = strings.clone(comment, gb.decl_factory_allocator(&factory.decls)) or_return

            when VERBOSE_LOG {
                log.infof("Parsed typedef: %#v", out_decl)
            } else {
                log.infof("Parsed typedef: %q", cursor.ident)
            }

            if !nil_usr_fl {
                when VERBOSE_LOG do log.infof("Setting the USR %q as seen.", usr_str)
                nonbase.seen_usr[cu.getString(usr)] = true
            }
    
        case .FunctionDecl:
            //if !cu.isCursorDefinition(cursor) do return .Continue, nil

            maybe_comment := get_comment(nonbase, cursor, sm)

            type := cu.getCursorType(cursor, sm)
            result_type := cu.getResultType(type, sm)

            maybe_calling_conv := cx_calling_conv_to_calling_conv(cu.getFunctionTypeCallingConv(type))

            if calling_conv, ok := maybe_calling_conv.?; ok {
                func_decl := gb.Func_Decl {
                    name=strings.clone(cursor.ident, gb.decl_factory_allocator(&factory.decls)) or_return,
                    return_type=resolve_decl(factory, result_type, sm) or_return,
                    params=make([dynamic]gb.Param, gb.decl_factory_allocator(&factory.decls)) or_return,
                    calling_conv=calling_conv
                }

                _Params_Client_Data :: struct {
                    factory: ^gb.Factory,
                    params: ^[dynamic]gb.Param
                }

                params_client_data := _Params_Client_Data{
                    factory=factory,
                    params=&func_decl.params
                }

                cu.Cursor_visitFunctionParams(
                    cursor,
                    proc(cursor: cu.Cursor, sm: ^cu.String_Manager, client_data: cu.Client_Data) -> (result: cu.Visitor_Result, err: cu.Visitor_Error) {
                        client_data := transmute(^_Params_Client_Data)client_data
                        factory: ^gb.Factory = client_data.factory
                        params: ^[dynamic]gb.Param = client_data.params

                        type := cu.getCursorType(cursor, sm)

                        param: gb.Param
                        param.default_value = nil
                        param.name = strings.clone(cursor.ident, gb.decl_factory_allocator(&factory.decls)) or_return
                        param.type = resolve_decl(factory, type, sm) or_return 
                        log.infof("Parsed parameter declaration: %v", param)
                        append(params, param) or_return
                        
                        return .Continue, nil
                    },
                    sm,
                    &params_client_data,
                    options=DEFAULT_VISITOR_OPTIONS
                ) or_return

                out_decl := gb.make_decl(&factory.decls) or_return
                out_decl.variant = func_decl
                if comment, ok := maybe_comment.?; ok do out_decl.comment = strings.clone(comment, gb.decl_factory_allocator(&factory.decls)) or_return

                when VERBOSE_LOG {
                    log.infof("Parsed function: %#v", out_decl)
                } else {
                    log.infof("Parsed function: %q", cursor.ident)
                }

                if !nil_usr_fl {
                    when VERBOSE_LOG do log.infof("Setting the USR %q as seen.", usr_str)
                    nonbase.seen_usr[cu.getString(usr)] = true
                }
            }
        
    }

    return .Continue, nil
}

parse :: proc(factory: ^gb.Factory, path: string, options := Parse_Options{}) -> Parser_Error {
    extra_extra_flags_count := 
        cast(int)cast(b32)!options.keep_stdlib + // 1 if not keeping stdlib "-nostdinc"
        (cast(int)cast(b32)!options.discard_comments * 2) // 2 if keeping comments "-fparse-all-comments" and "-Wdocumentation"
    extra_flags := make([]string, 
        len(options.extra_flags) + extra_extra_flags_count + 1 /*For "-xc"*/
    )
    i := 0
    extra_flags[i] = strings.clone("-xc") or_return
    i += 1
    if !options.keep_stdlib {
        extra_flags[i] = strings.clone("-nostdinc") or_return
        i += 1
    }
    if !options.discard_comments {
        extra_flags[i] = strings.clone("-fparse-all-comments") or_return
        i += 1
        extra_flags[i] = strings.clone("-Wdocumentation") or_return
        i += 1
    }
    for flag in options.extra_flags {
        extra_flags[i] = strings.clone(flag) or_return
        i += 1
    }
    defer {
        for &flag in extra_flags do delete(flag)
        delete(extra_flags)
    }

    _DEFAULT_UNIT_FLAGS : cu.Translation_Unit_Flags : {
        .SkipFunctionBodies,
        .KeepGoing, // Keep going on errors.
    }

    index: cu.Index = cu.createIndex(0, 0)
    unit: cu.Translation_Unit
    cu.parseTranslationUnit(
        index, 
        path,
        extra_flags,
        {},
        _DEFAULT_UNIT_FLAGS,
        &unit
    ) or_return
    defer {
        cu.disposeTranslationUnit(unit)
        cu.disposeIndex(index)
    }

    nonbase: ^Non_Base_Data = new(Non_Base_Data) or_return
    nonbase^ = make_non_base_data() or_return
    defer {
        destroy_non_base_data(nonbase)
        free(nonbase)
    }

    factory.last_source_location = nonbase.last_loc
    factory.nonbase_data = nonbase

    sm: cu.String_Manager
    cu.stringManagerInit(&sm) or_return
    defer cu.stringManagerDestroy(&sm)

    header_sb := strings.builder_make() or_return
    defer {
        if strings.builder_len(header_sb) > 0 do factory.header = strings.clone(strings.to_string(header_sb), factory.allocator)
        strings.builder_destroy(&header_sb)
    }
    factory_sb := strings.builder_make() or_return
    defer {
        if strings.builder_len(factory_sb) > 0 do factory.footer = strings.clone(strings.to_string(factory_sb), factory.allocator)
        strings.builder_destroy(&factory_sb)
    }

    strings.write_string(&header_sb, "import \"core:c\"\n")
    for alias, &import_ in options.extra_imports {
        fmt.sbprintfln(&header_sb, "import %s %q", alias, import_)
    }

    cursor := cu.getTranslationUnitCursor(unit, &sm)
    maybe_file_comment := get_comment(nonbase, cursor, &sm)
    if file_comment, ok := maybe_file_comment.?; ok {
        strings.write_string(&header_sb, file_comment)
    }
    cu.visitChildren(
        cursor,
        visit_type,
        &sm,
        factory,
        options=DEFAULT_VISITOR_OPTIONS
    ) or_return
    if options.keep_stdlib {
        valid_decls := make([dynamic]^gb.Decl, 0, len(factory.decls.items)) or_return
        defer delete(valid_decls)

        {
            _Non_Std_Info :: struct {
                record_and_enums: [dynamic]string,
                funcs: [dynamic]string
            }
            non_std_info := _Non_Std_Info{
                record_and_enums=make([dynamic]string, 0, len(factory.decls.items)) or_return,
                funcs=make([dynamic]string, 0, 16) or_return
            }
            defer {
                delete(non_std_info.record_and_enums)
                delete(non_std_info.funcs)
            }

            {
                nonstd_extra_flags := make([]string, len(extra_flags)+1) or_return
                defer delete(nonstd_extra_flags)
                copy(nonstd_extra_flags[:], extra_flags)
                nonstd_extra_flags[len(nonstd_extra_flags)-1] = "-nostdinc"
                nonstd_index: cu.Index = cu.createIndex(0, 0)
                nonstd_unit: cu.Translation_Unit
                cu.parseTranslationUnit(
                    nonstd_index, 
                    path,
                    nonstd_extra_flags[:],
                    {},
                    _DEFAULT_UNIT_FLAGS,
                    &nonstd_unit
                ) or_return
                defer {
                    cu.disposeTranslationUnit(nonstd_unit)
                    cu.disposeIndex(nonstd_index)
                }
                nonstd_cursor := cu.getTranslationUnitCursor(nonstd_unit, &sm)
                cu.visitChildren(
                    nonstd_cursor,
                    proc(cursor, parent: cu.Cursor, sm: ^cu.String_Manager, client_data: cu.Client_Data) -> (result: cu.Child_Visit_Result, err: cu.Visitor_Error) {
                        client_data := transmute(^_Non_Std_Info)client_data
                        kind := cu.getCursorKind(cursor)
                        #partial switch kind {
                            case .TypedefDecl: fallthrough
                            case .StructDecl: fallthrough
                            case .UnionDecl: fallthrough
                            case .EnumDecl:
                                append(&client_data.record_and_enums, cursor.ident)
                            case .FunctionDecl:
                                append(&client_data.funcs, cursor.ident)
                        }
                        return .Continue, nil
                    },
                    &sm,
                    &non_std_info,
                    options=DEFAULT_VISITOR_OPTIONS
                ) or_return
            }

            _append_tree :: proc(out: ^[dynamic]^gb.Decl, decl: ^gb.Decl) {
                if decl != nil do switch &internal in decl.variant {
                    case gb.Type_Decl:
                        switch &info in internal.info {
                            case gb.Struct_Info:
                                for &field in info.fields {
                                    _append_tree(out, field.type)
                                }
                            case gb.Union_Info:
                                for &field in info.fields {
                                    _append_tree(out, field.type)
                                }
                            case gb.Enum_Info:
                                _append_tree(out, info.underlying_type)
                            case gb.Builtin_Info:
                                // Nothing to append
                            case gb.Func_Info:
                                _append_tree(out, info.return_decl)
                                for decl in info.param_decls do _append_tree(out, decl)
                        }
                    case gb.Func_Decl:
                        _append_tree(out, internal.return_type)
                        for &param in internal.params {
                            _append_tree(out, param.type)
                        }
                    case gb.Alias_Decl:
                        _append_tree(out, internal.underlying)
                    case gb.Pointer_Decl:
                        _append_tree(out, internal.underlying)
                    case gb.Unknown_Alias_Decl:
                        // Nothing to append
                    case gb.Constant_Array_Decl:
                        _append_tree(out, internal.underlying)
                }
                append(out, decl)
            }

            for ident in non_std_info.record_and_enums {
                for decl in factory.decls.items {
                    if decl == nil {
                        _append_tree(&valid_decls, nil)
                    } else if _, is_func := decl.variant.(gb.Func_Decl); !is_func {
                        decl_name := gb.get_name(decl)
                        if strings.compare(ident, decl_name) == 0 {
                            _append_tree(&valid_decls, decl)
                            break
                        }
                    }
                }
            }

            for ident in non_std_info.funcs {
                for decl in factory.decls.items {
                    if func, is_func := decl.variant.(gb.Func_Decl); is_func {
                        if strings.compare(ident, func.name) == 0 {
                            _append_tree(&valid_decls, decl)
                            break
                        }
                    }
                }
            }

        }

        opaque_indexes := make([dynamic]int, 0, 8) or_return
        defer delete(opaque_indexes)

        for alias in options.type_aliases {
            found := false
            i := 0
            for &decl in valid_decls {
                if decl == nil do continue
                decl_name := gb.get_name(decl)
                if decl_name == alias.name {
                    found = true
                    break
                }
                i += 1
            }
            owned_alias: gb.Unknown_Alias_Decl
            owned_alias.name = strings.clone(alias.name, gb.decl_factory_allocator(&factory.decls)) or_return
            owned_alias.expr = strings.clone(alias.expr, gb.decl_factory_allocator(&factory.decls)) or_return
            if found {
                valid_decls[i].variant = owned_alias 
            } else if !alias.replace_only {
                decl := gb.make_decl(&factory.decls, as_item=false) or_return
                decl.variant = owned_alias
                append(&valid_decls, decl) or_return
            }
        }

        opaque_type_alias: string
        if alias, alias_ok := options.opaque_type_name.?; alias_ok {
            opaque_type_alias = strings.clone(alias) or_return
        } else {
            decl_names := make([]string, len(valid_decls)) or_return
            defer delete(decl_names)
            for &decl, i in valid_decls {
                if decl == nil do continue
                decl_name := gb.get_name(decl)
                decl_names[i] = decl_name
            }

            BASE_NAME :: "BIND_GEN_OPAQUE_T"
            
            counter: u64 = 0
            str_buf: [size_of(counter)*8]byte = ---
            opaque_type_alias = strings.clone(BASE_NAME) or_return
            for slice.contains(decl_names[:], opaque_type_alias) {
                delete(opaque_type_alias)
                opaque_type_alias = strings.concatenate({BASE_NAME, strconv.write_uint(str_buf[:], counter, 16) }) or_return
                counter += 1
            }
        }
        defer delete(opaque_type_alias)

        opaque_decl := gb.make_decl(&factory.decls, as_item=false) or_return
        opaque_decl.variant = gb.Unknown_Alias_Decl{
            name=strings.clone(opaque_type_alias, gb.decl_factory_allocator(&factory.decls)) or_return,
            expr=strings.clone("distinct rawptr", gb.decl_factory_allocator(&factory.decls)) or_return
        }
        opaque_decl.privacy = .File_Private
        append(&valid_decls, opaque_decl) or_return

        pointer_decls := make([dynamic]^gb.Decl) or_return
        for decl in valid_decls {
            if decl == nil do continue
            #partial switch &internal in decl.variant {
                case gb.Alias_Decl:
                    if internal.underlying == nil do continue
                    if type_decl, is_type_decl := internal.underlying.variant.(gb.Type_Decl); is_type_decl {
                        if builtin_info, has_builtin_info := type_decl.info.(gb.Builtin_Info); has_builtin_info {
                            if builtin_info.id == typeid_of(gb.c_opaque) {
                                // Overall alias is opaque.
                                internal.underlying = opaque_decl
                                continue
                            }
                        }
                    }
                case gb.Pointer_Decl:
                    append(&pointer_decls, decl)
            }
                
        }
        //for &decl in valid_decls do _try_decr_func_ptr_depth(&decl)

        // Handling function pointers.
        {
            defer delete(pointer_decls)
            _is_child :: proc(target: ^gb.Decl, arr: []^gb.Decl) -> bool {
                for &decl in arr {
                    if pd, is_pd := &decl.variant.(gb.Pointer_Decl); is_pd {
                        if pd.underlying == target do return true 
                    } else do return false
                }
                return false
            }
            _find_deepest :: proc(root: ^gb.Decl) -> ^gb.Decl {
                _break_cond :: proc(d: ^gb.Decl) -> bool {
                    if d == nil do return true
                    if pointer_decl, is_pointer_decl := d.variant.(gb.Pointer_Decl); is_pointer_decl {
                        if type_decl, is_type_decl := gb.get_base(pointer_decl.underlying).variant.(gb.Type_Decl); is_type_decl {
                            if func_info, has_func_info := type_decl.info.(gb.Func_Info); has_func_info {
                                return true
                            }
                        }
                    } else do return true // No other children to search
                    return false
                }
                current := root
                for !_break_cond(current) {
                    current = current.variant.(gb.Pointer_Decl).underlying
                }
                return current
            }
            _rem_deepest_from_roots :: proc(arr: []^gb.Decl, to_remove: ^[dynamic]^gb.Decl) {
                to_upd := make([dynamic]^gb.Decl)
                defer delete(to_upd)
                for target in arr {
                    if !_is_child(target, arr) {
                        deepest := _find_deepest(target)
                        if pointer_decl, is_pointer_decl := deepest.variant.(gb.Pointer_Decl); is_pointer_decl {
                            if type_decl, is_type_decl := pointer_decl.underlying.variant.(gb.Type_Decl); is_type_decl {
                                if func_info, has_func_info := type_decl.info.(gb.Func_Info); has_func_info {
                                    if !slice.contains(to_upd[:], deepest) do append(&to_upd, deepest)
                                    append(to_remove, pointer_decl.underlying)
                                }
                            }
                        }
                    }
                }
                for &decl in to_upd {
                    if pointer_decl, is_pointer_decl := decl.variant.(gb.Pointer_Decl); is_pointer_decl {
                        if type_decl, is_type_decl := pointer_decl.underlying.variant.(gb.Type_Decl); is_type_decl {
                            if func_info, has_func_info := type_decl.info.(gb.Func_Info); has_func_info {
                                decl.variant = pointer_decl.underlying.variant
                                decl.privacy = pointer_decl.underlying.privacy
                                decl.comment = pointer_decl.underlying.comment
                            }
                        }
                    }
                }
            }
            to_remove := make([dynamic]^gb.Decl) or_return
            defer delete(to_remove)
            _rem_deepest_from_roots(valid_decls[:], &to_remove)
            write := 0
            for decl in valid_decls {
                if !slice.contains(to_remove[:], decl) {
                    valid_decls[write] = decl
                    write += 1
                }
            }
            remove_range(&valid_decls, write, len(valid_decls))
        }

        clear(&factory.decls.items)
        for decl in valid_decls {
            if decl == nil do continue
            if slice.contains(factory.decls.items[:], decl) do continue
            if type_decl, is_type_decl := decl.variant.(gb.Type_Decl); is_type_decl {
                if builtin_info, has_builtin_info := type_decl.info.(gb.Builtin_Info); has_builtin_info {
                    if builtin_info.id == typeid_of(gb.c_opaque) {
                        continue // Skipping old opaque types
                    }
                }
            }
            append(&factory.decls.items, decl)
        }

    }
    
    return nil
}
