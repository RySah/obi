package c_api_gen

import clang "libclang"

import "core:mem"
import "core:c"
import vmem "core:mem/virtual"
import "core:hash"
import "core:strings"

import "base:runtime"
import "base:intrinsics"

ID :: distinct uint

Value :: union #shared_nil {
    ^uint,
    ^int,
    ^u64,
    ^i64
}

Name_Value_Field :: struct {
    name: string,
    value: Value,
    comment: Maybe(string)
}

Name_Type_Field :: struct {
    name: string,
    type_id: ID,
    comment: Maybe(string)
}

Type_Enum :: struct {
    underlying_type_id: ID,
    name: string,
    fields: [dynamic]Name_Value_Field
}
make_type_enum :: proc(allocator := context.allocator) -> (e: Type_Enum, err: mem.Allocator_Error) #optional_allocator_error {
    context.allocator = allocator
    e.fields = make([dynamic]Name_Value_Field) or_return
    return e, nil
}
delete_type_enum :: proc(e: ^Type_Enum) -> mem.Allocator_Error {
    delete(e.fields) or_return
    return nil
}

Type_Record :: struct {
    name: string,
    fields: [dynamic]Name_Type_Field
}
make_type_record :: proc(allocator := context.allocator) -> (u: Type_Record, err: mem.Allocator_Error) #optional_allocator_error {
    context.allocator = allocator
    u.fields = make([dynamic]Name_Type_Field) or_return
    return u, nil   
}
delete_type_record :: proc(u: ^Type_Record) -> mem.Allocator_Error {
    delete(u.fields) or_return
    return nil
}

Type_Alias :: struct {
    type_id: ID,
    name_id: ID
}

Builtin_Type :: enum u16 {
    UINT8,
    INT8,
    UINT16,
    INT16,
    UINT32,
    INT32,
    UINT64,
    INT64,

    INT_LEAST8,
    UINT_LEAST8,
    INT_LEAST16,
    UINT_LEAST16,
    INT_LEAST32,
    UINT_LEAST32,
    INT_LEAST64,
    UINT_LEAST64,
    
    INT_FAST8,
    UINT_FAST8,
    INT_FAST16,
    UINT_FAST16,
    INT_FAST32,
    UINT_FAST32,
    INT_FAST64,
    UINT_FAST64,

    CHAR,
    SCHAR,
    SHORT,
    INT,
    LONG,
    LONGLONG,
    UCHAR,
    USHORT,
    UINT,
    ULONG,
    ULONGLONG,

    BOOL,

    SIZE,
    SSIZE,
    WCHAR,

    FLOAT,
    DOUBLE,
    COMPLEX_FLOAT,
    COMPLEX_DOUBLE,

    INTPTR,
    UINTPTR,
    PTRDIFF,

    INTMAX,
    UINTMAX,

    VA_LIST,

    FILE,

    VOID,

    INT128, 
    UINT128
}

Type_Pointer :: struct {
    underlying_type_id: ID
}

Type_Translation :: struct {
    name: string,
    extra_import: Maybe(string)
}

Builtin_Type_Translation_Map :: [Builtin_Type]Type_Translation

