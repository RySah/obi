package clang_util

import clang "libclang"

import "core:strings"
import "core:mem"
import "core:c"
import "core:unicode/utf8"
import "core:hash"
import vmem "core:mem/virtual"
import "core:fmt"
import "core:log"

import "base:runtime"
import "base:intrinsics"

String_Manager :: struct {
    using arena: vmem.Arena,
    cache_map: map[u32][dynamic]string,
    allocator: mem.Allocator
}

stringManagerAllocator :: vmem.arena_allocator
stringManagerInit :: proc(sm: ^String_Manager, allocator := context.allocator) -> (err: mem.Allocator_Error) {
    sm.allocator = allocator
    vmem.arena_init_growing(sm) or_return
    sm.cache_map = make(map[u32][dynamic]string, allocator)
    return nil
}
stringManagerDestroy :: proc(sm: ^String_Manager) -> (err: mem.Allocator_Error) {
    for k, dyn in sm.cache_map do delete(dyn) or_return
    delete(sm.cache_map) or_return
    vmem.arena_destroy(sm)
    return nil
}
stringManagerIntern :: proc(sm: ^String_Manager, s: string) -> (out: string, err: mem.Allocator_Error) #optional_allocator_error {
    h := hash.murmur32(transmute([]byte)s)

    bucket, bucket_exists := sm.cache_map[h]
    if bucket_exists {
        for interned in bucket {
            if strings.compare(interned, s) == 0 {
                return interned, nil
            }
        }
    }

    out = strings.clone(s, stringManagerAllocator(sm)) or_return
    if bucket_exists {
        append(&sm.cache_map[h], out) or_return
    } else {
        new_bucket := make([dynamic]string, sm.allocator) or_return
        append(&new_bucket, out) or_return
        sm.cache_map[h] = new_bucket
    }

    return out, nil
}

Error_Code :: clang.Error_Code
Cursor :: struct {
    using cl: clang.Cursor,
    // Spelling of the cursor thats cleaned up to be a valid identifier e.g. "enum EQ_Result" ->  "EQ_Result", "enum my::EQ_Result" -> "EQ_Result", "struct xxx::(unnamed at...)" -> "_xxx___unnamed_at____" 
    ident: string
}
Translation_Unit :: clang.Translation_Unit
Translation_Unit_Flag :: clang.Translation_Unit_Flag
Translation_Unit_Flags :: clang.Translation_Unit_Flags
Index :: clang.Index
Unsaved_File :: clang.Unsaved_File
String :: clang.String
Child_Visit_Result :: clang.Child_Visit_Result
Visitor_Result :: clang.Visitor_Result
Client_Data :: clang.Client_Data
Cursor_Kind :: clang.Cursor_Kind
Type_Kind :: clang.Type_Kind
Cursor_Visitor :: #type proc(cursor, parent: Cursor, sm: ^String_Manager, client_data: Client_Data) -> (Child_Visit_Result, Visitor_Error)
Field_Visitor :: #type proc(cursor: Cursor, sm: ^String_Manager, client_data: Client_Data) -> (Visitor_Result, Visitor_Error)
Type :: struct {
    using cl: clang.Type,
    // Spelling of the cursor thats cleaned up to be a valid identifier e.g. "enum EQ_Result" ->  "EQ_Result", "enum my::EQ_Result" -> "EQ_Result", "struct xxx::(unnamed at...)" -> "_xxx___unnamed_at____" 
    ident: string
}
Source_Range :: clang.Source_Range
Calling_Conv :: clang.Calling_Conv

Visitor_Options :: struct {
    /* If enabled, in the case both the tag and the alias are the same e.g.
       ```
       typedef enum EQ_Result {
           EQ_OK = 0,
           EQ_ERR_INVALID_ARGUMENT = -1,
           EQ_ERR_OUT_OF_MEMORY    = -2,
           EQ_ERR_QUEUE_FULL       = -3,
           EQ_ERR_QUEUE_EMPTY      = -4
       } EQ_Result;
       ```  
       The typedef cursor will automaticaly will be skipped in favor of the underlying decleration.
    */
    skip_transparent_tag_typedefs: bool
}

