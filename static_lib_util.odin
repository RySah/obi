package obi

Static_Lib_Path :: distinct string

Static_Lib_Source :: union {
    C_Path,
    Object_Path
}

Static_Lib_Compile :: struct {
    sources: []Static_Lib_Source
}