DEFAULT_BUILTIN_TYPE_MAP :: Builtin_Type_Translation_Map{
    .UINT8 = { name="c.uint8_t", extra_import="c" },
    .INT8 = { name="c.int8_t", extra_import="c" },
    .UINT16 = { name="c.uint16_t", extra_import="c" },
    .INT16 = { name="c.int16_t", extra_import="c" },
    .UINT32 = { name="c.uint32_t", extra_import="c" },
    .INT32 = { name="c.int32_t", extra_import="c" },
    .UINT64 = { name="c.uint64_t", extra_import="c" },
    .INT64 = { name="c.int64_t", extra_import="c" },
    
    .INT_LEAST8 = { name="c.int_least8_t", extra_import="c" },
    .UINT_LEAST8 = { name="c.uint_least8_t", extra_import="c" },
    .INT_LEAST16 = { name="c.int_least16_t", extra_import="c" },
    .UINT_LEAST16 = { name="c.uint_least16_t", extra_import="c" },
    .INT_LEAST32 = { name="c.int_least32_t", extra_import="c" },
    .UINT_LEAST32 = { name="c.uint_least32_t", extra_import="c" },
    .INT_LEAST64 = { name="c.int_least64_t", extra_import="c" },
    .UINT_LEAST64 = { name="c.uint_least64_t", extra_import="c" },

    .INT_FAST8 = { name="c.int_fast8_t", extra_import="c" },
    .UINT_FAST8 = { name="c.uint_fast8_t", extra_import="c" },
    .INT_FAST16 = { name="c.int_fast16_t", extra_import="c" },
    .UINT_FAST16 = { name="c.uint_fast16_t", extra_import="c" },
    .INT_FAST32 = { name="c.int_fast32_t", extra_import="c" },
    .UINT_FAST32 = { name="c.uint_fast32_t", extra_import="c" },
    .INT_FAST64 = { name="c.int_fast64_t", extra_import="c" },
    .UINT_FAST64 = { name="c.uint_fast64_t", extra_import="c" },

    .CHAR = { name="c.char", extra_import="c" },
    .SCHAR = { name="c.schar", extra_import="c" },
    .SHORT = { name="c.short", extra_import="c" },
    .INT = { name="c.int", extra_import="c" },
    .LONG = { name="c.long", extra_import="c" },
    .LONGLONG = { name="c.longlong", extra_import="c" },
    .UCHAR = { name="c.uchar", extra_import="c" },
    .USHORT = { name="c.ushort", extra_import="c" },
    .UINT = { name="c.uint", extra_import="c" },
    .ULONG = { name="c.ulong", extra_import="c" },
    .ULONGLONG = { name="c.ulonglong", extra_import="c" },

    .BOOL = { name="c.bool", extra_import="c" },

    .SIZE = { name="c.size_t", extra_import="c" },
    .SSIZE = { name="c.ssize_t", extra_import="c" },
    .WCHAR = { name="c.wchar_t", extra_import="c" },

    .FLOAT = { name="c.float", extra_import="c" },
    .DOUBLE = { name="c.double", extra_import="c" },
    .COMPLEX_FLOAT = { name="c.complex_float", extra_import="c" },
    .COMPLEX_DOUBLE = { name="c.complex_double", extra_import="c" },

    .INTPTR = { name="c.intptr_t", extra_import="c" },
    .UINTPTR = { name="c.uintptr_t", extra_import="c" },
    .PTRDIFF = { name="c.ptrdiff_t", extra_import="c" },

    .INTMAX = { name="c.intmax_t", extra_import="c" },
    .UINTMAX = { name="c.uintmax_t", extra_import="c" },

    .VA_LIST = { name="c.va_list", extra_import="c" },

    .FILE = { name="c.FILE", extra_import="c" },

    .VOID = { name="", extra_import=nil },

    .INT128 = { name="struct{a,b:u64}", extra_import=nil },
    .UINT128 = { name="struct{a,b:u64}", extra_import=nil }
}

Type_Object :: union {
    Type_Enum,
    Type_Record,
    Type_Alias,
    Builtin_Type,
    Type_Pointer
}

hash_type_object :: proc(t: ^Type_Object) -> (h: u64) {
    _hash_name_value_fields :: proc(fields: []Name_Value_Field) -> (h: u64) {
        h = _hash_integer(len(fields))
        for &field in fields {
            h ~= _hash_name_value_field(field)        
        }
        return h
    }
    _hash_name_value_field :: proc(field: Name_Value_Field) -> (h: u64) {
        h = hash.murmur64a(transmute([]byte)field.name)
        h ~= _hash_value(field.value)    
        return h
    }
    _hash_name_type_fields :: proc(fields: []Name_Type_Field) -> (h: u64) {
        h = _hash_integer(len(fields))
        for &field in fields {
            h ~= _hash_name_type_field(field)        
        }
        return h
    }
    _hash_name_type_field :: proc(field: Name_Type_Field) -> (h: u64) {
        h = hash.murmur64a(transmute([]byte)field.name)
        h ~= _hash_integer(field.type_id)
        return h
    }
    _hash_value :: proc(value: Value) -> (h: u64) {
        switch v in value {
            case ^uint: h = _hash_integer(v^)
            case ^int: h = _hash_integer(v^)
            case ^u64: h = _hash_integer(v^)
            case ^i64: h = _hash_integer(v^)
        }
        return h
    }
    _hash_integer :: proc(i: $T) -> u64 where intrinsics.type_is_integer(T) {
        i := i
        buf: [size_of(T)]byte
        mem.copy(raw_data(buf[:]), &i, size_of(T))
        return hash.murmur64a(buf[:])
    }

    switch &v in t {
         case Type_Enum:
            h = _hash_integer(1)
            h ~= _hash_name_value_fields(v.fields[:])
            h ~= hash.murmur64a(transmute([]byte)v.name)
            h ~= _hash_integer(v.underlying_type_id)
        case Type_Record:
            h = _hash_integer(2)
            h ~= _hash_name_type_fields(v.fields[:])
            h ~= hash.murmur64a(transmute([]byte)v.name)
        case Type_Alias:
            h = _hash_integer(4)
            h ~= _hash_integer(v.name_id)
            h ~= _hash_integer(v.type_id)
        case Builtin_Type:
            h = _hash_integer(5)
            h ~= u64(v)
        case Type_Pointer:
            h = _hash_integer(6)
            h ~= _hash_integer(v.underlying_type_id)
    }

    return h
}