Error :: union #shared_nil {
    mem.Allocator_Error,
    Error_Code
}
Visitor_Error :: Error

asThisCursor :: proc(cursor: clang.Cursor, sm: ^String_Manager) -> (C: Cursor, err: mem.Allocator_Error) #optional_allocator_error {
    C.cl = cursor
    _cursor_cleanup(&C, sm) or_return
    return
}
asThisType :: proc(type: clang.Type, sm: ^String_Manager) -> (T: Type, err: mem.Allocator_Error) #optional_allocator_error {
    T.cl = type
    _type_cleanup(&T, sm) or_return
    return
}

equalCursors :: #force_inline proc "c" (a, b: Cursor) -> bool {
    return clang.equalCursors(a, b) != 0
}
getTypeDeclaration :: proc(T: Type, sm: ^String_Manager) -> Cursor {
    return asThisCursor(clang.getTypeDeclaration(T), sm)
}
getTypedefDeclUnderlyingType :: proc(C: Cursor, sm: ^String_Manager) -> (T: Type) {
    return asThisType(clang.getTypedefDeclUnderlyingType(C), sm)
}
getCursorKind :: clang.getCursorKind
Cursor_isTypedefOpaque :: proc(C: Cursor) -> bool {
    if getCursorKind(C) != .TypedefDecl do return false

    underlying := clang.getTypedefDeclUnderlyingType(C)
    underlying = clang.getCanonicalType(underlying)

    if underlying.kind != .Record do return false
    record_cursor := clang.getTypeDeclaration(underlying)

    if clang.Cursor_isNull(record_cursor) != 0 do return false

    k := getCursorKind(record_cursor)
    if k != .StructDecl && k != .UnionDecl do return false

    return clang.isCursorDefinition(record_cursor) == 0
}

