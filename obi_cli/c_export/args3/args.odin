package args3
import "core:c"

// An ArgParser instance stores registered flags, options and commands.
ArgParser :: BIND_GEN_OPAQUE_T
_1_Func_Type :: #type proc "cdecl" (cstring, [^]Arg_Parser) -> c.int
// A callback function should accept two arguments: the command's name and the
// command's ArgParser instance. It should return an integer status code.
Ap_Callback_T :: _1_Func_Type
@(private="file") BIND_GEN_OPAQUE_T :: distinct rawptr
foreign import libarg3 "third_party/args-3.3.0/build/libargs.a"
foreign libarg3
{
// Allocates and initializes a new ArgParser instance. Returns NULL if memory
// allocation fails.
@(link_name="ap_new_parser") ap_new_parser :: proc "cdecl" () -> [^]Arg_Parser ---
// Specifies a helptext string for the parser. If [helptext] is not NULL, this
// activates an automatic --help/-h flag. (Either --help or -h can be overridden
// by explicitly registered flags.) The parser stores and manages its own copy
// of the [helptext] string so [helptext] can be freed immediately after this
// call if it was dynamically constructed.
@(link_name="ap_set_helptext") ap_set_helptext :: proc "cdecl" (parser: [^]Arg_Parser, helptext: cstring) ---
// Returns a pointer to the parser's helptext string.
@(link_name="ap_get_helptext") ap_get_helptext :: proc "cdecl" (parser: [^]Arg_Parser) -> cstring ---
// Specifies a version string for the parser. If [version] is not NULL, this
// activates an automatic --version/-v flag. (Either --version or -v can be
// overridden by explicitly registered flags.) The parser stores and manages its
// own copy of the [version] string so [version] can be freed immediately after
// this call if it was dynamically constructed.
@(link_name="ap_set_version") ap_set_version :: proc "cdecl" (parser: [^]Arg_Parser, version: cstring) ---
// Returns a pointer to the parser's version string.
@(link_name="ap_get_version") ap_get_version :: proc "cdecl" (parser: [^]Arg_Parser) -> cstring ---
// Parses an array of string arguments.
// - Exits with an error message and a non-zero status code if the arguments are
//   invalid.
// - The parameters are assumed to be [argc] and [argv] as supplied to main(),
//   i.e. the first element of the array is assumed to be the binary name and
//   is therefore ignored.
// - Returns true if the arguments were successfully parsed.
// - Returns false if parsing failed because sufficient memory could not be
//   allocated.
@(link_name="ap_parse") ap_parse :: proc "cdecl" (parser: [^]Arg_Parser, argc: c.int, argv: [^]cstring) -> c.bool ---
// Frees the memory associated with the parser and any subparsers.
@(link_name="ap_free") ap_free :: proc "cdecl" (parser: [^]Arg_Parser) ---
// If set, the first positional argument ends option-parsing; all subsequent
// arguments will be treated as positionals.
@(link_name="ap_first_pos_arg_ends_option_parsing") ap_first_pos_arg_ends_option_parsing :: proc "cdecl" (parser: [^]Arg_Parser) ---
// If set, all arguments will be treated as positionals.
@(link_name="ap_all_args_as_pos_args") ap_all_args_as_pos_args :: proc "cdecl" (parser: [^]Arg_Parser) ---
// Registers a new flag.
@(link_name="ap_add_flag") ap_add_flag :: proc "cdecl" (parser: [^]Arg_Parser, name: cstring) ---
// Registers a new string-valued option.
@(link_name="ap_add_str_opt") ap_add_str_opt :: proc "cdecl" (parser: [^]Arg_Parser, name: cstring, fallback: cstring) ---
// Registers a new integer-valued option.
@(link_name="ap_add_int_opt") ap_add_int_opt :: proc "cdecl" (parser: [^]Arg_Parser, name: cstring, fallback: c.int) ---
// Registers a new double-valued option.
@(link_name="ap_add_dbl_opt") ap_add_dbl_opt :: proc "cdecl" (parser: [^]Arg_Parser, name: cstring, fallback: c.double) ---
// Registers a new greedy string-valued option.
@(link_name="ap_add_greedy_str_opt") ap_add_greedy_str_opt :: proc "cdecl" (parser: [^]Arg_Parser, name: cstring) ---
// Returns the number of times the specified flag or option was found.
@(link_name="ap_count") ap_count :: proc "cdecl" (parser: [^]Arg_Parser, name: cstring) -> c.int ---
// Returns true if the specified flag or option was found.
@(link_name="ap_found") ap_found :: proc "cdecl" (parser: [^]Arg_Parser, name: cstring) -> c.bool ---
// Returns the value of a string option.
@(link_name="ap_get_str_value") ap_get_str_value :: proc "cdecl" (parser: [^]Arg_Parser, name: cstring) -> cstring ---
// Returns the string value at the specified index.
@(link_name="ap_get_str_value_at_index") ap_get_str_value_at_index :: proc "cdecl" (parser: [^]Arg_Parser, name: cstring, index: c.int) -> cstring ---
// Returns the value of an integer option.
@(link_name="ap_get_int_value") ap_get_int_value :: proc "cdecl" (parser: [^]Arg_Parser, name: cstring) -> c.int ---
// Returns the integer value at the specified index.
@(link_name="ap_get_int_value_at_index") ap_get_int_value_at_index :: proc "cdecl" (parser: [^]Arg_Parser, name: cstring, index: c.int) -> c.int ---
// Returns the value of a floating-point option.
@(link_name="ap_get_dbl_value") ap_get_dbl_value :: proc "cdecl" (parser: [^]Arg_Parser, name: cstring) -> c.double ---
// Returns the floating-point value at the specified index.
@(link_name="ap_get_dbl_value_at_index") ap_get_dbl_value_at_index :: proc "cdecl" (parser: [^]Arg_Parser, name: cstring, index: c.int) -> c.double ---
// Returns an option's values as a freshly-allocated array of string
// pointers. The array's memory is not affected by calls to ap_free().
// Returns NULL if memory allocation fails.
@(link_name="ap_get_str_values") ap_get_str_values :: proc "cdecl" (parser: [^]Arg_Parser, name: cstring) -> [^]cstring ---
// Returns an option's values as a freshly-allocated array of integers.
// The array's memory is not affected by calls to ap_free().
// Returns NULL if memory allocation fails.
@(link_name="ap_get_int_values") ap_get_int_values :: proc "cdecl" (parser: [^]Arg_Parser, name: cstring) -> [^]c.int ---
// Returns an option's values as a freshly-allocated array of doubles.
// The array's memory is not affected by calls to ap_free().
// Returns NULL if memory allocation fails.
@(link_name="ap_get_dbl_values") ap_get_dbl_values :: proc "cdecl" (parser: [^]Arg_Parser, name: cstring) -> [^]c.double ---
// Returns true if the parser has found one or more positional arguments.
@(link_name="ap_has_args") ap_has_args :: proc "cdecl" (parser: [^]Arg_Parser) -> c.bool ---
// Returns the number of positional arguments.
@(link_name="ap_count_args") ap_count_args :: proc "cdecl" (parser: [^]Arg_Parser) -> c.int ---
// Returns the positional argument at the specified index.
@(link_name="ap_get_arg_at_index") ap_get_arg_at_index :: proc "cdecl" (parser: [^]Arg_Parser, index: c.int) -> cstring ---
// Returns the positional arguments as a freshly-allocated array of string
// pointers. The memory occupied by the returned array is not affected by
// calls to ap_free(). Returns NULL if memory allocation fails.
@(link_name="ap_get_args") ap_get_args :: proc "cdecl" (parser: [^]Arg_Parser) -> [^]cstring ---
// Attempts to parse and return the positional arguments as a freshly allocated
// array of integers. Exits with an error message on failure. The memory
// occupied by the returned array is not affected by calls to ap_free().
// Returns NULL if memory allocation fails.
@(link_name="ap_get_args_as_ints") ap_get_args_as_ints :: proc "cdecl" (parser: [^]Arg_Parser) -> [^]c.int ---
// Attempts to parse and return the positional arguments as a freshly allocated
// array of doubles. Exits with an error message on failure. The memory
// occupied by the returned array is not affected by calls to ap_free().
// Returns NULL if memory allocation fails.
@(link_name="ap_get_args_as_doubles") ap_get_args_as_doubles :: proc "cdecl" (parser: [^]Arg_Parser) -> [^]c.double ---
// Registers a new command. Returns the ArgParser instance for the command.
// Returns NULL if sufficient memory cannot be allocated for the new parser.
@(link_name="ap_new_cmd") ap_new_cmd :: proc "cdecl" (parent_parser: [^]Arg_Parser, name: cstring) -> [^]Arg_Parser ---
// Registers a callback function on a command parser.
@(link_name="ap_set_cmd_callback") ap_set_cmd_callback :: proc "cdecl" (cmd_parser: [^]Arg_Parser, cmd_callback: Ap_Callback_T) ---
// Returns true if [parent_parser] has found a command.
@(link_name="ap_found_cmd") ap_found_cmd :: proc "cdecl" (parent_parser: [^]Arg_Parser) -> c.bool ---
// If [parent_parser] has found a command, returns its name, otherwise NULL.
@(link_name="ap_get_cmd_name") ap_get_cmd_name :: proc "cdecl" (parent_parser: [^]Arg_Parser) -> cstring ---
// If [parent_parser] has found a command, returns its ArgParser instance,
// otherwise NULL.
@(link_name="ap_get_cmd_parser") ap_get_cmd_parser :: proc "cdecl" (parent_parser: [^]Arg_Parser) -> [^]Arg_Parser ---
// If [parent_parser] has found a command, and if that command has a callback
// function, returns the exit code from the callback, otherwise 0.
@(link_name="ap_get_cmd_exit_code") ap_get_cmd_exit_code :: proc "cdecl" (parent_parser: [^]Arg_Parser) -> c.int ---
// This boolean switch toggles support for an automatic 'help' command that
// prints subcommand helptext. The value defaults to false but gets toggled
// automatically to true whenever a command is registered. You can use this
// function to disable the feature if required.
@(link_name="ap_enable_help_command") ap_enable_help_command :: proc "cdecl" (parent_parser: [^]Arg_Parser, enable: c.bool) ---
// If [parser] has a parent -- i.e. if [parser] is a command parser -- returns
// its parent, otherwise NULL.
@(link_name="ap_get_parent") ap_get_parent :: proc "cdecl" (parser: [^]Arg_Parser) -> [^]Arg_Parser ---
// Dumps a parser instance to stdout for debugging.
@(link_name="ap_print") ap_print :: proc "cdecl" (parser: [^]Arg_Parser) ---
// Returns true if an attempt to allocate memory failed.
@(link_name="ap_had_memory_error") ap_had_memory_error :: proc "cdecl" (parser: [^]Arg_Parser) -> c.bool ---
// Returns the argument supplied at index-zero to the root parser. Typically
// this is the filepath of the binary. This function can be called on the root
// parser or any command sub-parser.
@(link_name="ap_get_zeroth_root_arg") ap_get_zeroth_root_arg :: proc "cdecl" (parser: [^]Arg_Parser) -> cstring ---
}
