package cbindgen2

import vmem "core:mem/virtual"
import "core:mem"
import "core:strings"
import "core:os"
import "core:os/os2"
import "core:fmt"
import "core:path/filepath"
import "core:encoding/json"

import "base:runtime"

// CREDITS: https://github.com/karl-zylinski/odin-c-bindgen/releases/tag/2.0
// ---
// This package is simply a API to use odin-c-bindgen more like an libary
// rather than executable.
// Some more functionality may be added here ontop of the API to make it easier to use.
import src "../third_party/odin-c-bindgen-2.0/src"

Config :: src.Config
Type :: src.Type
Type_List :: src.Type_List
Decl :: src.Decl
Decl_List :: src.Decl_List
Output_Name_Case :: src.Output_Name_Case

add_decl :: src.add_decl
add_type :: src.add_type

translate_collect :: src.translate_collect
translate_macros :: src.translate_macros
translate_process :: src.translate_process
output :: src.output

General_Error :: enum {
    Invalid_Input_Type
}

Error :: union #shared_nil {
    General_Error,
    mem.Allocator_Error,
    os2.Error
}

run :: proc(config: ^Config, cwd: string, function_name_case := Output_Name_Case.Original, allocator := context.allocator) -> Error {
    context.allocator = allocator

    output_folder := filepath.join({ cwd, config.output_folder }) or_return
    defer delete(output_folder)
    package_name := config.package_name

    imports_file: string
    if config.imports_file != "" {
        imports_file = filepath.join({ cwd, config.imports_file }) or_return
    } else {
        imports_file = strings.clone(config.imports_file)
    }
    defer delete(imports_file)

    input_files := make([dynamic]string, 0, len(config.inputs))
    defer {
        for &s in input_files do delete(s)
        delete(input_files)
    }

    for input_base in config.inputs {
        input := filepath.join({ cwd, input_base })
        defer delete(input)

        if os.is_dir(input) {
            input_folder := os2.open(input) or_return
            defer os2.close(input_folder)

            iter := os2.read_directory_iterator_create(input_folder)

            for f in os2.read_directory_iterator(&iter) {
                if f.type != .Regular do continue
                append(&input_files, filepath.join({ input, f.name }) or_return) or_return
            }
        } else if os.is_file(input) {
            append(&input_files, strings.clone(input) or_return) or_return
        } else do return General_Error.Invalid_Input_Type
    }

    if raw_data(output_folder) != nil && len(output_folder) > 0 && !os.exists(output_folder) {
        os2.make_directory_all(output_folder) or_return
    }

    for input_filename in input_files {
        if filepath.ext(input_filename) == ".h" {
            type_arr := make([dynamic]Type)
            types := Type_List(&type_arr)
            defer delete(type_arr)

            decl_arr := make([dynamic]Decl)
            decls := Decl_List(&decl_arr)
            defer delete(decl_arr)

            add_type(types, {})
            add_decl(decls, {})

            // TODO(rysah): Consider removing this, looks like it has no usage
            gen_arena: vmem.Arena
            src.gen_ctx = runtime.default_context()
            src.gen_ctx.allocator = vmem.arena_allocator(&gen_arena)
            src.gen_ctx.temp_allocator = vmem.arena_allocator(&gen_arena)
            defer vmem.arena_destroy(&gen_arena)

            collect_res, collect_ok := translate_collect(input_filename, config^, types, decls)

            if !collect_ok do continue

            translate_macros(collect_res.macros, decls)

            process_res := translate_process(collect_res, config^, types, decls)

            input_folder := filepath.dir(input_filename)
            defer delete(input_folder)
            filename_stem := filepath.stem(input_filename)
            defer delete(filename_stem)
            footer_filename := filepath.join({ input_folder, fmt.tprintf("%v_footer.odin", filename_stem) }) or_return
            defer delete(footer_filename)

            footer_allocated := false
            footer: string
            if os.exists(footer_filename) {
                if footer_bytes, footer_bytes_ok := os.read_entire_file(footer_filename); footer_bytes_ok {
                    footer = string(footer_bytes)
                    footer_allocated = true
                }
            }

            defer if footer_allocated do delete(footer)

            output_filename := filepath.join({ output_folder, fmt.tprintf("%v.odin", filename_stem) })
            defer delete(output_filename)

            output(types, decls, process_res, output_filename, footer, package_name, function_name_case=function_name_case)
        }
    }

    return nil
}