Cursor_isTransparentTagTypedef :: proc(C: Cursor, sm: ^String_Manager) -> bool {
    if getCursorKind(C) != .TypedefDecl do return false
    typedef_type := getCursorType(C, sm)
    underlying_type := getTypedefDeclUnderlyingType(C, sm)
    return strings.compare(typedef_type.ident, underlying_type.ident) == 0 && !Cursor_isTypedefOpaque(C)
}
Type_isTransparentTagTypedef :: proc(T: Type, sm: ^String_Manager) -> bool {
    if T.kind != .Typedef do return false
    return Cursor_isTransparentTagTypedef(getTypeDeclaration(T, sm), sm)
}
getCursorType :: proc(C: Cursor, sm: ^String_Manager) -> (T: Type) {
    return asThisType(clang.getCursorType(C), sm)
}
disposeTranslationUnit :: clang.disposeTranslationUnit
disposeIndex :: clang.disposeIndex
disposeString :: clang.disposeString
getCString :: clang.getCString
getString :: #force_inline proc "c" (_string: String) -> string {
    return string(getCString(_string))
}
getTranslationUnitCursor :: proc(unit: Translation_Unit, sm: ^String_Manager) -> (C: Cursor) {
    return asThisCursor(clang.getTranslationUnitCursor(unit), sm)
}
Type_getNamedType :: proc(T: Type, sm: ^String_Manager) -> Type {
    return asThisType(clang.Type_getNamedType(T), sm)
}
Type_resolveElaborated :: proc(T: Type, sm: ^String_Manager) -> Type {
    cl_t := T.cl
    for cl_t.kind == .Elaborated do cl_t = clang.Type_getNamedType(cl_t)
    return asThisType(cl_t, sm)
}
Type_resolveTypedef :: proc(T: Type, sm: ^String_Manager) -> Type {
    return asThisType(clang.getCanonicalType(T.cl), sm)
}
Type_resolve :: proc(T: Type, sm: ^String_Manager) -> Type {
    //TODO(rysah): This is less efficient then handling both in the same loop :/
    return Type_resolveElaborated(Type_resolveTypedef(Type_resolveElaborated(T, sm), sm), sm)
}
Cursor_atMacro :: proc(cursor: Cursor) -> bool {
    source_loc := clang.getCursorLocation(cursor)
    return clang.Location_isFromMainFile(source_loc) == 0
}
Cursor_getComment :: proc(
    cursor: Cursor,
    sm: ^String_Manager
) -> (comment: Maybe(string), range: Source_Range) {
	range = clang.Cursor_getCommentRange(cursor)
	// No comment to parse
	if clang.Range_isNull(range) != 0 do return nil, range

	raw_comment: clang.String = clang.Cursor_getRawCommentText(cursor)
    defer clang.disposeString(raw_comment)

    return stringManagerIntern(sm, getString(raw_comment)), range
}
Cursor_isAnonymous :: proc(C: Cursor) -> bool {
    return clang.Cursor_isAnonymous(C) != 0
}
Cursor_isVariadic :: proc(C: Cursor) -> bool {
    return clang.Cursor_isVariadic(C) != 0
}
Type_getSizeOf :: proc "c" (T: Type) -> int {
    return cast(int)clang.Type_getSizeOf(T)
}
Type_getAlignOf :: proc "c" (T: Type) -> int {
    return cast(int)clang.Type_getAlignOf(T)
}
getEnumConstantDeclUnsignedValue :: proc(C: Cursor) -> uint {
    return cast(uint)clang.getEnumConstantDeclUnsignedValue(C)
}
getEnumConstantDeclValue :: proc(C: Cursor) -> int {
    return cast(int)clang.getEnumConstantDeclValue(C)
}
getEnumIntegerType :: proc(C: Cursor, sm: ^String_Manager) -> Type {
    return asThisType(clang.getEnumDeclIntegerType(C), sm)
}
getElementType :: proc(T: Type, sm: ^String_Manager) -> Type {
    return asThisType(clang.getElementType(T), sm)
}
hashCursor :: proc "c" (C: Cursor) -> uint {
    return cast(uint)clang.hashCursor(C)
}
getResultType :: proc(T: Type, sm: ^String_Manager) -> Type {
    return asThisType(clang.getResultType(T), sm)
}
getFunctionTypeCallingConv :: clang.getFunctionTypeCallingConv
getCursorUSR :: clang.getCursorUSR
getPointeeType :: proc(T: Type, sm: ^String_Manager) -> Type {
    return asThisType(clang.getPointeeType(T), sm)
}
getNumArgTypes :: proc(T: Type) -> int { return cast(int)clang.getNumArgTypes(T) }
getArgType :: proc(T: Type, i: uint, sm: ^String_Manager) -> Type {
    return asThisType(clang.getArgType(T, cast(c.uint)i), sm)
}

@private _spelling_to_ident :: proc(spelling: string, allocator := context.allocator) -> (result: string, err: mem.Allocator_Error) #optional_allocator_error {
    if strings.has_prefix(spelling, "struct ") {
        result = spelling[len("struct "):]
    } else if strings.has_prefix(spelling, "union ") {
        result = spelling[len("union "):]
    } else if strings.has_prefix(spelling, "enum ") {
        result = spelling[len("enum "):]
    } else {
        result = spelling
    }

    // Scope unqualifying the name
    if strings.contains(result, "::") {
        tokens := strings.split(result, "::") or_return
        defer delete(tokens)
        return _spelling_to_ident(tokens[len(tokens)-1], allocator)
    }

    // ident_ascii_set, ident_ascii_set_ok := strings.ascii_set_make("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890_")
    // assert(ident_ascii_set_ok) 
    temp_sb := strings.builder_make(0, len(result)) or_return
    defer strings.builder_destroy(&temp_sb)
    for r in result {
        if utf8.rune_size(r) != 1 do continue
        if !((r >= 48 && r <= 57) || (r == 95) || (r >= 65 && r <= 90) || (r >= 97 && r <= 122)) {
            strings.write_byte(&temp_sb, '_')
        } else {
            strings.write_rune(&temp_sb, r)
        }
    }
    return strings.clone(strings.to_string(temp_sb), allocator)
}

@private _next_func_proto_ident :: proc(allocator := context.allocator) -> (result: string) {
    context.allocator = allocator
    @static counter: uint = 0
    n := counter
    counter += 1
    return fmt.aprintf("_%d_func_type_", n)
}