Object :: struct {
    type: Type_Object,
    comment: Maybe(string)
}

hash_object :: #force_inline proc(o: ^Object) -> u64 {
    return hash_type_object(&o.type)
}

Object_Manager :: struct {
    // Allocator.
    allocator: mem.Allocator,
    // Current ID.
    curr_id: ID,
    // Arena used to store values.
    value_arena: vmem.Arena,
    // Object map.
    object_map: map[ID]Object,
    // Value map.
    value_map: map[ID]Value,
    // Builtin type translation map.
    builtin_type_translation_map: Builtin_Type_Translation_Map
}
make_object_manager :: proc(builtin_type_translation_map := DEFAULT_BUILTIN_TYPE_MAP, allocator := context.allocator) -> (om: Object_Manager, err: mem.Allocator_Error) #optional_allocator_error {
    om.allocator = allocator
    context.allocator = om.allocator
    //om.dyn_allocator = allocator
    vmem.arena_init_growing(&om.value_arena) or_return
    om.object_map = make(map[ID]Object)
    om.value_map = make(map[ID]Value)
    om.builtin_type_translation_map = builtin_type_translation_map
    return om, nil
}
delete_object_manager :: proc(om: ^Object_Manager) -> mem.Allocator_Error {
    vmem.arena_destroy(&om.value_arena)
    for k, &u in om.object_map {
        #partial switch &v in u.type {
            case Type_Enum:
                delete_type_enum(&v) or_return
            case Type_Record:
                delete_type_record(&v) or_return
        }
    }
    delete(om.object_map) or_return
    delete(om.value_map) or_return
    return nil
}
om_next_id :: proc(om: ^Object_Manager) -> (id: ID) {
    id = om.curr_id
    om.curr_id += 1
    return id
}
om_manage_value :: proc(
    om: ^Object_Manager, 
    v: $T
) -> (value: Value, err: mem.Allocator_Error) where intrinsics.type_is_variant_of(Value, ^T) #optional_allocator_error {
    context.allocator = vmem.arena_allocator(&om.value_arena)
    ptr := new(T) or_return
    ptr^ = v
    return ptr, nil
}
om_manage_object :: proc(om: ^Object_Manager, obj: Object) -> (id: ID) {
    id = om_next_id(om)
    om.object_map[id] = obj
    return id
}
om_resolve_object_id :: proc(om: ^Object_Manager, id: ID) -> (res: Maybe(ID)) {
    obj, found := om.object_map[id]
    if !found do return nil
    #partial switch &actual in obj.type {
        case Type_Alias:
            return om_resolve_object_id(om, actual.type_id)
        case:
            return id
    }
    return nil
}
om_find_object_id :: proc(om: ^Object_Manager, type: ^Type_Object) -> (res: Maybe(ID)) {
    for id, &o in om.object_map {
        if hash_object(&o) == hash_type_object(type) do return id
    }
    return nil
}
om_find_or_insert :: #force_inline proc(om: ^Object_Manager, type: ^Type_Object) -> (res: ID) {
    return om_find_object_id(om, type).? or_else om_manage_object(om, { type=type^, comment=nil })
}
OM_Walker_Proc :: #type proc(client_data: rawptr, id: ID, depth: int)
om_walk_object_id :: proc(om: ^Object_Manager, start_id: ID, client_data: rawptr, client_proc: OM_Walker_Proc) {
    depth := 0
    id := start_id
    for {
        obj, found := om.object_map[id]
        if !found {
            return
        }

        // Visit current object
        client_proc(client_data, id, depth)

        #partial switch &actual in obj.type {
        case Type_Alias:
            depth += 1
            id = actual.type_id
            continue
        case:
            return
        }
    }
}
om_resolve_object :: proc(om: ^Object_Manager, id: ID) -> (obj: ^Object) {
    maybe_res_id := om_resolve_object_id(om, id)
    if res_id, ok := maybe_res_id.?; ok {
        return om_get_object(om, res_id)
    } else {
        return nil
    }
}
// NOTE: Has no checks to ensure it exists
om_get_object :: #force_inline proc(om: ^Object_Manager, id: ID) -> (obj: ^Object) {
    return &om.object_map[id]
}
om_get_value :: proc(om: ^Object_Manager, id: ID) -> (value: Value) {
    ok: bool
    value, ok = om.value_map[id]
    if !ok do return nil
    return value
}

