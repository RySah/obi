package cimport

import "core:mem"
import "core:strings"
import "core:os"

import bindgen "../cbindgen2"
import cachefs "../cache_fs"

Name_Case :: bindgen.Output_Name_Case

Bindgen_Config :: bindgen.Config

DEFAULT_CACHE_FS_NAME :: "cimport"

Error :: union #shared_nil {
    cachefs.Error,
    bindgen.Error,
    mem.Allocator_Error
}

Import_Info :: struct {
    cache_file_system: cachefs.File_System,

    // The package name
    package_name: string,
    // The output folder for the package
    output_folder: string,
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
    // The libary you want the procedures to link with, can either be a relative file path, or an odin expression to get the libary. In the case of an odin expression, alias the libary with `lib`.
    // e.g. `foreign import lib "raylib.lib"`
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
    // Put these tags on the specified struct field
	struct_field_tags: map[string]string,
    // Remove a specific enum member. Write the C name of the member. You can also use wildcards
    // such as *_Count
    remove_enum_members: [dynamic]string,
    // Overrides the type of a procedure parameter or return value. For a parameter use the key
    // Proc_Name.parameter_name. For a return value use the key Proc_Name.
    // You can also use `[^]`, `#by_ptr` and `#any_int` to augment an already existing type.
    procedure_type_overrides: map[string]string,
    // Add in a default value to a procedure parameter. Use `Proc_Name.parameter_name` as key and
	// write the plain-text Odin value as value.
	// You can also add defaults for proc parameters within structs. In that case you do:
	// `Struct_Name.proc_field.parameter_name` -- This does not currently support nested structs.
	procedure_parameter_defaults: map[string]string,
    // Put the names of declarations in here to remove them.	
    remove: [dynamic]string,
    // Group all procedures at the end of the file.
    procedures_at_end: bool,

    // Additional include paths to send into clang. While generating the bindings clang will look into
    // this path in search for included headers.
    clang_include_paths: [dynamic]string,
    clang_defines: map[string]string,
}

init_import_info :: proc(info: ^Import_Info, root_cache_fs: ^cachefs.File_System, allocator := context.allocator) -> Error {
    context.allocator = allocator
    info.cache_file_system = cachefs.child(root_cache_fs, DEFAULT_CACHE_FS_NAME) or_return
    info.file_and_dirs = make([dynamic]string) or_return
    info.rename = make(map[string]string)
    info.enum_to_bitset = make(map[string]string)
    info.type_overrides = make(map[string]string)
    info.struct_field_overrides = make(map[string]string)
    info.struct_field_tags = make(map[string]string)
    info.remove_enum_members = make([dynamic]string) or_return
    info.procedure_type_overrides = make(map[string]string)
    info.procedure_parameter_defaults = make(map[string]string)
    info.remove = make([dynamic]string) or_return
    info.clang_include_paths = make([dynamic]string) or_return
    info.clang_defines = make(map[string]string)
    return nil
}

make_import_info :: proc(root_cache_fs: ^cachefs.File_System, allocator := context.allocator) -> (info: ^Import_Info, err: Error) {
    context.allocator = allocator
    info = new(Import_Info) or_return
    init_import_info(info, root_cache_fs) or_return
    return info, nil
}

destroy_import_info :: proc(info: ^Import_Info) -> Error {
    cachefs.destroy(&info.cache_file_system) or_return
    delete(info.file_and_dirs) or_return
    delete(info.rename) or_return
    delete(info.enum_to_bitset) or_return
    delete(info.type_overrides) or_return
    delete(info.struct_field_overrides) or_return
    delete(info.struct_field_tags) or_return
    delete(info.remove_enum_members) or_return
    delete(info.procedure_type_overrides) or_return
    delete(info.procedure_parameter_defaults) or_return
    delete(info.remove) or_return
    delete(info.clang_include_paths) or_return
    delete(info.clang_defines) or_return
    return nil
}

include :: proc(info: ^Import_Info, paths: ..string) -> mem.Allocator_Error {
    append(&info.file_and_dirs, ..paths) or_return
    return nil
}

// **NOTE**: `function_name_case` is not handled here in the config, provide it as parameter to `bindgen.output`
as_bindgen_config :: proc(info: ^Import_Info) -> (config: Bindgen_Config, err: Error) {
    config.inputs = info.file_and_dirs[:]
    config.output_folder = info.output_folder
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
        config.imports_file = cachefs.cachef(&info.cache_file_system, "%s", info.lib) or_return
    }
    config.package_name = info.package_name
    config.rename = info.rename
    config.bit_setify = info.enum_to_bitset
    config.type_overrides = info.type_overrides
    config.struct_field_overrides = info.struct_field_overrides
    config.struct_field_tags = info.struct_field_tags
    config.remove_enum_members = info.remove_enum_members[:]
    config.procedure_type_overrides = info.procedure_type_overrides
    config.procedure_parameter_defaults = info.procedure_parameter_defaults
    config.remove = info.remove[:]
    config.procedures_at_end = info.procedures_at_end
    config.clang_include_paths = info.clang_include_paths[:]
    config.clang_defines = info.clang_defines
    return config, nil
}

import_info :: proc(info: ^Import_Info, allocator := context.allocator) -> (err: Error) {
    context.allocator = allocator
    config := as_bindgen_config(info) or_return
    bindgen.run(&config, ".", function_name_case=info.function_name_case) or_return
    return nil
}