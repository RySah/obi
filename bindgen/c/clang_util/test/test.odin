package test

import clang_util ".."

import "core:fmt"

visitor : clang_util.Cursor_Visitor : proc(parent, cursor: clang_util.Cursor, sm: ^clang_util.String_Manager, client_data: clang_util.Client_Data) -> (result: clang_util.Child_Visit_Result, err: clang_util.Error) {
    type := clang_util.getCursorType(cursor, sm)
    fmt.println(cursor, clang_util.Cursor_isAnonymous(cursor), clang_util.Type_isTransparentTagTypedef(type, sm))
    return .Recurse, nil
}

main :: proc() {
    index := clang_util.createIndex(0, 0)
    unit: clang_util.Translation_Unit
    assert(clang_util.parseTranslationUnit(
        index, "event_queue.h", {}, {}, { .SkipFunctionBodies, .KeepGoing }, &unit
    ) == nil)
    defer {
        clang_util.disposeIndex(index)
        clang_util.disposeTranslationUnit(unit)
    }

    sm: clang_util.String_Manager
    assert(clang_util.stringManagerInit(&sm) == nil)
    defer clang_util.stringManagerDestroy(&sm)

    cursor := clang_util.getTranslationUnitCursor(unit, &sm)
    exit_via_break, visit_err := clang_util.visitChildren(
        cursor, visitor, &sm, nil,
        { 
            skip_transparent_tag_typedefs=false
        }
    )
    
}