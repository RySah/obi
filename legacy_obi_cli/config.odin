package obi_cli

import "core:encoding/json"
import "core:os/os2"

LIBCLANG_DLL_EMBED :: #load("embed/libclang.dll")

Config :: struct {
    build_directory: string,
    extra_build_flags: []string,
    output_directory: string
}

Config_Creation_Error :: union #shared_nil {
    json.Unmarshal_Error,
    os2.Error
}

parse_config_from_bytes :: #force_inline proc(data: []byte, conf: ^Config) -> Config_Creation_Error {
    return json.unmarshal(data, conf, spec=json.Specification.SJSON)
}
parse_config_from_string :: #force_inline proc(data: string, conf: ^Config) -> Config_Creation_Error {
    return parse_config_from_bytes(transmute([]byte)data, conf)
}
parse_config_from_data :: proc{parse_config_from_bytes,parse_config_from_string}

parse_config_from_path :: #force_inline proc(path: string, conf: ^Config) -> Config_Creation_Error {
    data := os2.read_entire_file_from_path(path, context.allocator) or_return
    return parse_config_from_data(data, conf)
}