@private _cursor_cleanup :: proc(cursor: ^Cursor, sm: ^String_Manager) -> (err: mem.Allocator_Error) {
    // if clang.getCursorType(cursor^).kind == .FunctionProto {
    //     ident := _next_func_proto_ident()
    //     defer delete(ident)
    //     cursor.ident = stringManagerIntern(sm, ident) or_return
    // } else {
    //     spelling := clang.getCursorSpelling(cursor)
    //     defer disposeString(spelling)

    //     ident := _spelling_to_ident(getString(spelling)) or_return
    //     defer delete(ident)
    //     cursor.ident = stringManagerIntern(sm, ident) or_return
    // }
    spelling := clang.getCursorSpelling(cursor)
    defer disposeString(spelling)

    ident := _spelling_to_ident(getString(spelling)) or_return
    defer delete(ident)
    cursor.ident = stringManagerIntern(sm, ident) or_return
    return nil
}

@private _type_cleanup :: proc(type: ^Type, sm: ^String_Manager) -> (err: mem.Allocator_Error) {
    if type.kind == .FunctionProto {
        ident := _next_func_proto_ident()
        defer delete(ident)
        type.ident = stringManagerIntern(sm, ident) or_return
    } else {
        spelling := clang.getTypeSpelling(type)
        defer disposeString(spelling)

        ident := _spelling_to_ident(getString(spelling)) or_return
        defer delete(ident)
        type.ident = stringManagerIntern(sm, ident) or_return
    }
    // spelling := clang.getTypeSpelling(type)
    // defer disposeString(spelling)

    // ident := _spelling_to_ident(getString(spelling)) or_return
    // defer delete(ident)
    // type.ident = stringManagerIntern(sm, ident) or_return
    return nil
}

visitChildren :: proc(
    parent: Cursor, 
    visitor: Cursor_Visitor, 
    sm: ^String_Manager, 
    client_data: Client_Data, 
    options := Visitor_Options{}
) -> (exit_by_break: bool, err: Visitor_Error) {
    _Client_Data :: struct {
        internal_visitor: Cursor_Visitor,
        internal_client_data: Client_Data,
        context_in: runtime.Context,
        err: ^Visitor_Error,
        sm: ^String_Manager,
        options: Visitor_Options
    }
    clang_client_data := _Client_Data{
        internal_visitor=visitor,
        internal_client_data=client_data,
        context_in=context,
        err=&err,
        sm=sm,
        options=options
    }
    clang_visitor : clang.Cursor_Visitor : proc "c" (
        cursor, parent: clang.Cursor, client_data: Client_Data
    ) -> (result: Child_Visit_Result) {
        client_data := transmute(^_Client_Data)client_data
        context = client_data.context_in
        
        easy_parent_cursor, easy_cursor: Cursor
        easy_parent_cursor, client_data.err^ = asThisCursor(parent, client_data.sm)
        if client_data.err^ != nil do return .Break
        easy_cursor, client_data.err^ = asThisCursor(cursor, client_data.sm)
        if client_data.err^ != nil do return .Break
        
        if client_data.options.skip_transparent_tag_typedefs {
            if Cursor_isTransparentTagTypedef(easy_cursor, client_data.sm) {
                underlying_type := getTypedefDeclUnderlyingType(easy_cursor, client_data.sm)
                easy_cursor, client_data.err^ = asThisCursor(getTypeDeclaration(underlying_type, client_data.sm), client_data.sm)
                if client_data.err^ != nil do return .Break
            }
        } 
        
        result, client_data.err^ = client_data.internal_visitor(easy_cursor, easy_parent_cursor, client_data.sm, client_data.internal_client_data)
        
        return result
    } 
    exit_by_break = clang.visitChildren(parent, clang_visitor, &clang_client_data) != 0
    return exit_by_break, err
}

