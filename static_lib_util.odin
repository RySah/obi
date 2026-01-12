package obi

STATIC_LIB_EXT :: ".lib" when ODIN_OS == .Windows else ".a"

Static_Lib_Path :: distinct string

Static_Lib_Source :: union {
    C_Path,
    Object_Path
}

Static_Lib_Spec :: struct {
    sources: []Static_Lib_Source,
    output: Static_Lib_Path
}

