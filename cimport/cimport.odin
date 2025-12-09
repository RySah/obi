package cimport

import "core:mem"
import "core:strings"
import "core:os"

import bindgen "../cbindgen2"

Name_Case :: bindgen.Output_Name_Case

Bindgen_Config :: bindgen.Config

Import_Info :: struct {
    // The package name
    package_name: string,
    // List of files and directories to import
    file_and_dirs: [dynamic]string,
    // Remove this prefix from types names (structs, enums, etc)
    remove_type_prefix: string,
    // Remove this prefix from macro names
    remove_macro_prefix: string,
    // Remove this prefix from function names (and add it as link_prefix) to the foreign group
    remove_function_prefix: string,
    // Remove this suffix from function names (and add it as link_suffix) to the foreign group
    remove_function_suffix: string,
    // Set the name case for types
    type_name_case: Name_Case,
    // Set the name case for functions
    function_name_case: Name_Case,
    // The libary you want the procedures to link with, can either be a relative file path, or an odin expression to get the libary. In the case of an odin expression, alias the libary with `%LIB%`.
    // e.g. `foreign import %LIB% "raylib.lib"`
    // To ensure the expression can work across changes in the API. If not possible, on this **CURRENT VERSION** you can use "lib".
    lib: string,
    // "Old_Name" = "New_Name"
    rename: map[string]string,
    // Turns an enum into a bit_set. Converts the values of the enum into appropriate values for a
    // bit_set. Creates a bit_set type that uses the enum. Properly removes enum values with value 0.
    // Translates the enum values using a log2 procedure.
    enum_to_bitset: map[string]string,
    // Completely override the definition of a type.
    // "Original_Type" = "New_Type"
    type_overrides: map[string]string,
    // Override the type of a struct field.
    // You can also use `[^]` to augment an already existing type.
    struct_field_overrides: map[string]string,
    // Remove a specific enum member. Write the C name of the member. You can also use wildcards
    // such as *_Count
    remove_enum_members: [dynamic]string,
    // Overrides the type of a procedure parameter or return value. For a parameter use the key
    // Proc_Name.parameter_name. For a return value use the key Proc_Name.
    // You can also use `[^]`, `#by_ptr` and `#any_int` to augment an already existing type.
    procedure_type_overrides: map[string]string,
    // Put the names of declarations in here to remove them.	
    remove: [dynamic]string,
    // Group all procedures at the end of the file.
    procedures_at_end: bool,

    // Additional include paths to send into clang. While generating the bindings clang will look into
    // this path in search for included headers.
    clang_include_paths: [dynamic]string,
    clang_defines: map[string]string,
}

init_import_info :: proc(info: ^Import_Info, allocator := context.allocator) -> mem.Allocator_Error {
    context.allocator = allocator
    info.file_and_dirs = make([dynamic]string) or_return
    info.rename = make(map[string]string)
    info.enum_to_bitset = make(map[string]string)
    info.type_overrides = make(map[string]string)
    info.struct_field_overrides = make(map[string]string)
    info.remove_enum_members = make([dynamic]string) or_return
    info.procedure_type_overrides = make(map[string]string)
    info.remove = make([dynamic]string) or_return
    info.clang_include_paths = make([dynamic]string) or_return
    info.clang_defines = make(map[string]string)
    return nil
}

make_import_info :: proc(allocator := context.allocator) -> (info: ^Import_Info, err: mem.Allocator_Error) #optional_allocator_error {
    context.allocator = allocator
    info = new(Import_Info) or_return
    init_import_info(info) or_return
    return info, nil
}

destroy_import_info :: proc(info: ^Import_Info) -> mem.Allocator_Error {
    delete(info.file_and_dirs) or_return
    delete(info.rename) or_return
    delete(info.enum_to_bitset) or_return
    delete(info.type_overrides) or_return
    delete(info.struct_field_overrides) or_return
    delete(info.remove_enum_members) or_return
    delete(info.procedure_type_overrides) or_return
    delete(info.remove) or_return
    delete(info.clang_include_paths) or_return
    delete(info.clang_defines) or_return
    return nil
}

include :: proc(info: ^Import_Info, paths: ..string) -> mem.Allocator_Error {
    append(&info.file_and_dirs, ..paths) or_return
    return nil
}

as_bindgen_config :: proc(info: ^Import_Info) -> (config: Bindgen_Config) {
    config.inputs = info.file_and_dirs[:]
    config.output_folder = info.package_name
    config.remove_type_prefix = info.remove_type_prefix
    config.remove_macro_prefix = info.remove_macro_prefix
    config.remove_function_prefix = info.remove_function_prefix
    config.remove_function_suffix = info.remove_function_suffix
    config.force_ada_case_types = info.type_name_case == .Ada_Case
    config.force_snake_case_types = info.type_name_case == .Snake_Case
    config.force_camel_case_types = info.type_name_case == .Camel_Case
    config.force_pascal_case_types = info.type_name_case == .Pascal_Case
    if os.is_file(info.lib) {
        config.import_lib = info.lib
    } else {
        
    }
    return
}