API_Gen_General_Error :: enum int {
    None,
    Null_Unit,
    Non_Builtin,
    No_Specialization,
    Object_Not_Found,
    Invalid_Object_Type,
    Invalid_Element_Type
}
API_Gen_Error :: union #shared_nil {
    API_Gen_General_Error,
    mem.Allocator_Error
}

API_Gen_Error_Handler :: struct {
    client_proc: #type proc(client_data: rawptr, err: API_Gen_Error, args: []any, caller_location := #caller_location),
    client_data: rawptr
}

API_Gen :: struct {
    om: Object_Manager,
    imports: [dynamic]string,
    handled_comment_source_ranges: [dynamic]#simd[2]c.uint,
    error_handler: API_Gen_Error_Handler,
    file_comment: Maybe(string)
}
make_api_gen :: proc(allocator := context.allocator) -> (a: API_Gen, err: mem.Allocator_Error) #optional_allocator_error {
    context.allocator = allocator
    a.om = make_object_manager() or_return
    a.imports = make([dynamic]string) or_return
    a.handled_comment_source_ranges = make([dynamic]#simd[2]c.uint)
    return a, nil
}
delete_api_gen :: proc(a: ^API_Gen) -> mem.Allocator_Error {
    delete_object_manager(&a.om) or_return
    delete(a.imports) or_return
    return nil
}
ag_error :: proc(a: ^API_Gen, err: API_Gen_Error, args: ..any, caller_location := #caller_location) {
    if a.error_handler.client_proc == nil do return
    a.error_handler.client_proc(a.error_handler.client_data, err, args, caller_location)
}
ag_assert :: proc(cond: bool, a: ^API_Gen, err: API_Gen_Error, args: ..any, caller_location := #caller_location) {
    if !cond do ag_error(a, err, ..args, caller_location=caller_location)
}

@(private) _type_kind_to_builtin :: proc "c" (kind: clang.Type_Kind) -> Maybe(Builtin_Type) {
    #partial switch kind {
        case .Void: return .VOID
        case .Bool: return .BOOL
        case .UChar: return .UCHAR
        case .Char16: return .UINT16
        case .Char32: return .UINT32
        case .UShort: return .USHORT
        case .UInt: return .UINT
        case .ULong: return .ULONG
        case .ULongLong: return .ULONGLONG
        case .Float128: fallthrough
        case .UInt128: return .UINT128
        case .Int128: return .INT128
        case .SChar: return .SCHAR
        case .WChar: return .WCHAR
        case .Short: return .SHORT
        case .Int: return .INT
        case .Long: return .LONG
        case .LongLong: return .LONGLONG
        case .Float: return .FLOAT
        case .Double: return .DOUBLE
        case .Float16: fallthrough
        case .Half: return .UINT16
    }
    return nil
}

@(private) _is_unsigned :: proc "contextless" (t: Builtin_Type) -> bool {
    #partial switch t {
        case .UINT8: fallthrough
        case .UINT16: fallthrough
        case .UINT32: fallthrough
        case .UINT64: fallthrough
        case .UINT_LEAST8: fallthrough
        case .UINT_LEAST16: fallthrough
        case .UINT_LEAST32: fallthrough
        case .UINT_LEAST64: fallthrough
        case .UINT_FAST8: fallthrough
        case .UINT_FAST16: fallthrough
        case .UINT_FAST32: fallthrough
        case .UINT_FAST64: fallthrough
        case .UCHAR: fallthrough
        case .USHORT: fallthrough
        case .UINT: fallthrough
        case .ULONG: fallthrough
        case .ULONGLONG: fallthrough
        case .SIZE: fallthrough
        case .UINTPTR: fallthrough
        case .UINTMAX: fallthrough
        case .UINT128: return true
        case: return false
    }
}