Type_visitRecordFields :: proc(
    T: Type, 
    visitor: Field_Visitor, 
    sm: ^String_Manager, 
    client_data: Client_Data, 
    options := Visitor_Options{}
) -> (exit_by_break: bool, err: Visitor_Error) {
    _Client_Data :: struct {
        internal_visitor: Field_Visitor,
        internal_client_data: Client_Data
    }
    decl_cursor := getTypeDeclaration(T, sm)
    local_client_data := _Client_Data{
        internal_visitor=visitor,
        internal_client_data=client_data
    }
    return visitChildren(
        decl_cursor,
        proc(cursor, parent: Cursor, sm: ^String_Manager, client_data: Client_Data) -> (result: Child_Visit_Result, err: Error) {
            client_data := transmute(^_Client_Data)client_data
            kind := getCursorKind(cursor)
            #partial switch kind {
                case .FieldDecl:
                    result = transmute(Child_Visit_Result)client_data.internal_visitor(cursor, sm, client_data.internal_client_data) or_return
                    return result, nil
            }
            return result, nil
        },
        sm,
        &local_client_data
    )
}

Type_visitEnumConstantDecls :: proc(
    T: Type, 
    visitor: Field_Visitor, 
    sm: ^String_Manager, 
    client_data: Client_Data, 
    options := Visitor_Options{}
) -> (exit_by_break: bool, err: Visitor_Error) {
    _Client_Data :: struct {
        internal_visitor: Field_Visitor,
        internal_client_data: Client_Data
    }
    decl_cursor := getTypeDeclaration(T, sm)
    local_client_data := _Client_Data{
        internal_visitor=visitor,
        internal_client_data=client_data
    }
    return visitChildren(
        decl_cursor,
        proc(cursor, parent: Cursor, sm: ^String_Manager, client_data: Client_Data) -> (result: Child_Visit_Result, err: Error) {
            client_data := transmute(^_Client_Data)client_data
            if getCursorKind(cursor) == .EnumConstantDecl {
                result = transmute(Child_Visit_Result)client_data.internal_visitor(cursor, sm, client_data.internal_client_data) or_return
                return result, nil
            }
            return result, nil
        },
        sm,
        &local_client_data
    )
}

Cursor_visitFunctionParams :: proc(
    C: Cursor,
    visitor: Field_Visitor,
    sm: ^String_Manager,
    client_data: Client_Data,
    options := Visitor_Options{},
) -> (exit_by_break: bool, err: Visitor_Error) {
    _Client_Data :: struct {
        internal_visitor: Field_Visitor,
        internal_client_data: Client_Data,
    }

    local_client_data := _Client_Data{
        internal_visitor = visitor,
        internal_client_data = client_data,
    }

    return visitChildren(
        C,
        proc(cursor, parent: Cursor, sm: ^String_Manager, cd: Client_Data) -> (result: Child_Visit_Result, err: Error) {
            
            cd := transmute(^_Client_Data)cd

            if getCursorKind(cursor) == .ParmDecl {
                r, e := cd.internal_visitor(cursor, sm, cd.internal_client_data)
                return transmute(Child_Visit_Result)r, e
            }

            return .Continue, nil
        },
        sm,
        &local_client_data,
        options = options,
    )
}
isCursorDefinition :: proc "c" (C: Cursor) -> bool {
    return clang.isCursorDefinition(C) != 0
}

parseTranslationUnit :: proc(
    CIdx: Index, 
    source_filename: string, 
    command_line_args: []string,
    unsaved_files: []Unsaved_File,
    options: Translation_Unit_Flags, 
    out_TU: ^Translation_Unit
) -> Error {
    sf := strings.clone_to_cstring(source_filename) or_return
    defer delete(sf)
    cla := make([]cstring, len(command_line_args)) or_return
    for arg, i in command_line_args {
        cla[i] = strings.clone_to_cstring(arg) or_return
    }
    defer {
        for arg in cla do delete(arg)
        delete(cla)
    }
    return clang.parseTranslationUnit2(
        CIdx,
        sf,
        raw_data(cla), cast(c.int)len(cla),
        raw_data(unsaved_files), cast(c.uint)len(unsaved_files),
        options,
        out_TU
    )
}

createIndex :: proc(
    excludeDeclarationsFromPCH: int, 
    displayDiagnostics: int
) -> Index {
    return clang.createIndex(
        cast(c.int)excludeDeclarationsFromPCH, 
        cast(c.int)displayDiagnostics
    )
}