@(private) _resolve_type_object :: proc(a: ^API_Gen, t: clang.Type) -> Maybe(Type_Object) {
    if builtin_type, is_builtin := _type_kind_to_builtin(t.kind).?; is_builtin do return builtin_type
    #partial switch t.kind {
        case .Complex:
            elem_type := clang.getElementType(t)
            elem_builtin_type, is_builtin := _type_kind_to_builtin(elem_type.kind).?
            elem_type_spelling := clang.getTypeSpelling(elem_type)
            defer clang.disposeString(elem_type_spelling)
            elem_type_name := string(clang.getCString(elem_type_spelling))
            ag_assert(is_builtin, a, .Invalid_Element_Type, "Element type", elem_type_name, "cannot be specialized as an complex type")
            ag_assert(elem_builtin_type == .FLOAT || elem_builtin_type == .DOUBLE, a, .Invalid_Element_Type, "Element type", elem_type_name, "expected to be either a float or double")
            #partial switch elem_builtin_type {
                case .FLOAT: return Builtin_Type.COMPLEX_FLOAT
                case .DOUBLE: return Builtin_Type.COMPLEX_DOUBLE
            }
        case .Pointer:
            elem_type := clang.getPointeeType(t)
            elem_type_obj, resolved := _resolve_type_object(a, elem_type).?
            if !resolved do return nil
            elem_type_id := om_find_or_insert(&a.om, &elem_type_obj)
            return Type_Pointer{ underlying_type_id=elem_type_id }
        case .Record:
            spelling := clang.getTypeSpelling(t)
            defer clang.disposeString(spelling)
            name := string(clang.getCString(spelling))
            for id, &obj in a.om.object_map {
                #partial switch &v in obj.type {
                    case Type_Record:
                        if strings.compare(v.name, name) == 0 do return v
                    case Type_Alias:
                        if res_id, res_id_ok := om_resolve_object_id(&a.om, id).?; res_id_ok {
                            #partial switch &res_v in a.om.object_map[res_id].type {
                                case Type_Record:
                                    if strings.compare(res_v.name, name) == 0 do return res_v
                            }
                        }
                }
            }
        case .Enum:
            spelling := clang.getTypeSpelling(t)
            defer clang.disposeString(spelling)
            name := string(clang.getCString(spelling))
            for id, &obj in a.om.object_map {
                #partial switch &v in obj.type {
                    case Type_Enum:
                        if strings.compare(v.name, name) == 0 do return v
                }
            }
        case .Elaborated:
            return _resolve_type_object(a, clang.Type_getNamedType(t))
    }
    return nil
}

@(private) _is_forward_decl :: #force_inline proc "c" (cursor: clang.Cursor) -> bool {
    return clang.isCursorDefinition(cursor) == 0
}

@(private) _Enum_Decl_Visitor_Client_Data :: struct { a: ^API_Gen, id: ID, unsigned: bool }
@(private) _visit_enum_decl :: proc "c" (cursor, parent: clang.Cursor, client_data: clang.Client_Data) -> clang.Child_Visit_Result {
    context = runtime.default_context()
    
    client_data := transmute(^_Enum_Decl_Visitor_Client_Data)client_data
    
    api_gen := client_data.a

    obj := om_resolve_object(&api_gen.om, client_data.id)
    ag_assert(obj != nil, api_gen, .Object_Not_Found, "Failed to find the object under the ID", client_data.id)
    
    te, is_enum := &obj.type.(Type_Enum)
    ag_assert(is_enum, api_gen, .Invalid_Object_Type, "Expected type enum for the object", obj^)

    maybe_comment := _get_comment(api_gen, cursor)

    allocator_err: mem.Allocator_Error

    kind := clang.getCursorKind(cursor)
    if kind == .EnumConstantDecl {
        spelling := clang.getCursorSpelling(cursor)
        defer clang.disposeString(spelling)

        field: Name_Value_Field = ---
        field.name, allocator_err = _manage_string(api_gen, string(clang.getCString(spelling)))
        ag_assert(allocator_err == nil, api_gen, allocator_err, "Failed to clone spelling")
        if client_data.unsigned {
            value := clang.getEnumConstantDeclUnsignedValue(cursor)
            field.value, allocator_err = om_manage_value(&api_gen.om, value)
            ag_assert(allocator_err == nil, api_gen, allocator_err, "Failed to clone/manage value", value)
        } else {
            value := clang.getEnumConstantDeclValue(cursor)
            field.value, allocator_err = om_manage_value(&api_gen.om, value)
            ag_assert(allocator_err == nil, api_gen, allocator_err, "Failed to clone/manage value", value)
        }
        field.comment = maybe_comment

        append(&te.fields, field)
    }

    return .Continue
}

@(private) _Record_Decl_Visitor_Client_Data :: struct { a: ^API_Gen, id: ID }
@(private) _visit_record_decl :: proc "c" (cursor, parent: clang.Cursor, client_data: clang.Client_Data) -> clang.Child_Visit_Result {
    context = runtime.default_context()
    
    client_data := transmute(^_Record_Decl_Visitor_Client_Data)client_data
    
    api_gen := client_data.a

    obj := om_resolve_object(&api_gen.om, client_data.id)
    ag_assert(obj != nil, api_gen, .Object_Not_Found, "Failed to find the object under the ID", client_data.id)
    
    tu, is_union := &obj.type.(Type_Record)
    ag_assert(is_union, api_gen, .Invalid_Object_Type, "Expected type union/struct for the object", obj^)

    maybe_comment := _get_comment(api_gen, cursor)

    allocator_err: mem.Allocator_Error

    kind := clang.getCursorKind(cursor)
    if kind == .FieldDecl {
        spelling := clang.getCursorSpelling(cursor)
        defer clang.disposeString(spelling)
        type := clang.getCursorType(cursor)
        type_spelling := clang.getTypeSpelling(type)
        defer clang.disposeString(type_spelling)
        type_name := string(clang.getCString(type_spelling))

        field: Name_Type_Field = ---
        field.name, allocator_err = _manage_string(api_gen, string(clang.getCString(spelling)))
        ag_assert(allocator_err == nil, api_gen, allocator_err, "Failed to clone spelling")
        type_obj, type_obj_resolved := _resolve_type_object(api_gen, type).?
        ag_assert(type_obj_resolved, api_gen, .Object_Not_Found, "Could not find object", type_name)
        field.type_id = om_find_or_insert(&api_gen.om, &type_obj)
        field.comment = maybe_comment

        append(&tu.fields, field)
    }

    return .Continue
}

@(private) _visit_top :: proc "c" (cursor, parent: clang.Cursor, client_data: clang.Client_Data) -> clang.Child_Visit_Result {
    context = runtime.default_context()
    
    api_gen := transmute(^API_Gen)client_data
    
    maybe_comment := _get_comment(api_gen, cursor)

    allocator_err: mem.Allocator_Error = nil

    kind := clang.getCursorKind(cursor)
    #partial switch kind {
        case .EnumDecl:
            if _is_forward_decl(cursor) do return .Continue

            underlying_type := clang.getEnumDeclIntegerType(cursor)
            underlying_type_kind := underlying_type.kind

            maybe_underlying_builtin_type := _type_kind_to_builtin(underlying_type_kind)
            if underlying_builtin_type, underlying_builtin_type_ok := maybe_underlying_builtin_type.?; !underlying_builtin_type_ok {
                ag_error(api_gen, .Non_Builtin, "Failed to translate", underlying_type_kind)
            } else if underlying_builtin_type != .INT128 && underlying_builtin_type != .UINT128 {
                obj: ^Object
                te_id: ID
                {
                    temp_te: Type_Enum
                    temp_te, allocator_err = make_type_enum(api_gen.om.allocator)
                    ag_assert(allocator_err == nil, api_gen, allocator_err, "Failed to make enum")
                
                    te_id = om_manage_object(
                        &api_gen.om,
                        Object{ type=temp_te, comment=maybe_comment }
                    )

                    obj = om_get_object(&api_gen.om, te_id)
                }
                
                te, is_enum := &obj.type.(Type_Enum)
                ag_assert(is_enum, api_gen, .Invalid_Object_Type, "Expected type enum for the object", obj^)

                spelling := clang.getCursorSpelling(cursor)
                defer clang.disposeString(spelling)
                te.name, allocator_err = _manage_string(api_gen, string(clang.getCString(spelling)))
                ag_assert(allocator_err == nil, api_gen, allocator_err, "Failed to clone spelling")

                underlying_builtin_type_obj : Type_Object = underlying_builtin_type
                te.underlying_type_id = om_find_or_insert(&api_gen.om, &underlying_builtin_type_obj)
                
                enum_decl_client_data := _Enum_Decl_Visitor_Client_Data{
                    a = api_gen,
                    id = te_id,
                    unsigned=_is_unsigned(underlying_builtin_type)
                }
                clang.visitChildren(
                    cursor,
                    _visit_enum_decl,
                    &enum_decl_client_data
                )
            } else {
                ag_error(api_gen, .No_Specialization, "No specialization for", underlying_builtin_type)
            }

        case .StructDecl: fallthrough
        case .UnionDecl:
            if _is_forward_decl(cursor) do return .Continue

            obj: ^Object
            tr_id: ID
            {
                temp_tr: Type_Record
                temp_tr, allocator_err = make_type_record(api_gen.om.allocator)
                ag_assert(allocator_err == nil, api_gen, allocator_err, "Failed to make record")
            
                tr_id = om_manage_object(
                    &api_gen.om,
                    Object{ type=temp_tr, comment=maybe_comment }
                )

                obj = om_get_object(&api_gen.om, tr_id)
            }
            
            tu, is_record := &obj.type.(Type_Record)
            ag_assert(is_record, api_gen, .Invalid_Object_Type, "Expected type struct/union for the object", obj^)

            spelling := clang.getCursorSpelling(cursor)
            defer clang.disposeString(spelling)
            tu.name, allocator_err = _manage_string(api_gen, string(clang.getCString(spelling)))
            ag_assert(allocator_err == nil, api_gen, allocator_err, "Failed to clone spelling")

            record_decl_client_data := _Record_Decl_Visitor_Client_Data{
                a = api_gen,
                id = tr_id
            }
            clang.visitChildren(
                cursor,
                _visit_record_decl,
                &record_decl_client_data
            )

    }

    return .Recurse
}

@(private) _manage_string :: proc(a: ^API_Gen, v: string) -> (res: string, err: mem.Allocator_Error) #optional_allocator_error {
    context.allocator = vmem.arena_allocator(&a.om.value_arena)
    return strings.clone(v)
}

@(private) _get_comment :: proc(a: ^API_Gen, cursor: clang.Cursor) -> (ms: Maybe(string), err: mem.Allocator_Error) #optional_allocator_error {
    source_loc := clang.getCursorLocation(cursor)
    // Helps ignore comments from macros.
    if clang.Location_isFromMainFile(source_loc) == 0 do return nil, nil

    source_range := clang.Cursor_getCommentRange(cursor)
    // No comment to parse
    if clang.Range_isNull(source_range) != 0 do return nil, nil

    ser_source_range: #simd[2]c.uint = { source_range.begin_int_data, source_range.end_int_data }
    for &handled in a.handled_comment_source_ranges {
        if handled == ser_source_range do return nil, nil
    }
    append(&a.handled_comment_source_ranges, ser_source_range)

    raw_comment : clang.String = clang.Cursor_getRawCommentText(cursor)
    ms, err = _manage_string(a, string(clang.getCString(raw_comment)))
    return ms, err
}

ag_parse_cstring_path :: proc(a: ^API_Gen, path: cstring, cli_args: ..cstring) -> API_Gen_Error {
    modified_args := make([]cstring, len(cli_args)+2)
    defer delete(modified_args)
    modified_args[0] = "-fparse-all-comments" // Ensures all comments remain when parsing.
    modified_args[1] = "-Wdocumentation" // Improves doc-comment association quality
    copy_slice(modified_args[2:], cli_args)

    index : clang.Index = clang.createIndex(0, 0)
    unit : clang.Translation_Unit = clang.parseTranslationUnit(
        index,
        path,
        raw_data(modified_args), cast(c.int)len(modified_args),
        nil, 0,
        {
		    .DetailedPreprocessingRecord, // Keep macros.
		    .SkipFunctionBodies,
		    .KeepGoing, // Keep going on errors.
	    }
    )
    if unit == nil do return .Null_Unit
    defer {
        clang.disposeTranslationUnit(unit)
        clang.disposeIndex(index)
    }

    cursor: clang.Cursor = clang.getTranslationUnitCursor(unit)
    a.file_comment = _get_comment(a, cursor) or_return
    clang.visitChildren(
        cursor,
        _visit_top,
        a
    )

    return nil
}
