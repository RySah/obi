package mpack
import "core:c"

int32_t :: c.int32_t
/**
 * Error states for MPack objects.
 *
 * When a reader, writer, or tree is in an error state, all subsequent calls
 * are ignored and their return values are nil/zero. You should check whether
 * the source is in an error state before using such values.
 */
Mpack_Error_T :: enum int32_t
{
    MPACK_OK = 0,
    MPACK_ERROR_IO = 2,
    MPACK_ERROR_INVALID = 3,
    MPACK_ERROR_UNSUPPORTED = 4,
    MPACK_ERROR_TYPE = 5,
    MPACK_ERROR_TOO_BIG = 6,
    MPACK_ERROR_MEMORY = 7,
    MPACK_ERROR_BUG = 8,
    MPACK_ERROR_DATA = 9,
    MPACK_ERROR_EOF = 10
}
/**
 * Defines the type of a MessagePack tag.
 *
 * Note that extension types, both user defined and built-in, are represented
 * in tags as @ref mpack_type_ext. The value for an extension type is stored
 * separately.
 */
Mpack_Type_T :: enum int32_t
{
    MPACK_TYPE_MISSING = 0,
    MPACK_TYPE_NIL = 1,
    MPACK_TYPE_BOOL = 2,
    MPACK_TYPE_INT = 3,
    MPACK_TYPE_UINT = 4,
    MPACK_TYPE_FLOAT = 5,
    MPACK_TYPE_DOUBLE = 6,
    MPACK_TYPE_STR = 7,
    MPACK_TYPE_BIN = 8,
    MPACK_TYPE_ARRAY = 9,
    MPACK_TYPE_MAP = 10
}
int16_t :: c.int16_t
uint64_t :: c.uint64_t
uint8_t :: c.uint8_t
uint16_t :: c.uint16_t
/* The value for non-compound types. */
_Unnamed_At_Third_Party_Api_Mpack_H_2093_5 :: struct #align(8) #raw_union
{
    u: uint64_t,
    i: uint8_t,
    b: c.bool,
    f: c.float,
    d: c.double,
    l: uint16_t,
    n: uint16_t
}
/* Hide internals from documentation */
/** @cond */
Mpack_Tag_T :: struct #align(8)
{
    type: Mpack_Type_T,
    v: _Unnamed_At_Third_Party_Api_Mpack_H_2093_5
}
size_t :: c.size_t
size_t :: int16_t
/**
 * Builds form a linked list of mpack_build_t, interleaved with their encoded
 * contents directly in the paged builder buffer.
 */
Mpack_Build_T :: struct #align(8)
{
    parent: <nil>,
    bytes: Size_T,
    count: uint16_t,
    type: Mpack_Type_T,
    nested_compound_elements: uint16_t,
    key_needs_value: c.bool
}
/**
 * Build buffer pages form a linked list.
 *
 * They don't always fill up. If there is not enough space within them to write
 * a tag or place an mpack_build_t, a new page is allocated. For this reason
 * they store the number of used bytes.
 */
Mpack_Builder_Page_T :: struct #align(8)
{
    next: <nil>,
    bytes_used: Size_T
}
/**
 * The builder state. This is stored within mpack_writer_t.
 */
Mpack_Builder_T :: struct #align(8)
{
    current_build: [^]Mpack_Build_T,
    latest_build: [^]Mpack_Build_T,
    current_page: [^]Mpack_Builder_Page_T,
    pages: [^]Mpack_Builder_Page_T,
    stash_buffer: cstring,
    stash_position: cstring,
    stash_end: cstring
}
Mpack_Writer_T :: struct #align(8)
{
    flush: <nil>,
    error_fn: <nil>,
    teardown: <nil>,
    context: rawptr,
    buffer: cstring,
    position: cstring,
    end: cstring,
    error: Mpack_Error_T,
    reserved: [2]size_t,
    builder: Mpack_Builder_T
}
/* Hide internals from documentation */
/** @cond */
Mpack_Reader_T :: struct #align(8)
{
    context: rawptr,
    fill: <nil>,
    error_fn: <nil>,
    teardown: <nil>,
    skip: <nil>,
    buffer: cstring,
    size: Size_T,
    data: cstring,
    end: cstring,
    error: Mpack_Error_T
}
/* Hide internals from documentation */
/** @cond */
Mpack_Node_T :: struct #align(8)
{
    data: <nil>,
    tree: <nil>
}
_Unnamed_At_Third_Party_Api_Mpack_H_6892_5 :: struct #align(8) #raw_union
{
    b: c.bool,
    f: c.float,
    d: c.double,
    i: uint8_t,
    u: uint64_t,
    offset: Size_T,
    children: <nil>
}
Mpack_Node_Data_T :: struct #align(8)
{
    type: Mpack_Type_T,
    len: uint16_t,
    value: _Unnamed_At_Third_Party_Api_Mpack_H_6892_5
}
Mpack_Tree_Parse_State_T :: enum int32_t
{
    MPACK_TREE_PARSE_STATE_NOT_STARTED = 0,
    MPACK_TREE_PARSE_STATE_IN_PROGRESS = 1,
    MPACK_TREE_PARSE_STATE_PARSED = 2
}
Mpack_Level_T :: struct #align(8)
{
    child: [^]Mpack_Node_Data_T,
    left: Size_T
}
Mpack_Tree_Parser_T :: struct #align(8)
{
    state: Mpack_Tree_Parse_State_T,
    possible_nodes_left: Size_T,
    nodes: [^]Mpack_Node_Data_T,
    nodes_left: Size_T,
    current_node_reserved: Size_T,
    level: Size_T,
    stack: [^]Mpack_Level_T,
    stack_capacity: Size_T,
    stack_owned: c.bool,
    stack_local: [8]Mpack_Level_T
}
Mpack_Tree_Page_T :: struct #align(8)
{
    next: <nil>,
    nodes: [1]Mpack_Node_Data_T
}
Mpack_Tree_T :: struct #align(8)
{
    error_fn: <nil>,
    read_fn: <nil>,
    teardown: <nil>,
    context: rawptr,
    nil_node: Mpack_Node_Data_T,
    missing_node: Mpack_Node_Data_T,
    error: Mpack_Error_T,
    buffer: cstring,
    buffer_capacity: Size_T,
    data: cstring,
    data_length: Size_T,
    size: Size_T,
    node_count: Size_T,
    max_size: Size_T,
    max_nodes: Size_T,
    parser: Mpack_Tree_Parser_T,
    root: [^]Mpack_Node_Data_T,
    pool: [^]Mpack_Node_Data_T,
    pool_count: Size_T,
    next: [^]Mpack_Tree_Page_T
}
int32_t :: int32_t
Uint8_T :: c.uchar
Uint16_T :: c.ushort
Int8_T :: c.schar
Int16_T :: c.short
_Iobuf :: struct #align(8)
{
    _placeholder: rawptr
}
FILE :: _Iobuf
@(private="file") BIND_GEN_OPAQUE_T :: distinct rawptr
when ODIN_OS == .Windows { foreign import mpack_lib "mpack.lib"; } else { foreign import mpack_lib "mpack.a"; }
foreign mpack_lib
{
@(link_name="mpack_realloc") mpack_realloc :: proc "cdecl" (old_ptr: rawptr, used_size: Size_T, new_size: Size_T) -> rawptr ---
/**
 * Converts an MPack error to a string. This function returns an empty
 * string when MPACK_DEBUG is not set.
 */
@(link_name="mpack_error_to_string") mpack_error_to_string :: proc "cdecl" (error: Mpack_Error_T) -> cstring ---
/**
 * Converts an MPack type to a string. This function returns an empty
 * string when MPACK_DEBUG is not set.
 */
@(link_name="mpack_type_to_string") mpack_type_to_string :: proc "cdecl" (type: Mpack_Type_T) -> cstring ---
/** Generates a nil tag. */
@(link_name="mpack_tag_make_nil") mpack_tag_make_nil :: proc "cdecl" () -> Mpack_Tag_T ---
/** Generates a bool tag. */
@(link_name="mpack_tag_make_bool") mpack_tag_make_bool :: proc "cdecl" (value: c.bool) -> Mpack_Tag_T ---
/** Generates a bool tag with value true. */
@(link_name="mpack_tag_make_true") mpack_tag_make_true :: proc "cdecl" () -> Mpack_Tag_T ---
/** Generates a bool tag with value false. */
@(link_name="mpack_tag_make_false") mpack_tag_make_false :: proc "cdecl" () -> Mpack_Tag_T ---
/** Generates a signed int tag. */
@(link_name="mpack_tag_make_int") mpack_tag_make_int :: proc "cdecl" (value: uint8_t) -> Mpack_Tag_T ---
/** Generates an unsigned int tag. */
@(link_name="mpack_tag_make_uint") mpack_tag_make_uint :: proc "cdecl" (value: uint64_t) -> Mpack_Tag_T ---
/** Generates a float tag. */
@(link_name="mpack_tag_make_float") mpack_tag_make_float :: proc "cdecl" (value: c.float) -> Mpack_Tag_T ---
/** Generates a double tag. */
@(link_name="mpack_tag_make_double") mpack_tag_make_double :: proc "cdecl" (value: c.double) -> Mpack_Tag_T ---
/** Generates an array tag. */
@(link_name="mpack_tag_make_array") mpack_tag_make_array :: proc "cdecl" (count: uint16_t) -> Mpack_Tag_T ---
/** Generates a map tag. */
@(link_name="mpack_tag_make_map") mpack_tag_make_map :: proc "cdecl" (count: uint16_t) -> Mpack_Tag_T ---
/** Generates a str tag. */
@(link_name="mpack_tag_make_str") mpack_tag_make_str :: proc "cdecl" (length: uint16_t) -> Mpack_Tag_T ---
/** Generates a bin tag. */
@(link_name="mpack_tag_make_bin") mpack_tag_make_bin :: proc "cdecl" (length: uint16_t) -> Mpack_Tag_T ---
/**
 * Gets the type of a tag.
 */
@(link_name="mpack_tag_type") mpack_tag_type :: proc "cdecl" (tag: [^]Mpack_Tag_T) -> Mpack_Type_T ---
/**
 * Gets the boolean value of a bool-type tag. The tag must be of type @ref
 * mpack_type_bool.
 *
 * This asserts that the type in the tag is @ref mpack_type_bool. (No check is
 * performed if MPACK_DEBUG is not set.)
 */
@(link_name="mpack_tag_bool_value") mpack_tag_bool_value :: proc "cdecl" (tag: [^]Mpack_Tag_T) -> c.bool ---
/**
 * Gets the signed integer value of an int-type tag.
 *
 * This asserts that the type in the tag is @ref mpack_type_int. (No check is
 * performed if MPACK_DEBUG is not set.)
 *
 * @warning This does not convert between signed and unsigned tags! A positive
 * integer may be stored in a tag as either @ref mpack_type_int or @ref
 * mpack_type_uint. You must check the type first; this can only be used if the
 * type is @ref mpack_type_int.
 *
 * @see mpack_type_int
 */
@(link_name="mpack_tag_int_value") mpack_tag_int_value :: proc "cdecl" (tag: [^]Mpack_Tag_T) -> uint8_t ---
/**
 * Gets the unsigned integer value of a uint-type tag.
 *
 * This asserts that the type in the tag is @ref mpack_type_uint. (No check is
 * performed if MPACK_DEBUG is not set.)
 *
 * @warning This does not convert between signed and unsigned tags! A positive
 * integer may be stored in a tag as either @ref mpack_type_int or @ref
 * mpack_type_uint. You must check the type first; this can only be used if the
 * type is @ref mpack_type_uint.
 *
 * @see mpack_type_uint
 */
@(link_name="mpack_tag_uint_value") mpack_tag_uint_value :: proc "cdecl" (tag: [^]Mpack_Tag_T) -> uint64_t ---
@(link_name="mpack_tag_float_value") mpack_tag_float_value :: proc "cdecl" (tag: [^]Mpack_Tag_T) -> c.float ---
@(link_name="mpack_tag_double_value") mpack_tag_double_value :: proc "cdecl" (tag: [^]Mpack_Tag_T) -> c.double ---
/**
 * Gets the number of elements in an array tag.
 *
 * This asserts that the type in the tag is @ref mpack_type_array. (No check is
 * performed if MPACK_DEBUG is not set.)
 *
 * @see mpack_type_array
 */
@(link_name="mpack_tag_array_count") mpack_tag_array_count :: proc "cdecl" (tag: [^]Mpack_Tag_T) -> uint16_t ---
/**
 * Gets the number of key-value pairs in a map tag.
 *
 * This asserts that the type in the tag is @ref mpack_type_map. (No check is
 * performed if MPACK_DEBUG is not set.)
 *
 * @see mpack_type_map
 */
@(link_name="mpack_tag_map_count") mpack_tag_map_count :: proc "cdecl" (tag: [^]Mpack_Tag_T) -> uint16_t ---
/**
 * Gets the length in bytes of a str-type tag.
 *
 * This asserts that the type in the tag is @ref mpack_type_str. (No check is
 * performed if MPACK_DEBUG is not set.)
 *
 * @see mpack_type_str
 */
@(link_name="mpack_tag_str_length") mpack_tag_str_length :: proc "cdecl" (tag: [^]Mpack_Tag_T) -> uint16_t ---
/**
 * Gets the length in bytes of a bin-type tag.
 *
 * This asserts that the type in the tag is @ref mpack_type_bin. (No check is
 * performed if MPACK_DEBUG is not set.)
 *
 * @see mpack_type_bin
 */
@(link_name="mpack_tag_bin_length") mpack_tag_bin_length :: proc "cdecl" (tag: [^]Mpack_Tag_T) -> uint16_t ---
/**
 * Gets the length in bytes of a str-, bin- or ext-type tag.
 *
 * This asserts that the type in the tag is @ref mpack_type_str, @ref
 * mpack_type_bin or @ref mpack_type_ext. (No check is performed if MPACK_DEBUG
 * is not set.)
 *
 * @see mpack_type_str
 * @see mpack_type_bin
 * @see mpack_type_ext
 */
@(link_name="mpack_tag_bytes") mpack_tag_bytes :: proc "cdecl" (tag: [^]Mpack_Tag_T) -> uint16_t ---
/**
 * Compares two tags with an arbitrary fixed ordering. Returns 0 if the tags are
 * equal, a negative integer if left comes before right, or a positive integer
 * otherwise.
 *
 * \warning The ordering is not guaranteed to be preserved across MPack versions; do
 * not rely on it in persistent data.
 *
 * \warning Floating point numbers are compared bit-for-bit, not using the language's
 * operator==. This means that NaNs with matching representation will compare equal.
 * This behaviour is up for debate; see comments in the definition of mpack_tag_cmp().
 *
 * See mpack_tag_equal() for more information on when tags are considered equal.
 */
@(link_name="mpack_tag_cmp") mpack_tag_cmp :: proc "cdecl" (left: Mpack_Tag_T, right: Mpack_Tag_T) -> int32_t ---
/**
 * Compares two tags for equality. Tags are considered equal if the types are compatible
 * and the values (for non-compound types) are equal.
 *
 * The field width of variable-width fields is ignored (and in fact is not stored
 * in a tag), and positive numbers in signed integers are considered equal to their
 * unsigned counterparts. So for example the value 1 stored as a positive fixint
 * is equal to the value 1 stored in a 64-bit unsigned integer field.
 *
 * The "extension type" of an extension object is considered part of the value
 * and must match exactly.
 *
 * \warning Floating point numbers are compared bit-for-bit, not using the language's
 * operator==. This means that NaNs with matching representation will compare equal.
 * This behaviour is up for debate; see comments in the definition of mpack_tag_cmp().
 */
@(link_name="mpack_tag_equal") mpack_tag_equal :: proc "cdecl" (left: Mpack_Tag_T, right: Mpack_Tag_T) -> c.bool ---
/** \deprecated Renamed to mpack_tag_make_nil(). */
@(link_name="mpack_tag_nil") mpack_tag_nil :: proc "cdecl" () -> Mpack_Tag_T ---
/** \deprecated Renamed to mpack_tag_make_bool(). */
@(link_name="mpack_tag_bool") mpack_tag_bool :: proc "cdecl" (value: c.bool) -> Mpack_Tag_T ---
/** \deprecated Renamed to mpack_tag_make_true(). */
@(link_name="mpack_tag_true") mpack_tag_true :: proc "cdecl" () -> Mpack_Tag_T ---
/** \deprecated Renamed to mpack_tag_make_false(). */
@(link_name="mpack_tag_false") mpack_tag_false :: proc "cdecl" () -> Mpack_Tag_T ---
/** \deprecated Renamed to mpack_tag_make_int(). */
@(link_name="mpack_tag_int") mpack_tag_int :: proc "cdecl" (value: uint8_t) -> Mpack_Tag_T ---
/** \deprecated Renamed to mpack_tag_make_uint(). */
@(link_name="mpack_tag_uint") mpack_tag_uint :: proc "cdecl" (value: uint64_t) -> Mpack_Tag_T ---
/** \deprecated Renamed to mpack_tag_make_float(). */
@(link_name="mpack_tag_float") mpack_tag_float :: proc "cdecl" (value: c.float) -> Mpack_Tag_T ---
/** \deprecated Renamed to mpack_tag_make_double(). */
@(link_name="mpack_tag_double") mpack_tag_double :: proc "cdecl" (value: c.double) -> Mpack_Tag_T ---
/** \deprecated Renamed to mpack_tag_make_array(). */
@(link_name="mpack_tag_array") mpack_tag_array :: proc "cdecl" (count: Int32_T) -> Mpack_Tag_T ---
/** \deprecated Renamed to mpack_tag_make_map(). */
@(link_name="mpack_tag_map") mpack_tag_map :: proc "cdecl" (count: Int32_T) -> Mpack_Tag_T ---
/** \deprecated Renamed to mpack_tag_make_str(). */
@(link_name="mpack_tag_str") mpack_tag_str :: proc "cdecl" (length: Int32_T) -> Mpack_Tag_T ---
/** \deprecated Renamed to mpack_tag_make_bin(). */
@(link_name="mpack_tag_bin") mpack_tag_bin :: proc "cdecl" (length: Int32_T) -> Mpack_Tag_T ---
/*
 * Helpers to perform unaligned network-endian loads and stores
 * at arbitrary addresses. Byte-swapping builtins are used if they
 * are available and if they improve performance.
 *
 * These will remain available in the public API so feel free to
 * use them for other purposes, but they are undocumented.
 */
@(link_name="mpack_load_u8") mpack_load_u8 :: proc "cdecl" (p: cstring) -> Uint8_T ---
@(link_name="mpack_load_u16") mpack_load_u16 :: proc "cdecl" (p: cstring) -> Uint16_T ---
@(link_name="mpack_load_u32") mpack_load_u32 :: proc "cdecl" (p: cstring) -> uint16_t ---
@(link_name="mpack_load_u64") mpack_load_u64 :: proc "cdecl" (p: cstring) -> uint64_t ---
@(link_name="mpack_store_u8") mpack_store_u8 :: proc "cdecl" (p: cstring, val: Uint8_T) ---
@(link_name="mpack_store_u16") mpack_store_u16 :: proc "cdecl" (p: cstring, val: Uint16_T) ---
@(link_name="mpack_store_u32") mpack_store_u32 :: proc "cdecl" (p: cstring, val: uint16_t) ---
@(link_name="mpack_store_u64") mpack_store_u64 :: proc "cdecl" (p: cstring, val: uint64_t) ---
@(link_name="mpack_load_i8") mpack_load_i8 :: proc "cdecl" (p: cstring) -> Int8_T ---
@(link_name="mpack_load_i16") mpack_load_i16 :: proc "cdecl" (p: cstring) -> Int16_T ---
@(link_name="mpack_load_i32") mpack_load_i32 :: proc "cdecl" (p: cstring) -> Int32_T ---
@(link_name="mpack_load_i64") mpack_load_i64 :: proc "cdecl" (p: cstring) -> uint8_t ---
@(link_name="mpack_store_i8") mpack_store_i8 :: proc "cdecl" (p: cstring, val: Int8_T) ---
@(link_name="mpack_store_i16") mpack_store_i16 :: proc "cdecl" (p: cstring, val: Int16_T) ---
@(link_name="mpack_store_i32") mpack_store_i32 :: proc "cdecl" (p: cstring, val: Int32_T) ---
@(link_name="mpack_store_i64") mpack_store_i64 :: proc "cdecl" (p: cstring, val: uint8_t) ---
@(link_name="mpack_load_float") mpack_load_float :: proc "cdecl" (p: cstring) -> c.float ---
@(link_name="mpack_load_double") mpack_load_double :: proc "cdecl" (p: cstring) -> c.double ---
@(link_name="mpack_store_float") mpack_store_float :: proc "cdecl" (p: cstring, value: c.float) ---
@(link_name="mpack_store_double") mpack_store_double :: proc "cdecl" (p: cstring, value: c.double) ---
@(link_name="mpack_writer_track_push") mpack_writer_track_push :: proc "cdecl" (writer: [^]Mpack_Writer_T, type: Mpack_Type_T, count: uint16_t) ---
@(link_name="mpack_writer_track_push_builder") mpack_writer_track_push_builder :: proc "cdecl" (writer: [^]Mpack_Writer_T, type: Mpack_Type_T) ---
@(link_name="mpack_writer_track_pop") mpack_writer_track_pop :: proc "cdecl" (writer: [^]Mpack_Writer_T, type: Mpack_Type_T) ---
@(link_name="mpack_writer_track_pop_builder") mpack_writer_track_pop_builder :: proc "cdecl" (writer: [^]Mpack_Writer_T, type: Mpack_Type_T) ---
@(link_name="mpack_writer_track_bytes") mpack_writer_track_bytes :: proc "cdecl" (writer: [^]Mpack_Writer_T, count: Size_T) ---
/**
 * Initializes an MPack writer with the given buffer. The writer
 * does not assume ownership of the buffer.
 *
 * Trying to write past the end of the buffer will result in mpack_error_too_big
 * unless a flush function is set with mpack_writer_set_flush(). To use the data
 * without flushing, call mpack_writer_buffer_used() to determine the number of
 * bytes written.
 *
 * @param writer The MPack writer.
 * @param buffer The buffer into which to write MessagePack data.
 * @param size The size of the buffer.
 */
@(link_name="mpack_writer_init") mpack_writer_init :: proc "cdecl" (writer: [^]Mpack_Writer_T, buffer: cstring, size: Size_T) ---
/**
 * Initializes an MPack writer using a growable buffer.
 *
 * The data is placed in the given data pointer if and when the writer
 * is destroyed without error. The data pointer is NULL during writing,
 * and will remain NULL if an error occurs.
 *
 * The allocated data must be freed with MPACK_FREE() (or simply free()
 * if MPack's allocator hasn't been customized.)
 *
 * @throws mpack_error_memory if the buffer fails to grow when
 * flushing.
 *
 * @param writer The MPack writer.
 * @param data Where to place the allocated data.
 * @param size Where to write the size of the data.
 */
@(link_name="mpack_writer_init_growable") mpack_writer_init_growable :: proc "cdecl" (writer: [^]Mpack_Writer_T, data: [^]cstring, size: [^]Size_T) ---
/**
 * Initializes an MPack writer directly into an error state. Use this if you
 * are writing a wrapper to mpack_writer_init() which can fail its setup.
 */
@(link_name="mpack_writer_init_error") mpack_writer_init_error :: proc "cdecl" (writer: [^]Mpack_Writer_T, error: Mpack_Error_T) ---
/**
 * Initializes an MPack writer that writes to a file.
 *
 * @throws mpack_error_memory if allocation fails
 * @throws mpack_error_io if the file cannot be opened
 */
@(link_name="mpack_writer_init_filename") mpack_writer_init_filename :: proc "cdecl" (writer: [^]Mpack_Writer_T, filename: cstring) ---
/**
 * Deprecated.
 *
 * \deprecated Renamed to mpack_writer_init_filename().
 */
@(link_name="mpack_writer_init_file") mpack_writer_init_file :: proc "cdecl" (writer: [^]Mpack_Writer_T, filename: cstring) ---
/**
 * Initializes an MPack writer that writes to a libc FILE. This can be used to
 * write to stdout or stderr, or to a file opened separately.
 *
 * @param writer The MPack writer.
 * @param stdfile The FILE.
 * @param close_when_done If true, fclose() will be called on the FILE when it
 *         is no longer needed. If false, the file will not be flushed or
 *         closed when writing is done.
 *
 * @note The writer is buffered. If you want to write other data to the FILE in
 *         between messages, you must flush it first.
 *
 * @see mpack_writer_flush_message
 */
@(link_name="mpack_writer_init_stdfile") mpack_writer_init_stdfile :: proc "cdecl" (writer: [^]Mpack_Writer_T, stdfile: [^]FILE, close_when_done: c.bool) ---
/**
 * Cleans up the MPack writer, flushing and closing the underlying stream,
 * if any. Returns the final error state of the writer.
 *
 * No flushing is performed if the writer is in an error state. The attached
 * teardown function is called whether or not the writer is in an error state.
 *
 * This will assert in tracking mode if the writer is not in an error
 * state and has any unclosed compound types. If you want to cancel
 * writing in the middle of a document, you need to flag an error on
 * the writer before destroying it (such as mpack_error_data).
 *
 * Note that a writer may raise an error and call your error handler during
 * the final flush. It is safe to longjmp or throw out of this error handler,
 * but if you do, the writer will not be destroyed, and the teardown function
 * will not be called. You can still get the writer's error state, and you
 * must call @ref mpack_writer_destroy() again. (The second call is guaranteed
 * not to call your error handler again since the writer is already in an error
 * state.)
 *
 * @see mpack_writer_set_error_handler
 * @see mpack_writer_set_flush
 * @see mpack_writer_set_teardown
 * @see mpack_writer_flag_error
 * @see mpack_error_data
 */
@(link_name="mpack_writer_destroy") mpack_writer_destroy :: proc "cdecl" (writer: [^]Mpack_Writer_T) -> Mpack_Error_T ---
/**
 * Sets the custom pointer to pass to the writer callbacks, such as flush
 * or teardown.
 *
 * @param writer The MPack writer.
 * @param context User data to pass to the writer callbacks.
 *
 * @see mpack_writer_context()
 */
@(link_name="mpack_writer_set_context") mpack_writer_set_context :: proc "cdecl" (writer: [^]Mpack_Writer_T, context: rawptr) ---
/**
 * Returns the custom context for writer callbacks.
 *
 * @see mpack_writer_set_context
 * @see mpack_writer_set_flush
 */
@(link_name="mpack_writer_context") mpack_writer_context :: proc "cdecl" (writer: [^]Mpack_Writer_T) -> rawptr ---
/**
 * Sets the flush function to write out the data when the buffer is full.
 *
 * If no flush function is used, trying to write past the end of the
 * buffer will result in mpack_error_too_big.
 *
 * This should normally be used with mpack_writer_set_context() to register
 * a custom pointer to pass to the flush function.
 *
 * @param writer The MPack writer.
 * @param flush The function to write out data from the buffer.
 *
 * @see mpack_writer_context()
 */
@(link_name="mpack_writer_set_flush") mpack_writer_set_flush :: proc "cdecl" (writer: [^]Mpack_Writer_T, flush: <nil>) ---
/**
 * Sets the error function to call when an error is flagged on the writer.
 *
 * This should normally be used with mpack_writer_set_context() to register
 * a custom pointer to pass to the error function.
 *
 * See the definition of mpack_writer_error_t for more information about
 * what you can do from an error callback.
 *
 * @see mpack_writer_error_t
 * @param writer The MPack writer.
 * @param error_fn The function to call when an error is flagged on the writer.
 */
@(link_name="mpack_writer_set_error_handler") mpack_writer_set_error_handler :: proc "cdecl" (writer: [^]Mpack_Writer_T, error_fn: <nil>) ---
/**
 * Sets the teardown function to call when the writer is destroyed.
 *
 * This should normally be used with mpack_writer_set_context() to register
 * a custom pointer to pass to the teardown function.
 *
 * @param writer The MPack writer.
 * @param teardown The function to call when the writer is destroyed.
 */
@(link_name="mpack_writer_set_teardown") mpack_writer_set_teardown :: proc "cdecl" (writer: [^]Mpack_Writer_T, teardown: <nil>) ---
/**
 * Flushes any buffered data to the underlying stream.
 *
 * If the writer is connected to a socket and you are keeping it open,
 * you will want to call this after writing a message (or set of
 * messages) so that the data is actually sent.
 *
 * It is not necessary to call this if you are not keeping the writer
 * open afterwards. You can just call `mpack_writer_destroy()` and it
 * will flush before cleaning up.
 *
 * This will assert if no flush function is assigned to the writer.
 *
 * If write tracking is enabled, this will break and flag @ref
 * mpack_error_bug if the writer has any open compound types, ensuring
 * that no compound types are still open. This prevents a "missing
 * finish" bug from causing a never-ending message.
 */
@(link_name="mpack_writer_flush_message") mpack_writer_flush_message :: proc "cdecl" (writer: [^]Mpack_Writer_T) ---
/**
 * Returns the number of bytes currently stored in the buffer. This
 * may be less than the total number of bytes written if bytes have
 * been flushed to an underlying stream.
 */
@(link_name="mpack_writer_buffer_used") mpack_writer_buffer_used :: proc "cdecl" (writer: [^]Mpack_Writer_T) -> Size_T ---
/**
 * Returns the amount of space left in the buffer. This may be reset
 * after a write if bytes are flushed to an underlying stream.
 */
@(link_name="mpack_writer_buffer_left") mpack_writer_buffer_left :: proc "cdecl" (writer: [^]Mpack_Writer_T) -> Size_T ---
/**
 * Returns the (current) size of the buffer. This may change after a write if
 * the flush callback changes the buffer.
 */
@(link_name="mpack_writer_buffer_size") mpack_writer_buffer_size :: proc "cdecl" (writer: [^]Mpack_Writer_T) -> Size_T ---
/**
 * Places the writer in the given error state, calling the error callback if one
 * is set.
 *
 * This allows you to externally flag errors, for example if you are validating
 * data as you write it, or if you want to cancel writing in the middle of a
 * document. (The writer will assert if you try to destroy it without error and
 * with unclosed compound types. In this case you should flag mpack_error_data
 * before destroying it.)
 *
 * If the writer is already in an error state, this call is ignored and no
 * error callback is called.
 *
 * @see mpack_writer_destroy
 * @see mpack_error_data
 */
@(link_name="mpack_writer_flag_error") mpack_writer_flag_error :: proc "cdecl" (writer: [^]Mpack_Writer_T, error: Mpack_Error_T) ---
/**
 * Queries the error state of the MPack writer.
 *
 * If a writer is in an error state, you should discard all data since the
 * last time the error flag was checked. The error flag cannot be cleared.
 */
@(link_name="mpack_writer_error") mpack_writer_error :: proc "cdecl" (writer: [^]Mpack_Writer_T) -> Mpack_Error_T ---
/**
 * Writes a MessagePack object header (an MPack Tag.)
 *
 * If the value is a map, array, string, binary or extension type, the
 * containing elements or bytes must be written separately and the
 * appropriate finish function must be called (as though one of the
 * mpack_start_*() functions was called.)
 *
 * @see mpack_write_bytes()
 * @see mpack_finish_map()
 * @see mpack_finish_array()
 * @see mpack_finish_str()
 * @see mpack_finish_bin()
 * @see mpack_finish_ext()
 * @see mpack_finish_type()
 */
@(link_name="mpack_write_tag") mpack_write_tag :: proc "cdecl" (writer: [^]Mpack_Writer_T, tag: Mpack_Tag_T) ---
/** Writes an 8-bit integer in the most efficient packing available. */
@(link_name="mpack_write_i8") mpack_write_i8 :: proc "cdecl" (writer: [^]Mpack_Writer_T, value: Int8_T) ---
/** Writes a 16-bit integer in the most efficient packing available. */
@(link_name="mpack_write_i16") mpack_write_i16 :: proc "cdecl" (writer: [^]Mpack_Writer_T, value: Int16_T) ---
/** Writes a 32-bit integer in the most efficient packing available. */
@(link_name="mpack_write_i32") mpack_write_i32 :: proc "cdecl" (writer: [^]Mpack_Writer_T, value: Int32_T) ---
/** Writes a 64-bit integer in the most efficient packing available. */
@(link_name="mpack_write_i64") mpack_write_i64 :: proc "cdecl" (writer: [^]Mpack_Writer_T, value: uint8_t) ---
/** Writes an integer in the most efficient packing available. */
@(link_name="mpack_write_int") mpack_write_int :: proc "cdecl" (writer: [^]Mpack_Writer_T, value: uint8_t) ---
/** Writes an 8-bit unsigned integer in the most efficient packing available. */
@(link_name="mpack_write_u8") mpack_write_u8 :: proc "cdecl" (writer: [^]Mpack_Writer_T, value: Uint8_T) ---
/** Writes an 16-bit unsigned integer in the most efficient packing available. */
@(link_name="mpack_write_u16") mpack_write_u16 :: proc "cdecl" (writer: [^]Mpack_Writer_T, value: Uint16_T) ---
/** Writes an 32-bit unsigned integer in the most efficient packing available. */
@(link_name="mpack_write_u32") mpack_write_u32 :: proc "cdecl" (writer: [^]Mpack_Writer_T, value: uint16_t) ---
/** Writes an 64-bit unsigned integer in the most efficient packing available. */
@(link_name="mpack_write_u64") mpack_write_u64 :: proc "cdecl" (writer: [^]Mpack_Writer_T, value: uint64_t) ---
/** Writes an unsigned integer in the most efficient packing available. */
@(link_name="mpack_write_uint") mpack_write_uint :: proc "cdecl" (writer: [^]Mpack_Writer_T, value: uint64_t) ---
/** Writes a float. */
@(link_name="mpack_write_float") mpack_write_float :: proc "cdecl" (writer: [^]Mpack_Writer_T, value: c.float) ---
/** Writes a double. */
@(link_name="mpack_write_double") mpack_write_double :: proc "cdecl" (writer: [^]Mpack_Writer_T, value: c.double) ---
/** Writes a boolean. */
@(link_name="mpack_write_bool") mpack_write_bool :: proc "cdecl" (writer: [^]Mpack_Writer_T, value: c.bool) ---
/** Writes a boolean with value true. */
@(link_name="mpack_write_true") mpack_write_true :: proc "cdecl" (writer: [^]Mpack_Writer_T) ---
/** Writes a boolean with value false. */
@(link_name="mpack_write_false") mpack_write_false :: proc "cdecl" (writer: [^]Mpack_Writer_T) ---
/** Writes a nil. */
@(link_name="mpack_write_nil") mpack_write_nil :: proc "cdecl" (writer: [^]Mpack_Writer_T) ---
/** Write a pre-encoded messagepack object */
@(link_name="mpack_write_object_bytes") mpack_write_object_bytes :: proc "cdecl" (writer: [^]Mpack_Writer_T, data: cstring, bytes: Size_T) ---
/**
 * Opens an array.
 *
 * `count` elements must follow, and mpack_finish_array() must be called
 * when done.
 *
 * If you do not know the number of elements to be written ahead of time, call
 * mpack_build_array() instead.
 *
 * @see mpack_finish_array()
 * @see mpack_build_array() to count the number of elements automatically
 */
@(link_name="mpack_start_array") mpack_start_array :: proc "cdecl" (writer: [^]Mpack_Writer_T, count: uint16_t) ---
/**
 * Opens a map.
 *
 * `count * 2` elements must follow, and mpack_finish_map() must be called
 * when done.
 *
 * If you do not know the number of elements to be written ahead of time, call
 * mpack_build_map() instead.
 *
 * Remember that while map elements in MessagePack are implicitly ordered,
 * they are not ordered in JSON. If you need elements to be read back
 * in the order they are written, consider use an array instead.
 *
 * @see mpack_finish_map()
 * @see mpack_build_map() to count the number of key/value pairs automatically
 */
@(link_name="mpack_start_map") mpack_start_map :: proc "cdecl" (writer: [^]Mpack_Writer_T, count: uint16_t) ---
@(link_name="mpack_builder_compound_push") mpack_builder_compound_push :: proc "cdecl" (writer: [^]Mpack_Writer_T) ---
@(link_name="mpack_builder_compound_pop") mpack_builder_compound_pop :: proc "cdecl" (writer: [^]Mpack_Writer_T) ---
/**
 * Finishes writing an array.
 *
 * This should be called only after a corresponding call to mpack_start_array()
 * and after the array contents are written.
 *
 * In debug mode (or if MPACK_WRITE_TRACKING is not 0), this will track writes
 * to ensure that the correct number of elements are written.
 *
 * @see mpack_start_array()
 */
@(link_name="mpack_finish_array") mpack_finish_array :: proc "cdecl" (writer: [^]Mpack_Writer_T) ---
/**
 * Finishes writing a map.
 *
 * This should be called only after a corresponding call to mpack_start_map()
 * and after the map contents are written.
 *
 * In debug mode (or if MPACK_WRITE_TRACKING is not 0), this will track writes
 * to ensure that the correct number of elements are written.
 *
 * @see mpack_start_map()
 */
@(link_name="mpack_finish_map") mpack_finish_map :: proc "cdecl" (writer: [^]Mpack_Writer_T) ---
/**
 * Starts building an array.
 *
 * Elements must follow, and mpack_complete_array() must be called when done. The
 * number of elements is determined automatically.
 *
 * If you know ahead of time the number of elements in the array, it is more
 * efficient to call mpack_start_array() instead, even if you are already
 * within another open build.
 *
 * Builder containers can be nested within normal (known size) containers and
 * vice versa. You can call mpack_build_array(), then mpack_start_array()
 * inside it, then mpack_build_array() inside that, and so forth.
 *
 * @see mpack_complete_array() to complete this array
 * @see mpack_start_array() if you already know the size of the array
 * @see mpack_build_map() for implementation details
 */
@(link_name="mpack_build_array") mpack_build_array :: proc "cdecl" (writer: [^]Mpack_Writer_T) ---
/**
 * Starts building a map.
 *
 * An even number of elements must follow, and mpack_complete_map() must be
 * called when done. The number of elements is determined automatically.
 *
 * If you know ahead of time the number of elements in the map, it is more
 * efficient to call mpack_start_map() instead, even if you are already within
 * another open build.
 *
 * Builder containers can be nested within normal (known size) containers and
 * vice versa. You can call mpack_build_map(), then mpack_start_map() inside
 * it, then mpack_build_map() inside that, and so forth.
 *
 * A writer in build mode diverts writes to a builder buffer that allocates as
 * needed. Once the last map or array being built is completed, the deferred
 * message is composed with computed array and map sizes into the writer.
 * Builder maps and arrays are encoded exactly the same as ordinary maps and
 * arrays in the final message.
 *
 * This indirect encoding is costly, as it incurs at least an extra copy of all
 * data written within a builder (but not additional copies for nested
 * builders.) Expect a speed penalty of half or more.
 *
 * A good strategy is to use this during early development when your messages
 * are constantly changing, and then closer to release when your message
 * formats have stabilized, replace all your build calls with start calls with
 * pre-computed sizes. Or don't, if you find the builder has little impact on
 * performance, because even with builders MPack is extremely fast.
 *
 * @note When an array or map starts being built, nothing will be flushed
 *       until it is completed. If you are building a large message that
 *       does not fit in the output stream, you won't get an error about it
 *       until everything is written.
 *
 * @see mpack_complete_map() to complete this map
 * @see mpack_start_map() if you already know the size of the map
 */
@(link_name="mpack_build_map") mpack_build_map :: proc "cdecl" (writer: [^]Mpack_Writer_T) ---
/**
 * Completes an array being built.
 *
 * @see mpack_build_array()
 */
@(link_name="mpack_complete_array") mpack_complete_array :: proc "cdecl" (writer: [^]Mpack_Writer_T) ---
/**
 * Completes a map being built.
 *
 * @see mpack_build_map()
 */
@(link_name="mpack_complete_map") mpack_complete_map :: proc "cdecl" (writer: [^]Mpack_Writer_T) ---
/**
 * Writes a string.
 *
 * To stream a string in chunks, use mpack_start_str() instead.
 *
 * MPack does not care about the underlying encoding, but UTF-8 is highly
 * recommended, especially for compatibility with JSON. You should consider
 * calling mpack_write_utf8() instead, especially if you will be reading
 * it back as UTF-8.
 *
 * You should not call mpack_finish_str() after calling this; this
 * performs both start and finish.
 */
@(link_name="mpack_write_str") mpack_write_str :: proc "cdecl" (writer: [^]Mpack_Writer_T, str: cstring, length: uint16_t) ---
/**
 * Writes a string, ensuring that it is valid UTF-8.
 *
 * This does not accept any UTF-8 variant such as Modified UTF-8, CESU-8 or
 * WTF-8. Only pure UTF-8 is allowed.
 *
 * You should not call mpack_finish_str() after calling this; this
 * performs both start and finish.
 *
 * @throws mpack_error_invalid if the string is not valid UTF-8
 */
@(link_name="mpack_write_utf8") mpack_write_utf8 :: proc "cdecl" (writer: [^]Mpack_Writer_T, str: cstring, length: uint16_t) ---
/**
 * Writes a null-terminated string. (The null-terminator is not written.)
 *
 * MPack does not care about the underlying encoding, but UTF-8 is highly
 * recommended, especially for compatibility with JSON. You should consider
 * calling mpack_write_utf8_cstr() instead, especially if you will be reading
 * it back as UTF-8.
 *
 * You should not call mpack_finish_str() after calling this; this
 * performs both start and finish.
 */
@(link_name="mpack_write_cstr") mpack_write_cstr :: proc "cdecl" (writer: [^]Mpack_Writer_T, cstr: cstring) ---
/**
 * Writes a null-terminated string, or a nil node if the given cstr pointer
 * is NULL. (The null-terminator is not written.)
 *
 * MPack does not care about the underlying encoding, but UTF-8 is highly
 * recommended, especially for compatibility with JSON. You should consider
 * calling mpack_write_utf8_cstr_or_nil() instead, especially if you will
 * be reading it back as UTF-8.
 *
 * You should not call mpack_finish_str() after calling this; this
 * performs both start and finish.
 */
@(link_name="mpack_write_cstr_or_nil") mpack_write_cstr_or_nil :: proc "cdecl" (writer: [^]Mpack_Writer_T, cstr: cstring) ---
/**
 * Writes a null-terminated string, ensuring that it is valid UTF-8. (The
 * null-terminator is not written.)
 *
 * This does not accept any UTF-8 variant such as Modified UTF-8, CESU-8 or
 * WTF-8. Only pure UTF-8 is allowed.
 *
 * You should not call mpack_finish_str() after calling this; this
 * performs both start and finish.
 *
 * @throws mpack_error_invalid if the string is not valid UTF-8
 */
@(link_name="mpack_write_utf8_cstr") mpack_write_utf8_cstr :: proc "cdecl" (writer: [^]Mpack_Writer_T, cstr: cstring) ---
/**
 * Writes a null-terminated string ensuring that it is valid UTF-8, or
 * writes nil if the given cstr pointer is NULL. (The null-terminator
 * is not written.)
 *
 * This does not accept any UTF-8 variant such as Modified UTF-8, CESU-8 or
 * WTF-8. Only pure UTF-8 is allowed.
 *
 * You should not call mpack_finish_str() after calling this; this
 * performs both start and finish.
 *
 * @throws mpack_error_invalid if the string is not valid UTF-8
 */
@(link_name="mpack_write_utf8_cstr_or_nil") mpack_write_utf8_cstr_or_nil :: proc "cdecl" (writer: [^]Mpack_Writer_T, cstr: cstring) ---
/**
 * Writes a binary blob.
 *
 * To stream a binary blob in chunks, use mpack_start_bin() instead.
 *
 * You should not call mpack_finish_bin() after calling this; this
 * performs both start and finish.
 */
@(link_name="mpack_write_bin") mpack_write_bin :: proc "cdecl" (writer: [^]Mpack_Writer_T, data: cstring, count: uint16_t) ---
/**
 * Opens a string. `count` bytes should be written with calls to
 * mpack_write_bytes(), and mpack_finish_str() should be called
 * when done.
 *
 * To write an entire string at once, use mpack_write_str() or
 * mpack_write_cstr() instead.
 *
 * MPack does not care about the underlying encoding, but UTF-8 is highly
 * recommended, especially for compatibility with JSON.
 */
@(link_name="mpack_start_str") mpack_start_str :: proc "cdecl" (writer: [^]Mpack_Writer_T, count: uint16_t) ---
/**
 * Opens a binary blob. `count` bytes should be written with calls to
 * mpack_write_bytes(), and mpack_finish_bin() should be called
 * when done.
 */
@(link_name="mpack_start_bin") mpack_start_bin :: proc "cdecl" (writer: [^]Mpack_Writer_T, count: uint16_t) ---
/**
 * Writes a portion of bytes for a string, binary blob or extension type which
 * was opened by mpack_write_tag() or one of the mpack_start_*() functions.
 *
 * This can be called multiple times to write the data in chunks, as long as
 * the total amount of bytes written matches the count given when the compound
 * type was started.
 *
 * The corresponding mpack_finish_*() function must be called when done.
 *
 * To write an entire string, binary blob or extension type at
 * once, use one of the mpack_write_*() functions instead.
 *
 * @see mpack_write_tag()
 * @see mpack_start_str()
 * @see mpack_start_bin()
 * @see mpack_start_ext()
 * @see mpack_finish_str()
 * @see mpack_finish_bin()
 * @see mpack_finish_ext()
 * @see mpack_finish_type()
 */
@(link_name="mpack_write_bytes") mpack_write_bytes :: proc "cdecl" (writer: [^]Mpack_Writer_T, data: cstring, count: Size_T) ---
/**
 * Finishes writing a string.
 *
 * This should be called only after a corresponding call to mpack_start_str()
 * and after the string bytes are written with mpack_write_bytes().
 *
 * This will track writes to ensure that the correct number of elements are written.
 *
 * @see mpack_start_str()
 * @see mpack_write_bytes()
 */
@(link_name="mpack_finish_str") mpack_finish_str :: proc "cdecl" (writer: [^]Mpack_Writer_T) ---
/**
 * Finishes writing a binary blob.
 *
 * This should be called only after a corresponding call to mpack_start_bin()
 * and after the binary bytes are written with mpack_write_bytes().
 *
 * This will track writes to ensure that the correct number of bytes are written.
 *
 * @see mpack_start_bin()
 * @see mpack_write_bytes()
 */
@(link_name="mpack_finish_bin") mpack_finish_bin :: proc "cdecl" (writer: [^]Mpack_Writer_T) ---
/**
 * Finishes writing the given compound type.
 *
 * This will track writes to ensure that the correct number of elements
 * or bytes are written.
 *
 * This can be called with the appropriate type instead the corresponding
 * mpack_finish_*() function if you want to finish a dynamic type.
 */
@(link_name="mpack_finish_type") mpack_finish_type :: proc "cdecl" (writer: [^]Mpack_Writer_T, type: Mpack_Type_T) ---
/**
 * Initializes an MPack reader with the given buffer. The reader does
 * not assume ownership of the buffer, but the buffer must be writeable
 * if a fill function will be used to refill it.
 *
 * @param reader The MPack reader.
 * @param buffer The buffer with which to read MessagePack data.
 * @param size The size of the buffer.
 * @param count The number of bytes already in the buffer.
 */
@(link_name="mpack_reader_init") mpack_reader_init :: proc "cdecl" (reader: [^]Mpack_Reader_T, buffer: cstring, size: Size_T, count: Size_T) ---
/**
 * Initializes an MPack reader directly into an error state. Use this if you
 * are writing a wrapper to mpack_reader_init() which can fail its setup.
 */
@(link_name="mpack_reader_init_error") mpack_reader_init_error :: proc "cdecl" (reader: [^]Mpack_Reader_T, error: Mpack_Error_T) ---
/**
 * Initializes an MPack reader to parse a pre-loaded contiguous chunk of data. The
 * reader does not assume ownership of the data.
 *
 * @param reader The MPack reader.
 * @param data The data to parse.
 * @param count The number of bytes pointed to by data.
 */
@(link_name="mpack_reader_init_data") mpack_reader_init_data :: proc "cdecl" (reader: [^]Mpack_Reader_T, data: cstring, count: Size_T) ---
/**
 * Initializes an MPack reader that reads from a file.
 *
 * The file will be automatically opened and closed by the reader.
 */
@(link_name="mpack_reader_init_filename") mpack_reader_init_filename :: proc "cdecl" (reader: [^]Mpack_Reader_T, filename: cstring) ---
/**
 * Deprecated.
 *
 * \deprecated Renamed to mpack_reader_init_filename().
 */
@(link_name="mpack_reader_init_file") mpack_reader_init_file :: proc "cdecl" (reader: [^]Mpack_Reader_T, filename: cstring) ---
/**
 * Initializes an MPack reader that reads from a libc FILE. This can be used to
 * read from stdin, or from a file opened separately.
 *
 * @param reader The MPack reader.
 * @param stdfile The FILE.
 * @param close_when_done If true, fclose() will be called on the FILE when it
 *         is no longer needed. If false, the file will not be closed when
 *         reading is done.
 *
 * @warning The reader is buffered. It will read data in advance of parsing it,
 * and it may read more data than it parsed. See mpack_reader_remaining() to
 * access the extra data.
 */
@(link_name="mpack_reader_init_stdfile") mpack_reader_init_stdfile :: proc "cdecl" (reader: [^]Mpack_Reader_T, stdfile: [^]FILE, close_when_done: c.bool) ---
/**
 * Cleans up the MPack reader, ensuring that all compound elements
 * have been completely read. Returns the final error state of the
 * reader.
 *
 * This will assert in tracking mode if the reader is not in an error
 * state and has any incomplete reads. If you want to cancel reading
 * in the middle of a document, you need to flag an error on the reader
 * before destroying it (such as mpack_error_data).
 *
 * @see mpack_read_tag()
 * @see mpack_reader_flag_error()
 * @see mpack_error_data
 */
@(link_name="mpack_reader_destroy") mpack_reader_destroy :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> Mpack_Error_T ---
/**
 * Sets the custom pointer to pass to the reader callbacks, such as fill
 * or teardown.
 *
 * @param reader The MPack reader.
 * @param context User data to pass to the reader callbacks.
 *
 * @see mpack_reader_context()
 */
@(link_name="mpack_reader_set_context") mpack_reader_set_context :: proc "cdecl" (reader: [^]Mpack_Reader_T, context: rawptr) ---
/**
 * Returns the custom context for reader callbacks.
 *
 * @see mpack_reader_set_context
 * @see mpack_reader_set_fill
 * @see mpack_reader_set_skip
 */
@(link_name="mpack_reader_context") mpack_reader_context :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> rawptr ---
/**
 * Sets the fill function to refill the data buffer when it runs out of data.
 *
 * If no fill function is used, truncated MessagePack data results in
 * mpack_error_invalid (since the buffer is assumed to contain a
 * complete MessagePack object.)
 *
 * If a fill function is used, truncated MessagePack data usually
 * results in mpack_error_io (since the fill function fails to get
 * the missing data.)
 *
 * This should normally be used with mpack_reader_set_context() to register
 * a custom pointer to pass to the fill function.
 *
 * @param reader The MPack reader.
 * @param fill The function to fetch additional data into the buffer.
 */
@(link_name="mpack_reader_set_fill") mpack_reader_set_fill :: proc "cdecl" (reader: [^]Mpack_Reader_T, fill: <nil>) ---
/**
 * Sets the skip function to discard bytes from the source stream.
 *
 * It's not necessary to implement this function. If the stream is not
 * seekable, don't set a skip callback. The reader will fall back to
 * using the fill function instead.
 *
 * This should normally be used with mpack_reader_set_context() to register
 * a custom pointer to pass to the skip function.
 *
 * The skip function is ignored in size-optimized builds to reduce code
 * size. Data will be skipped with the fill function when necessary.
 *
 * @param reader The MPack reader.
 * @param skip The function to discard bytes from the source stream.
 */
@(link_name="mpack_reader_set_skip") mpack_reader_set_skip :: proc "cdecl" (reader: [^]Mpack_Reader_T, skip: <nil>) ---
/**
 * Sets the error function to call when an error is flagged on the reader.
 *
 * This should normally be used with mpack_reader_set_context() to register
 * a custom pointer to pass to the error function.
 *
 * See the definition of mpack_reader_error_t for more information about
 * what you can do from an error callback.
 *
 * @see mpack_reader_error_t
 * @param reader The MPack reader.
 * @param error_fn The function to call when an error is flagged on the reader.
 */
@(link_name="mpack_reader_set_error_handler") mpack_reader_set_error_handler :: proc "cdecl" (reader: [^]Mpack_Reader_T, error_fn: <nil>) ---
/**
 * Sets the teardown function to call when the reader is destroyed.
 *
 * This should normally be used with mpack_reader_set_context() to register
 * a custom pointer to pass to the teardown function.
 *
 * @param reader The MPack reader.
 * @param teardown The function to call when the reader is destroyed.
 */
@(link_name="mpack_reader_set_teardown") mpack_reader_set_teardown :: proc "cdecl" (reader: [^]Mpack_Reader_T, teardown: <nil>) ---
/**
 * Queries the error state of the MPack reader.
 *
 * If a reader is in an error state, you should discard all data since the
 * last time the error flag was checked. The error flag cannot be cleared.
 */
@(link_name="mpack_reader_error") mpack_reader_error :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> Mpack_Error_T ---
/**
 * Places the reader in the given error state, calling the error callback if one
 * is set.
 *
 * This allows you to externally flag errors, for example if you are validating
 * data as you read it.
 *
 * If the reader is already in an error state, this call is ignored and no
 * error callback is called.
 */
@(link_name="mpack_reader_flag_error") mpack_reader_flag_error :: proc "cdecl" (reader: [^]Mpack_Reader_T, error: Mpack_Error_T) ---
/**
 * Places the reader in the given error state if the given error is not mpack_ok,
 * returning the resulting error state of the reader.
 *
 * This allows you to externally flag errors, for example if you are validating
 * data as you read it.
 *
 * If the given error is mpack_ok or if the reader is already in an error state,
 * this call is ignored and the actual error state of the reader is returned.
 */
@(link_name="mpack_reader_flag_if_error") mpack_reader_flag_if_error :: proc "cdecl" (reader: [^]Mpack_Reader_T, error: Mpack_Error_T) -> Mpack_Error_T ---
/**
 * Returns bytes left in the reader's buffer.
 *
 * If you are done reading MessagePack data but there is other interesting data
 * following it, the reader may have buffered too much data. The number of bytes
 * remaining in the buffer and a pointer to the position of those bytes can be
 * queried here.
 *
 * If you know the length of the MPack chunk beforehand, it's better to instead
 * have your fill function limit the data it reads so that the reader does not
 * have extra data. In this case you can simply check that this returns zero.
 *
 * Returns 0 if the reader is in an error state.
 *
 * @param reader The MPack reader from which to query remaining data.
 * @param data [out] A pointer to the remaining data, or NULL.
 * @return The number of bytes remaining in the buffer.
 */
@(link_name="mpack_reader_remaining") mpack_reader_remaining :: proc "cdecl" (reader: [^]Mpack_Reader_T, data: [^]cstring) -> Size_T ---
/**
 * Reads a MessagePack object header (an MPack tag.)
 *
 * If an error occurs, the reader is placed in an error state and a
 * nil tag is returned. If the reader is already in an error state,
 * a nil tag is returned.
 *
 * If the type is compound (i.e. is a map, array, string, binary or
 * extension type), additional reads are required to get the contained
 * data, and the corresponding done function must be called when done.
 *
 * @note Maps in JSON are unordered, so it is recommended not to expect
 * a specific ordering for your map values in case your data is converted
 * to/from JSON.
 *
 * @see mpack_read_bytes()
 * @see mpack_done_array()
 * @see mpack_done_map()
 * @see mpack_done_str()
 * @see mpack_done_bin()
 * @see mpack_done_ext()
 */
@(link_name="mpack_read_tag") mpack_read_tag :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> Mpack_Tag_T ---
/**
 * Parses the next MessagePack object header (an MPack tag) without
 * advancing the reader.
 *
 * If an error occurs, the reader is placed in an error state and a
 * nil tag is returned. If the reader is already in an error state,
 * a nil tag is returned.
 *
 * @note Maps in JSON are unordered, so it is recommended not to expect
 * a specific ordering for your map values in case your data is converted
 * to/from JSON.
 *
 * @see mpack_read_tag()
 * @see mpack_discard()
 */
@(link_name="mpack_peek_tag") mpack_peek_tag :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> Mpack_Tag_T ---
/**
 * Skips bytes from the underlying stream. This is used only to
 * skip the contents of a string, binary blob or extension object.
 */
@(link_name="mpack_skip_bytes") mpack_skip_bytes :: proc "cdecl" (reader: [^]Mpack_Reader_T, count: Size_T) ---
/**
 * Reads bytes from a string, binary blob or extension object, copying
 * them into the given buffer.
 *
 * A str, bin or ext must have been opened by a call to mpack_read_tag()
 * which yielded one of these types, or by a call to an expect function
 * such as mpack_expect_str() or mpack_expect_bin().
 *
 * If an error occurs, the buffer contents are undefined.
 *
 * This can be called multiple times for a single str, bin or ext
 * to read the data in chunks. The total data read must add up
 * to the size of the object.
 *
 * @param reader The MPack reader
 * @param p The buffer in which to copy the bytes
 * @param count The number of bytes to read
 */
@(link_name="mpack_read_bytes") mpack_read_bytes :: proc "cdecl" (reader: [^]Mpack_Reader_T, p: cstring, count: Size_T) ---
/**
 * Reads bytes from a string, ensures that the string is valid UTF-8,
 * and copies the bytes into the given buffer.
 *
 * A string must have been opened by a call to mpack_read_tag() which
 * yielded a string, or by a call to an expect function such as
 * mpack_expect_str().
 *
 * The given byte count must match the complete size of the string as
 * returned by the tag or expect function. You must ensure that the
 * buffer fits the data.
 *
 * This does not accept any UTF-8 variant such as Modified UTF-8, CESU-8 or
 * WTF-8. Only pure UTF-8 is allowed.
 *
 * If an error occurs, the buffer contents are undefined.
 *
 * Unlike mpack_read_bytes(), this cannot be used to read the data in
 * chunks (since this might split a character's UTF-8 bytes, and the
 * reader does not keep track of the UTF-8 decoding state between reads.)
 *
 * @throws mpack_error_type if the string contains invalid UTF-8.
 */
@(link_name="mpack_read_utf8") mpack_read_utf8 :: proc "cdecl" (reader: [^]Mpack_Reader_T, p: cstring, byte_count: Size_T) ---
/**
 * Reads bytes from a string, ensures that the string contains no NUL
 * bytes, copies the bytes into the given buffer and adds a null-terminator.
 *
 * A string must have been opened by a call to mpack_read_tag() which
 * yielded a string, or by a call to an expect function such as
 * mpack_expect_str().
 *
 * The given byte count must match the size of the string as returned
 * by the tag or expect function. The string will only be copied if
 * the buffer is large enough to store it.
 *
 * If an error occurs, the buffer will contain an empty string.
 *
 * @note If you know the object will be a string before reading it,
 * it is highly recommended to use mpack_expect_cstr() instead.
 * Alternatively you could use mpack_peek_tag() and call
 * mpack_expect_cstr() if it's a string.
 *
 * @throws mpack_error_too_big if the string plus null-terminator is larger than the given buffer size
 * @throws mpack_error_type if the string contains a null byte.
 *
 * @see mpack_peek_tag()
 * @see mpack_expect_cstr()
 * @see mpack_expect_utf8_cstr()
 */
@(link_name="mpack_read_cstr") mpack_read_cstr :: proc "cdecl" (reader: [^]Mpack_Reader_T, buf: cstring, buffer_size: Size_T, byte_count: Size_T) ---
/**
 * Reads bytes from a string, ensures that the string is valid UTF-8
 * with no NUL bytes, copies the bytes into the given buffer and adds a
 * null-terminator.
 *
 * A string must have been opened by a call to mpack_read_tag() which
 * yielded a string, or by a call to an expect function such as
 * mpack_expect_str().
 *
 * The given byte count must match the size of the string as returned
 * by the tag or expect function. The string will only be copied if
 * the buffer is large enough to store it.
 *
 * This does not accept any UTF-8 variant such as Modified UTF-8, CESU-8 or
 * WTF-8. Only pure UTF-8 is allowed, but without the NUL character, since
 * it cannot be represented in a null-terminated string.
 *
 * If an error occurs, the buffer will contain an empty string.
 *
 * @note If you know the object will be a string before reading it,
 * it is highly recommended to use mpack_expect_utf8_cstr() instead.
 * Alternatively you could use mpack_peek_tag() and call
 * mpack_expect_utf8_cstr() if it's a string.
 *
 * @throws mpack_error_too_big if the string plus null-terminator is larger than the given buffer size
 * @throws mpack_error_type if the string contains invalid UTF-8 or a null byte.
 *
 * @see mpack_peek_tag()
 * @see mpack_expect_utf8_cstr()
 */
@(link_name="mpack_read_utf8_cstr") mpack_read_utf8_cstr :: proc "cdecl" (reader: [^]Mpack_Reader_T, buf: cstring, buffer_size: Size_T, byte_count: Size_T) ---
/** @cond */
// This can optionally add a null-terminator, but it does not check
// whether the data contains null bytes. This must be done separately
// in a cstring read function (possibly as part of a UTF-8 check.)
@(link_name="mpack_read_bytes_alloc_impl") mpack_read_bytes_alloc_impl :: proc "cdecl" (reader: [^]Mpack_Reader_T, count: Size_T, null_terminated: c.bool) -> cstring ---
/**
 * Reads bytes from a string, binary blob or extension object, allocating
 * storage for them and returning the allocated pointer.
 *
 * The allocated string must be freed with MPACK_FREE() (or simply free()
 * if MPack's allocator hasn't been customized.)
 *
 * Returns NULL if any error occurs, or if count is zero.
 */
@(link_name="mpack_read_bytes_alloc") mpack_read_bytes_alloc :: proc "cdecl" (reader: [^]Mpack_Reader_T, count: Size_T) -> cstring ---
/**
 * Reads bytes from a string, binary blob or extension object in-place in
 * the buffer. This can be used to avoid copying the data.
 *
 * A str, bin or ext must have been opened by a call to mpack_read_tag()
 * which yielded one of these types, or by a call to an expect function
 * such as mpack_expect_str() or mpack_expect_bin().
 *
 * If the bytes are from a string, the string is not null-terminated! Use
 * mpack_read_cstr() to copy the string into a buffer and add a null-terminator.
 *
 * The returned pointer is invalidated on the next read, or when the buffer
 * is destroyed.
 *
 * The reader will move data around in the buffer if needed to ensure that
 * the pointer can always be returned, so this should only be used if
 * count is very small compared to the buffer size. If you need to check
 * whether a small size is reasonable (for example you intend to handle small and
 * large sizes differently), you can call mpack_should_read_bytes_inplace().
 *
 * This can be called multiple times for a single str, bin or ext
 * to read the data in chunks. The total data read must add up
 * to the size of the object.
 *
 * NULL is returned if the reader is in an error state.
 *
 * @throws mpack_error_too_big if the requested size is larger than the buffer size
 *
 * @see mpack_should_read_bytes_inplace()
 */
@(link_name="mpack_read_bytes_inplace") mpack_read_bytes_inplace :: proc "cdecl" (reader: [^]Mpack_Reader_T, count: Size_T) -> cstring ---
/**
 * Reads bytes from a string in-place in the buffer and ensures they are
 * valid UTF-8. This can be used to avoid copying the data.
 *
 * A string must have been opened by a call to mpack_read_tag() which
 * yielded a string, or by a call to an expect function such as
 * mpack_expect_str().
 *
 * The string is not null-terminated! Use mpack_read_utf8_cstr() to
 * copy the string into a buffer and add a null-terminator.
 *
 * The returned pointer is invalidated on the next read, or when the buffer
 * is destroyed.
 *
 * The reader will move data around in the buffer if needed to ensure that
 * the pointer can always be returned, so this should only be used if
 * count is very small compared to the buffer size. If you need to check
 * whether a small size is reasonable (for example you intend to handle small and
 * large sizes differently), you can call mpack_should_read_bytes_inplace().
 *
 * This does not accept any UTF-8 variant such as Modified UTF-8, CESU-8 or
 * WTF-8. Only pure UTF-8 is allowed.
 *
 * Unlike mpack_read_bytes_inplace(), this cannot be used to read the data in
 * chunks (since this might split a character's UTF-8 bytes, and the
 * reader does not keep track of the UTF-8 decoding state between reads.)
 *
 * NULL is returned if the reader is in an error state.
 *
 * @throws mpack_error_type if the string contains invalid UTF-8
 * @throws mpack_error_too_big if the requested size is larger than the buffer size
 *
 * @see mpack_should_read_bytes_inplace()
 */
@(link_name="mpack_read_utf8_inplace") mpack_read_utf8_inplace :: proc "cdecl" (reader: [^]Mpack_Reader_T, count: Size_T) -> cstring ---
/**
 * Returns true if it's a good idea to read the given number of bytes
 * in-place.
 *
 * If the read will be larger than some small fraction of the buffer size,
 * this will return false to avoid shuffling too much data back and forth
 * in the buffer.
 *
 * Use this if you're expecting arbitrary size data, and you want to read
 * in-place for the best performance when possible but will fall back to
 * a normal read if the data is too large.
 *
 * @see mpack_read_bytes_inplace()
 */
@(link_name="mpack_should_read_bytes_inplace") mpack_should_read_bytes_inplace :: proc "cdecl" (reader: [^]Mpack_Reader_T, count: Size_T) -> c.bool ---
@(link_name="mpack_done_type") mpack_done_type :: proc "cdecl" (reader: [^]Mpack_Reader_T, type: Mpack_Type_T) ---
/**
 * Finishes reading an array.
 *
 * This will track reads to ensure that the correct number of elements are read.
 */
@(link_name="mpack_done_array") mpack_done_array :: proc "cdecl" (reader: [^]Mpack_Reader_T) ---
/**
 * @fn mpack_done_map(mpack_reader_t* reader)
 *
 * Finishes reading a map.
 *
 * This will track reads to ensure that the correct number of elements are read.
 */
@(link_name="mpack_done_map") mpack_done_map :: proc "cdecl" (reader: [^]Mpack_Reader_T) ---
/**
 * @fn mpack_done_str(mpack_reader_t* reader)
 *
 * Finishes reading a string.
 *
 * This will track reads to ensure that the correct number of bytes are read.
 */
@(link_name="mpack_done_str") mpack_done_str :: proc "cdecl" (reader: [^]Mpack_Reader_T) ---
/**
 * @fn mpack_done_bin(mpack_reader_t* reader)
 *
 * Finishes reading a binary data blob.
 *
 * This will track reads to ensure that the correct number of bytes are read.
 */
@(link_name="mpack_done_bin") mpack_done_bin :: proc "cdecl" (reader: [^]Mpack_Reader_T) ---
/**
 * Reads and discards the next object. This will read and discard all
 * contained data as well if it is a compound type.
 */
@(link_name="mpack_discard") mpack_discard :: proc "cdecl" (reader: [^]Mpack_Reader_T) ---
/**
 * Reads an 8-bit unsigned integer.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in an 8-bit unsigned int.
 *
 * Returns zero if an error occurs.
 */
@(link_name="mpack_expect_u8") mpack_expect_u8 :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> Uint8_T ---
/**
 * Reads a 16-bit unsigned integer.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in a 16-bit unsigned int.
 *
 * Returns zero if an error occurs.
 */
@(link_name="mpack_expect_u16") mpack_expect_u16 :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> Uint16_T ---
/**
 * Reads a 32-bit unsigned integer.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in a 32-bit unsigned int.
 *
 * Returns zero if an error occurs.
 */
@(link_name="mpack_expect_u32") mpack_expect_u32 :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> uint16_t ---
/**
 * Reads a 64-bit unsigned integer.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in a 64-bit unsigned int.
 *
 * Returns zero if an error occurs.
 */
@(link_name="mpack_expect_u64") mpack_expect_u64 :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> uint64_t ---
/**
 * Reads an 8-bit signed integer.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in an 8-bit signed int.
 *
 * Returns zero if an error occurs.
 */
@(link_name="mpack_expect_i8") mpack_expect_i8 :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> Int8_T ---
/**
 * Reads a 16-bit signed integer.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in a 16-bit signed int.
 *
 * Returns zero if an error occurs.
 */
@(link_name="mpack_expect_i16") mpack_expect_i16 :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> Int16_T ---
/**
 * Reads a 32-bit signed integer.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in a 32-bit signed int.
 *
 * Returns zero if an error occurs.
 */
@(link_name="mpack_expect_i32") mpack_expect_i32 :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> Int32_T ---
/**
 * Reads a 64-bit signed integer.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in a 64-bit signed int.
 *
 * Returns zero if an error occurs.
 */
@(link_name="mpack_expect_i64") mpack_expect_i64 :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> uint8_t ---
/**
 * Reads a number, returning the value as a float. The underlying value can be an
 * integer, float or double; the value is converted to a float.
 *
 * @note Reading a double or a large integer with this function can incur a
 * loss of precision.
 *
 * @throws mpack_error_type if the underlying value is not a float, double or integer.
 */
@(link_name="mpack_expect_float") mpack_expect_float :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> c.float ---
/**
 * Reads a number, returning the value as a double. The underlying value can be an
 * integer, float or double; the value is converted to a double.
 *
 * @note Reading a very large integer with this function can incur a
 * loss of precision.
 *
 * @throws mpack_error_type if the underlying value is not a float, double or integer.
 */
@(link_name="mpack_expect_double") mpack_expect_double :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> c.double ---
/**
 * Reads a float. The underlying value must be a float, not a double or an integer.
 * This ensures no loss of precision can occur.
 *
 * @throws mpack_error_type if the underlying value is not a float.
 */
@(link_name="mpack_expect_float_strict") mpack_expect_float_strict :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> c.float ---
/**
 * Reads a double. The underlying value must be a float or double, not an integer.
 * This ensures no loss of precision can occur.
 *
 * @throws mpack_error_type if the underlying value is not a float or double.
 */
@(link_name="mpack_expect_double_strict") mpack_expect_double_strict :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> c.double ---
/**
 * Reads an 8-bit unsigned integer, ensuring that it falls within the given range.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in an 8-bit unsigned int.
 *
 * Returns min_value if an error occurs.
 */
@(link_name="mpack_expect_u8_range") mpack_expect_u8_range :: proc "cdecl" (reader: [^]Mpack_Reader_T, min_value: Uint8_T, max_value: Uint8_T) -> Uint8_T ---
/**
 * Reads a 16-bit unsigned integer, ensuring that it falls within the given range.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in a 16-bit unsigned int.
 *
 * Returns min_value if an error occurs.
 */
@(link_name="mpack_expect_u16_range") mpack_expect_u16_range :: proc "cdecl" (reader: [^]Mpack_Reader_T, min_value: Uint16_T, max_value: Uint16_T) -> Uint16_T ---
/**
 * Reads a 32-bit unsigned integer, ensuring that it falls within the given range.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in a 32-bit unsigned int.
 *
 * Returns min_value if an error occurs.
 */
@(link_name="mpack_expect_u32_range") mpack_expect_u32_range :: proc "cdecl" (reader: [^]Mpack_Reader_T, min_value: uint16_t, max_value: uint16_t) -> uint16_t ---
/**
 * Reads a 64-bit unsigned integer, ensuring that it falls within the given range.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in a 64-bit unsigned int.
 *
 * Returns min_value if an error occurs.
 */
@(link_name="mpack_expect_u64_range") mpack_expect_u64_range :: proc "cdecl" (reader: [^]Mpack_Reader_T, min_value: uint64_t, max_value: uint64_t) -> uint64_t ---
/**
 * Reads an unsigned integer, ensuring that it falls within the given range.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in an unsigned int.
 *
 * Returns min_value if an error occurs.
 */
@(link_name="mpack_expect_uint_range") mpack_expect_uint_range :: proc "cdecl" (reader: [^]Mpack_Reader_T, min_value: c.uint, max_value: c.uint) -> c.uint ---
/**
 * Reads an 8-bit unsigned integer, ensuring that it is at most @a max_value.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in an 8-bit unsigned int.
 *
 * Returns 0 if an error occurs.
 */
@(link_name="mpack_expect_u8_max") mpack_expect_u8_max :: proc "cdecl" (reader: [^]Mpack_Reader_T, max_value: Uint8_T) -> Uint8_T ---
/**
 * Reads a 16-bit unsigned integer, ensuring that it is at most @a max_value.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in a 16-bit unsigned int.
 *
 * Returns 0 if an error occurs.
 */
@(link_name="mpack_expect_u16_max") mpack_expect_u16_max :: proc "cdecl" (reader: [^]Mpack_Reader_T, max_value: Uint16_T) -> Uint16_T ---
/**
 * Reads a 32-bit unsigned integer, ensuring that it is at most @a max_value.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in a 32-bit unsigned int.
 *
 * Returns 0 if an error occurs.
 */
@(link_name="mpack_expect_u32_max") mpack_expect_u32_max :: proc "cdecl" (reader: [^]Mpack_Reader_T, max_value: uint16_t) -> uint16_t ---
/**
 * Reads a 64-bit unsigned integer, ensuring that it is at most @a max_value.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in a 64-bit unsigned int.
 *
 * Returns 0 if an error occurs.
 */
@(link_name="mpack_expect_u64_max") mpack_expect_u64_max :: proc "cdecl" (reader: [^]Mpack_Reader_T, max_value: uint64_t) -> uint64_t ---
/**
 * Reads an unsigned integer, ensuring that it is at most @a max_value.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in an unsigned int.
 *
 * Returns 0 if an error occurs.
 */
@(link_name="mpack_expect_uint_max") mpack_expect_uint_max :: proc "cdecl" (reader: [^]Mpack_Reader_T, max_value: c.uint) -> c.uint ---
/**
 * Reads an 8-bit signed integer, ensuring that it falls within the given range.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in an 8-bit signed int.
 *
 * Returns min_value if an error occurs.
 */
@(link_name="mpack_expect_i8_range") mpack_expect_i8_range :: proc "cdecl" (reader: [^]Mpack_Reader_T, min_value: Int8_T, max_value: Int8_T) -> Int8_T ---
/**
 * Reads a 16-bit signed integer, ensuring that it falls within the given range.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in a 16-bit signed int.
 *
 * Returns min_value if an error occurs.
 */
@(link_name="mpack_expect_i16_range") mpack_expect_i16_range :: proc "cdecl" (reader: [^]Mpack_Reader_T, min_value: Int16_T, max_value: Int16_T) -> Int16_T ---
/**
 * Reads a 32-bit signed integer, ensuring that it falls within the given range.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in a 32-bit signed int.
 *
 * Returns min_value if an error occurs.
 */
@(link_name="mpack_expect_i32_range") mpack_expect_i32_range :: proc "cdecl" (reader: [^]Mpack_Reader_T, min_value: Int32_T, max_value: Int32_T) -> Int32_T ---
/**
 * Reads a 64-bit signed integer, ensuring that it falls within the given range.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in a 64-bit signed int.
 *
 * Returns min_value if an error occurs.
 */
@(link_name="mpack_expect_i64_range") mpack_expect_i64_range :: proc "cdecl" (reader: [^]Mpack_Reader_T, min_value: uint8_t, max_value: uint8_t) -> uint8_t ---
/**
 * Reads a signed integer, ensuring that it falls within the given range.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in a signed int.
 *
 * Returns min_value if an error occurs.
 */
@(link_name="mpack_expect_int_range") mpack_expect_int_range :: proc "cdecl" (reader: [^]Mpack_Reader_T, min_value: int32_t, max_value: int32_t) -> int32_t ---
/**
 * Reads an 8-bit signed integer, ensuring that it is at least zero and at
 * most @a max_value.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in an 8-bit signed int.
 *
 * Returns 0 if an error occurs.
 */
@(link_name="mpack_expect_i8_max") mpack_expect_i8_max :: proc "cdecl" (reader: [^]Mpack_Reader_T, max_value: Int8_T) -> Int8_T ---
/**
 * Reads a 16-bit signed integer, ensuring that it is at least zero and at
 * most @a max_value.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in a 16-bit signed int.
 *
 * Returns 0 if an error occurs.
 */
@(link_name="mpack_expect_i16_max") mpack_expect_i16_max :: proc "cdecl" (reader: [^]Mpack_Reader_T, max_value: Int16_T) -> Int16_T ---
/**
 * Reads a 32-bit signed integer, ensuring that it is at least zero and at
 * most @a max_value.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in a 32-bit signed int.
 *
 * Returns 0 if an error occurs.
 */
@(link_name="mpack_expect_i32_max") mpack_expect_i32_max :: proc "cdecl" (reader: [^]Mpack_Reader_T, max_value: Int32_T) -> Int32_T ---
/**
 * Reads a 64-bit signed integer, ensuring that it is at least zero and at
 * most @a max_value.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in a 64-bit signed int.
 *
 * Returns 0 if an error occurs.
 */
@(link_name="mpack_expect_i64_max") mpack_expect_i64_max :: proc "cdecl" (reader: [^]Mpack_Reader_T, max_value: uint8_t) -> uint8_t ---
/**
 * Reads an int, ensuring that it is at least zero and at most @a max_value.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in a signed int.
 *
 * Returns 0 if an error occurs.
 */
@(link_name="mpack_expect_int_max") mpack_expect_int_max :: proc "cdecl" (reader: [^]Mpack_Reader_T, max_value: int32_t) -> int32_t ---
/**
 * Reads a number, ensuring that it falls within the given range and returning
 * the value as a float. The underlying value can be an integer, float or
 * double; the value is converted to a float.
 *
 * @note Reading a double or a large integer with this function can incur a
 * loss of precision.
 *
 * @throws mpack_error_type if the underlying value is not a float, double or integer.
 */
@(link_name="mpack_expect_float_range") mpack_expect_float_range :: proc "cdecl" (reader: [^]Mpack_Reader_T, min_value: c.float, max_value: c.float) -> c.float ---
/**
 * Reads a number, ensuring that it falls within the given range and returning
 * the value as a double. The underlying value can be an integer, float or
 * double; the value is converted to a double.
 *
 * @note Reading a very large integer with this function can incur a
 * loss of precision.
 *
 * @throws mpack_error_type if the underlying value is not a float, double or integer.
 */
@(link_name="mpack_expect_double_range") mpack_expect_double_range :: proc "cdecl" (reader: [^]Mpack_Reader_T, min_value: c.double, max_value: c.double) -> c.double ---
/**
 * Reads an unsigned int.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in an unsigned int.
 *
 * Returns zero if an error occurs.
 */
@(link_name="mpack_expect_uint") mpack_expect_uint :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> c.uint ---
/**
 * Reads a signed int.
 *
 * The underlying type may be an integer type of any size and signedness,
 * as long as the value can be represented in a signed int.
 *
 * Returns zero if an error occurs.
 */
@(link_name="mpack_expect_int") mpack_expect_int :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> int32_t ---
/**
 * Reads an unsigned integer, ensuring that it exactly matches the given value.
 *
 * mpack_error_type is raised if the value is not representable as an unsigned
 * integer or if it does not exactly match the given value.
 */
@(link_name="mpack_expect_uint_match") mpack_expect_uint_match :: proc "cdecl" (reader: [^]Mpack_Reader_T, value: uint64_t) ---
/**
 * Reads a signed integer, ensuring that it exactly matches the given value.
 *
 * mpack_error_type is raised if the value is not representable as a signed
 * integer or if it does not exactly match the given value.
 */
@(link_name="mpack_expect_int_match") mpack_expect_int_match :: proc "cdecl" (reader: [^]Mpack_Reader_T, value: uint8_t) ---
/**
 * Reads a nil, raising @ref mpack_error_type if the value is not nil.
 */
@(link_name="mpack_expect_nil") mpack_expect_nil :: proc "cdecl" (reader: [^]Mpack_Reader_T) ---
/**
 * Reads a boolean.
 *
 * @note Integers will raise mpack_error_type; the value must be strictly a boolean.
 */
@(link_name="mpack_expect_bool") mpack_expect_bool :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> c.bool ---
/**
 * Reads a boolean, raising @ref mpack_error_type if its value is not @c true.
 */
@(link_name="mpack_expect_true") mpack_expect_true :: proc "cdecl" (reader: [^]Mpack_Reader_T) ---
/**
 * Reads a boolean, raising @ref mpack_error_type if its value is not @c false.
 */
@(link_name="mpack_expect_false") mpack_expect_false :: proc "cdecl" (reader: [^]Mpack_Reader_T) ---
/**
 * Reads the start of a map, returning its element count.
 *
 * A number of values follow equal to twice the element count of the map,
 * alternating between keys and values. @ref mpack_done_map() must be called
 * once all elements have been read.
 *
 * @note Maps in JSON are unordered, so it is recommended not to expect
 * a specific ordering for your map values in case your data is converted
 * to/from JSON.
 *
 * @warning This call is dangerous! It does not have a size limit, and it
 * does not have any way of checking whether there is enough data in the
 * message (since the data could be coming from a stream.) When looping
 * through the map's contents, you must check for errors on each iteration
 * of the loop. Otherwise an attacker could craft a message declaring a map
 * of a billion elements which would throw your parsing code into an
 * infinite loop! You should strongly consider using mpack_expect_map_max()
 * with a safe maximum size instead.
 *
 * @throws mpack_error_type if the value is not a map.
 */
@(link_name="mpack_expect_map") mpack_expect_map :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> uint16_t ---
/**
 * Reads the start of a map with a number of elements in the given range, returning
 * its element count.
 *
 * A number of values follow equal to twice the element count of the map,
 * alternating between keys and values. @ref mpack_done_map() must be called
 * once all elements have been read.
 *
 * @note Maps in JSON are unordered, so it is recommended not to expect
 * a specific ordering for your map values in case your data is converted
 * to/from JSON.
 *
 * min_count is returned if an error occurs.
 *
 * @throws mpack_error_type if the value is not a map or if its size does
 * not fall within the given range.
 */
@(link_name="mpack_expect_map_range") mpack_expect_map_range :: proc "cdecl" (reader: [^]Mpack_Reader_T, min_count: uint16_t, max_count: uint16_t) -> uint16_t ---
/**
 * Reads the start of a map with a number of elements at most @a max_count,
 * returning its element count.
 *
 * A number of values follow equal to twice the element count of the map,
 * alternating between keys and values. @ref mpack_done_map() must be called
 * once all elements have been read.
 *
 * @note Maps in JSON are unordered, so it is recommended not to expect
 * a specific ordering for your map values in case your data is converted
 * to/from JSON.
 *
 * Zero is returned if an error occurs.
 *
 * @throws mpack_error_type if the value is not a map or if its size is
 * greater than max_count.
 */
@(link_name="mpack_expect_map_max") mpack_expect_map_max :: proc "cdecl" (reader: [^]Mpack_Reader_T, max_count: uint16_t) -> uint16_t ---
/**
 * Reads the start of a map of the exact size given.
 *
 * A number of values follow equal to twice the element count of the map,
 * alternating between keys and values. @ref mpack_done_map() must be called
 * once all elements have been read.
 *
 * @note Maps in JSON are unordered, so it is recommended not to expect
 * a specific ordering for your map values in case your data is converted
 * to/from JSON.
 *
 * @throws mpack_error_type if the value is not a map or if its size
 * does not match the given count.
 */
@(link_name="mpack_expect_map_match") mpack_expect_map_match :: proc "cdecl" (reader: [^]Mpack_Reader_T, count: uint16_t) ---
/**
 * Reads a nil node or the start of a map, returning whether a map was
 * read and placing its number of key/value pairs in count.
 *
 * If a map was read, a number of values follow equal to twice the element count
 * of the map, alternating between keys and values. @ref mpack_done_map() should
 * also be called once all elements have been read (only if a map was read.)
 *
 * @note Maps in JSON are unordered, so it is recommended not to expect
 * a specific ordering for your map values in case your data is converted
 * to/from JSON.
 *
 * @warning This call is dangerous! It does not have a size limit, and it
 * does not have any way of checking whether there is enough data in the
 * message (since the data could be coming from a stream.) When looping
 * through the map's contents, you must check for errors on each iteration
 * of the loop. Otherwise an attacker could craft a message declaring a map
 * of a billion elements which would throw your parsing code into an
 * infinite loop! You should strongly consider using mpack_expect_map_max_or_nil()
 * with a safe maximum size instead.
 *
 * @returns @c true if a map was read successfully; @c false if nil was read
 *     or an error occurred.
 * @throws mpack_error_type if the value is not a nil or map.
 */
@(link_name="mpack_expect_map_or_nil") mpack_expect_map_or_nil :: proc "cdecl" (reader: [^]Mpack_Reader_T, count: [^]uint16_t) -> c.bool ---
/**
 * Reads a nil node or the start of a map with a number of elements at most
 * max_count, returning whether a map was read and placing its number of
 * key/value pairs in count.
 *
 * If a map was read, a number of values follow equal to twice the element count
 * of the map, alternating between keys and values. @ref mpack_done_map() should
 * anlso be called once all elements have been read (only if a map was read.)
 *
 * @note Maps in JSON are unordered, so it is recommended not to expect
 * a specific ordering for your map values in case your data is converted
 * to/from JSON. Consider using mpack_expect_key_cstr() or mpack_expect_key_uint()
 * to switch on the key; see @ref docs/expect.md for examples.
 *
 * @returns @c true if a map was read successfully; @c false if nil was read
 *     or an error occurred.
 * @throws mpack_error_type if the value is not a nil or map.
 */
@(link_name="mpack_expect_map_max_or_nil") mpack_expect_map_max_or_nil :: proc "cdecl" (reader: [^]Mpack_Reader_T, max_count: uint16_t, count: [^]uint16_t) -> c.bool ---
/**
 * Reads the start of an array, returning its element count.
 *
 * A number of values follow equal to the element count of the array.
 * @ref mpack_done_array() must be called once all elements have been read.
 *
 * @warning This call is dangerous! It does not have a size limit, and it
 * does not have any way of checking whether there is enough data in the
 * message (since the data could be coming from a stream.) When looping
 * through the array's contents, you must check for errors on each iteration
 * of the loop. Otherwise an attacker could craft a message declaring an array
 * of a billion elements which would throw your parsing code into an
 * infinite loop! You should strongly consider using mpack_expect_array_max()
 * with a safe maximum size instead.
 */
@(link_name="mpack_expect_array") mpack_expect_array :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> uint16_t ---
/**
 * Reads the start of an array with a number of elements in the given range,
 * returning its element count.
 *
 * A number of values follow equal to the element count of the array.
 * @ref mpack_done_array() must be called once all elements have been read.
 *
 * min_count is returned if an error occurs.
 *
 * @throws mpack_error_type if the value is not an array or if its size does
 * not fall within the given range.
 */
@(link_name="mpack_expect_array_range") mpack_expect_array_range :: proc "cdecl" (reader: [^]Mpack_Reader_T, min_count: uint16_t, max_count: uint16_t) -> uint16_t ---
/**
 * Reads the start of an array with a number of elements at most @a max_count,
 * returning its element count.
 *
 * A number of values follow equal to the element count of the array.
 * @ref mpack_done_array() must be called once all elements have been read.
 *
 * Zero is returned if an error occurs.
 *
 * @throws mpack_error_type if the value is not an array or if its size is
 * greater than max_count.
 */
@(link_name="mpack_expect_array_max") mpack_expect_array_max :: proc "cdecl" (reader: [^]Mpack_Reader_T, max_count: uint16_t) -> uint16_t ---
/**
 * Reads the start of an array of the exact size given.
 *
 * A number of values follow equal to the element count of the array.
 * @ref mpack_done_array() must be called once all elements have been read.
 *
 * @throws mpack_error_type if the value is not an array or if its size does
 * not match the given count.
 */
@(link_name="mpack_expect_array_match") mpack_expect_array_match :: proc "cdecl" (reader: [^]Mpack_Reader_T, count: uint16_t) ---
/**
 * Reads a nil node or the start of an array, returning whether an array was
 * read and placing its number of elements in count.
 *
 * If an array was read, a number of values follow equal to the element count
 * of the array. @ref mpack_done_array() should also be called once all elements
 * have been read (only if an array was read.)
 *
 * @warning This call is dangerous! It does not have a size limit, and it
 * does not have any way of checking whether there is enough data in the
 * message (since the data could be coming from a stream.) When looping
 * through the array's contents, you must check for errors on each iteration
 * of the loop. Otherwise an attacker could craft a message declaring an array
 * of a billion elements which would throw your parsing code into an
 * infinite loop! You should strongly consider using mpack_expect_array_max_or_nil()
 * with a safe maximum size instead.
 *
 * @returns @c true if an array was read successfully; @c false if nil was read
 *     or an error occurred.
 * @throws mpack_error_type if the value is not a nil or array.
 */
@(link_name="mpack_expect_array_or_nil") mpack_expect_array_or_nil :: proc "cdecl" (reader: [^]Mpack_Reader_T, count: [^]uint16_t) -> c.bool ---
/**
 * Reads a nil node or the start of an array with a number of elements at most
 * max_count, returning whether an array was read and placing its number of
 * key/value pairs in count.
 *
 * If an array was read, a number of values follow equal to the element count
 * of the array. @ref mpack_done_array() should also be called once all elements
 * have been read (only if an array was read.)
 *
 * @returns @c true if an array was read successfully; @c false if nil was read
 *     or an error occurred.
 * @throws mpack_error_type if the value is not a nil or array.
 */
@(link_name="mpack_expect_array_max_or_nil") mpack_expect_array_max_or_nil :: proc "cdecl" (reader: [^]Mpack_Reader_T, max_count: uint16_t, count: [^]uint16_t) -> c.bool ---
@(link_name="mpack_expect_array_alloc_impl") mpack_expect_array_alloc_impl :: proc "cdecl" (reader: [^]Mpack_Reader_T, element_size: Size_T, max_count: uint16_t, out_count: [^]uint16_t, allow_nil: c.bool) -> rawptr ---
/**
 * Reads the start of a string, returning its size in bytes.
 *
 * The bytes follow and must be read separately with mpack_read_bytes()
 * or mpack_read_bytes_inplace(). mpack_done_str() must be called
 * once all bytes have been read.
 *
 * NUL bytes are allowed in the string, and no encoding checks are done.
 *
 * mpack_error_type is raised if the value is not a string.
 */
@(link_name="mpack_expect_str") mpack_expect_str :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> uint16_t ---
/**
 * Reads a string of at most the given size, writing it into the
 * given buffer and returning its size in bytes.
 *
 * This does not add a null-terminator! Use mpack_expect_cstr() to
 * add a null-terminator.
 *
 * NUL bytes are allowed in the string, and no encoding checks are done.
 */
@(link_name="mpack_expect_str_buf") mpack_expect_str_buf :: proc "cdecl" (reader: [^]Mpack_Reader_T, buf: cstring, bufsize: Size_T) -> Size_T ---
/**
 * Reads a string into the given buffer, ensuring it is a valid UTF-8 string
 * and returning its size in bytes.
 *
 * This does not add a null-terminator! Use mpack_expect_utf8_cstr() to
 * add a null-terminator.
 *
 * This does not accept any UTF-8 variant such as Modified UTF-8, CESU-8 or
 * WTF-8. Only pure UTF-8 is allowed.
 *
 * NUL bytes are allowed in the string (as they are in UTF-8.)
 *
 * Raises mpack_error_too_big if there is not enough room for the string.
 * Raises mpack_error_type if the value is not a string or is not a valid UTF-8 string.
 */
@(link_name="mpack_expect_utf8") mpack_expect_utf8 :: proc "cdecl" (reader: [^]Mpack_Reader_T, buf: cstring, bufsize: Size_T) -> Size_T ---
/**
 * Reads the start of a string, raising an error if its length is not
 * at most the given number of bytes (not including any null-terminator.)
 *
 * The bytes follow and must be read separately with mpack_read_bytes()
 * or mpack_read_bytes_inplace(). @ref mpack_done_str() must be called
 * once all bytes have been read.
 *
 * @throws mpack_error_type If the value is not a string.
 * @throws mpack_error_too_big If the string's length in bytes is larger than the given maximum size.
 */
@(link_name="mpack_expect_str_max") mpack_expect_str_max :: proc "cdecl" (reader: [^]Mpack_Reader_T, maxsize: uint16_t) -> uint16_t ---
/**
 * Reads the start of a string, raising an error if its length is not
 * exactly the given number of bytes (not including any null-terminator.)
 *
 * The bytes follow and must be read separately with mpack_read_bytes()
 * or mpack_read_bytes_inplace(). @ref mpack_done_str() must be called
 * once all bytes have been read.
 *
 * mpack_error_type is raised if the value is not a string or if its
 * length does not match.
 */
@(link_name="mpack_expect_str_length") mpack_expect_str_length :: proc "cdecl" (reader: [^]Mpack_Reader_T, count: uint16_t) ---
/**
 * Reads a string, ensuring it exactly matches the given string.
 *
 * Remember that maps are unordered in JSON. Don't use this for map keys
 * unless the map has only a single key!
 */
@(link_name="mpack_expect_str_match") mpack_expect_str_match :: proc "cdecl" (reader: [^]Mpack_Reader_T, str: cstring, length: Size_T) ---
/**
 * Reads a string into the given buffer, ensures it has no null bytes,
 * and adds a null-terminator at the end.
 *
 * Raises mpack_error_too_big if there is not enough room for the string and null-terminator.
 * Raises mpack_error_type if the value is not a string or contains a null byte.
 */
@(link_name="mpack_expect_cstr") mpack_expect_cstr :: proc "cdecl" (reader: [^]Mpack_Reader_T, buf: cstring, size: Size_T) ---
/**
 * Reads a string into the given buffer, ensures it is a valid UTF-8 string
 * without NUL characters, and adds a null-terminator at the end.
 *
 * This does not accept any UTF-8 variant such as Modified UTF-8, CESU-8 or
 * WTF-8. Only pure UTF-8 is allowed, but without the NUL character, since
 * it cannot be represented in a null-terminated string.
 *
 * Raises mpack_error_too_big if there is not enough room for the string and null-terminator.
 * Raises mpack_error_type if the value is not a string or is not a valid UTF-8 string.
 */
@(link_name="mpack_expect_utf8_cstr") mpack_expect_utf8_cstr :: proc "cdecl" (reader: [^]Mpack_Reader_T, buf: cstring, size: Size_T) ---
/**
 * Reads a string with the given total maximum size (including space for a
 * null-terminator), allocates storage for it, ensures it has no null-bytes,
 * and adds a null-terminator at the end. You assume ownership of the
 * returned pointer if reading succeeds.
 *
 * The allocated string must be freed with MPACK_FREE() (or simply free()
 * if MPack's allocator hasn't been customized.)
 *
 * @throws mpack_error_too_big If the string plus null-terminator is larger than the given maxsize.
 * @throws mpack_error_type If the value is not a string or contains a null byte.
 */
@(link_name="mpack_expect_cstr_alloc") mpack_expect_cstr_alloc :: proc "cdecl" (reader: [^]Mpack_Reader_T, maxsize: Size_T) -> cstring ---
/**
 * Reads a string with the given total maximum size (including space for a
 * null-terminator), allocates storage for it, ensures it is valid UTF-8
 * with no null-bytes, and adds a null-terminator at the end. You assume
 * ownership of the returned pointer if reading succeeds.
 *
 * The length in bytes of the string, not including the null-terminator,
 * will be written to size.
 *
 * This does not accept any UTF-8 variant such as Modified UTF-8, CESU-8 or
 * WTF-8. Only pure UTF-8 is allowed, but without the NUL character, since
 * it cannot be represented in a null-terminated string.
 *
 * The allocated string must be freed with MPACK_FREE() (or simply free()
 * if MPack's allocator hasn't been customized.)
 * if you want a null-terminator.
 *
 * @throws mpack_error_too_big If the string plus null-terminator is larger
 *     than the given maxsize.
 * @throws mpack_error_type If the value is not a string or contains
 *     invalid UTF-8 or a null byte.
 */
@(link_name="mpack_expect_utf8_cstr_alloc") mpack_expect_utf8_cstr_alloc :: proc "cdecl" (reader: [^]Mpack_Reader_T, maxsize: Size_T) -> cstring ---
/**
 * Reads a string, ensuring it exactly matches the given null-terminated
 * string.
 *
 * Remember that maps are unordered in JSON. Don't use this for map keys
 * unless the map has only a single key!
 */
@(link_name="mpack_expect_cstr_match") mpack_expect_cstr_match :: proc "cdecl" (reader: [^]Mpack_Reader_T, cstr: cstring) ---
/**
 * Reads the start of a binary blob, returning its size in bytes.
 *
 * The bytes follow and must be read separately with mpack_read_bytes()
 * or mpack_read_bytes_inplace(). @ref mpack_done_bin() must be called
 * once all bytes have been read.
 *
 * mpack_error_type is raised if the value is not a binary blob.
 */
@(link_name="mpack_expect_bin") mpack_expect_bin :: proc "cdecl" (reader: [^]Mpack_Reader_T) -> uint16_t ---
/**
 * Reads the start of a binary blob, raising an error if its length is not
 * at most the given number of bytes.
 *
 * The bytes follow and must be read separately with mpack_read_bytes()
 * or mpack_read_bytes_inplace(). @ref mpack_done_bin() must be called
 * once all bytes have been read.
 *
 * mpack_error_type is raised if the value is not a binary blob or if its
 * length does not match.
 */
@(link_name="mpack_expect_bin_max") mpack_expect_bin_max :: proc "cdecl" (reader: [^]Mpack_Reader_T, maxsize: uint16_t) -> uint16_t ---
/**
 * Reads the start of a binary blob, raising an error if its length is not
 * exactly the given number of bytes.
 *
 * The bytes follow and must be read separately with mpack_read_bytes()
 * or mpack_read_bytes_inplace(). @ref mpack_done_bin() must be called
 * once all bytes have been read.
 *
 * @throws mpack_error_type if the value is not a binary blob or if its size
 * does not match.
 */
@(link_name="mpack_expect_bin_size") mpack_expect_bin_size :: proc "cdecl" (reader: [^]Mpack_Reader_T, count: uint16_t) ---
/**
 * Reads a binary blob into the given buffer, returning its size in bytes.
 *
 * For compatibility, this will accept if the underlying type is string or
 * binary (since in MessagePack 1.0, strings and binary data were combined
 * under the "raw" type which became string in 1.1.)
 */
@(link_name="mpack_expect_bin_buf") mpack_expect_bin_buf :: proc "cdecl" (reader: [^]Mpack_Reader_T, buf: cstring, size: Size_T) -> Size_T ---
/**
 * Reads a binary blob with the exact given size into the given buffer.
 *
 * For compatibility, this will accept if the underlying type is string or
 * binary (since in MessagePack 1.0, strings and binary data were combined
 * under the "raw" type which became string in 1.1.)
 *
 * @throws mpack_error_type if the value is not a binary blob or if its size
 * does not match.
 */
@(link_name="mpack_expect_bin_size_buf") mpack_expect_bin_size_buf :: proc "cdecl" (reader: [^]Mpack_Reader_T, buf: cstring, size: uint16_t) ---
/**
 * Reads a binary blob with the given total maximum size, allocating storage for it.
 */
@(link_name="mpack_expect_bin_alloc") mpack_expect_bin_alloc :: proc "cdecl" (reader: [^]Mpack_Reader_T, maxsize: Size_T, size: [^]Size_T) -> cstring ---
/**
 * Reads a MessagePack object header (an MPack tag), expecting it to exactly
 * match the given tag.
 *
 * If the type is compound (i.e. is a map, array, string, binary or
 * extension type), additional reads are required to get the contained
 * data, and the corresponding done function must be called when done.
 *
 * @throws mpack_error_type if the tag does not match
 *
 * @see mpack_read_bytes()
 * @see mpack_done_array()
 * @see mpack_done_map()
 * @see mpack_done_str()
 * @see mpack_done_bin()
 * @see mpack_done_ext()
 */
@(link_name="mpack_expect_tag") mpack_expect_tag :: proc "cdecl" (reader: [^]Mpack_Reader_T, tag: Mpack_Tag_T) ---
/**
 * Expects a string matching one of the strings in the given array,
 * returning its array index.
 *
 * If the value does not match any of the given strings,
 * @ref mpack_error_type is flagged. Use mpack_expect_enum_optional()
 * if you want to allow other values than the given strings.
 *
 * If any error occurs or the reader is in an error state, @a count
 * is returned.
 *
 * This can be used to quickly parse a string into an enum when the
 * enum values range from 0 to @a count-1. If the last value in the
 * enum is a special "count" value, it can be passed as the count,
 * and the return value can be cast directly to the enum type.
 *
 * @code{.c}
 * typedef enum           { APPLE ,  BANANA ,  ORANGE , COUNT} fruit_t;
 * const char* fruits[] = {"apple", "banana", "orange"};
 *
 * fruit_t fruit = (fruit_t)mpack_expect_enum(reader, fruits, COUNT);
 * @endcode
 *
 * See @ref docs/expect.md for more examples.
 *
 * The maximum string length is the size of the buffer (strings are read in-place.)
 *
 * @param reader The reader
 * @param strings An array of expected strings of length count
 * @param count The number of strings
 * @return The index of the matched string, or @a count in case of error
 */
@(link_name="mpack_expect_enum") mpack_expect_enum :: proc "cdecl" (reader: [^]Mpack_Reader_T, strings: <nil>, count: Size_T) -> Size_T ---
/**
 * Expects a string matching one of the strings in the given array
 * returning its array index, or @a count if no strings match.
 *
 * If the value is not a string, or it does not match any of the
 * given strings, @a count is returned and no error is flagged.
 *
 * If any error occurs or the reader is in an error state, @a count
 * is returned.
 *
 * This can be used to quickly parse a string into an enum when the
 * enum values range from 0 to @a count-1. If the last value in the
 * enum is a special "count" value, it can be passed as the count,
 * and the return value can be cast directly to the enum type.
 *
 * @code{.c}
 * typedef enum           { APPLE ,  BANANA ,  ORANGE , COUNT} fruit_t;
 * const char* fruits[] = {"apple", "banana", "orange"};
 *
 * fruit_t fruit = (fruit_t)mpack_expect_enum_optional(reader, fruits, COUNT);
 * @endcode
 *
 * See @ref docs/expect.md for more examples.
 *
 * The maximum string length is the size of the buffer (strings are read in-place.)
 *
 * @param reader The reader
 * @param strings An array of expected strings of length count
 * @param count The number of strings
 *
 * @return The index of the matched string, or @a count if it does not
 * match or an error occurs
 */
@(link_name="mpack_expect_enum_optional") mpack_expect_enum_optional :: proc "cdecl" (reader: [^]Mpack_Reader_T, strings: <nil>, count: Size_T) -> Size_T ---
/**
 * Expects an unsigned integer map key between 0 and count-1, marking it
 * as found in the given bool array and returning it.
 *
 * This is a helper for switching among int keys in a map. It is
 * typically used with an enum to define the key values. It should
 * be called in the expression of a switch() statement. See @ref
 * docs/expect.md for an example.
 *
 * The found array must be cleared before expecting the first key. If the
 * flag for a given key is already set when found (i.e. the map contains a
 * duplicate key), mpack_error_invalid is flagged.
 *
 * If the key is not a non-negative integer, or if the key is @a count or
 * larger, @a count is returned and no error is flagged. If you want an error
 * on unrecognized keys, flag an error in the default case in your switch;
 * otherwise you must call mpack_discard() to discard its content.
 *
 * @param reader The reader
 * @param found An array of bool flags of length count
 * @param count The number of values in the found array, and one more than the
 *              maximum allowed key
 *
 * @see @ref docs/expect.md
 */
@(link_name="mpack_expect_key_uint") mpack_expect_key_uint :: proc "cdecl" (reader: [^]Mpack_Reader_T, found: <nil>, count: Size_T) -> Size_T ---
/**
 * Expects a string map key matching one of the strings in the given key list,
 * marking it as found in the given bool array and returning its index.
 *
 * This is a helper for switching among string keys in a map. It is
 * typically used with an enum with names matching the strings in the
 * array to define the key indices. It should be called in the expression
 * of a switch() statement. See @ref docs/expect.md for an example.
 *
 * The found array must be cleared before expecting the first key. If the
 * flag for a given key is already set when found (i.e. the map contains a
 * duplicate key), mpack_error_invalid is flagged.
 *
 * If the key is unrecognized, count is returned and no error is flagged. If
 * you want an error on unrecognized keys, flag an error in the default case
 * in your switch; otherwise you must call mpack_discard() to discard its content.
 *
 * The maximum key length is the size of the buffer (keys are read in-place.)
 *
 * @param reader The reader
 * @param keys An array of expected string keys of length count
 * @param found An array of bool flags of length count
 * @param count The number of values in the keys and found arrays
 *
 * @see @ref docs/expect.md
 */
@(link_name="mpack_expect_key_cstr") mpack_expect_key_cstr :: proc "cdecl" (reader: [^]Mpack_Reader_T, keys: <nil>, found: <nil>, count: Size_T) -> Size_T ---
// internal functions
@(link_name="mpack_node") mpack_node :: proc "cdecl" (tree: [^]Mpack_Tree_T, data: [^]Mpack_Node_Data_T) -> Mpack_Node_T ---
@(link_name="mpack_node_child") mpack_node_child :: proc "cdecl" (node: Mpack_Node_T, child: Size_T) -> [^]Mpack_Node_Data_T ---
@(link_name="mpack_tree_nil_node") mpack_tree_nil_node :: proc "cdecl" (tree: [^]Mpack_Tree_T) -> Mpack_Node_T ---
@(link_name="mpack_tree_missing_node") mpack_tree_missing_node :: proc "cdecl" (tree: [^]Mpack_Tree_T) -> Mpack_Node_T ---
/**
 * Initializes a tree parser with the given data.
 *
 * Configure the tree if desired, then call mpack_tree_parse() to parse it. The
 * tree will allocate pages of nodes as needed and will free them when
 * destroyed.
 *
 * The tree must be destroyed with mpack_tree_destroy().
 *
 * Any string or blob data types reference the original data, so the given data
 * pointer must remain valid until after the tree is destroyed.
 */
@(link_name="mpack_tree_init_data") mpack_tree_init_data :: proc "cdecl" (tree: [^]Mpack_Tree_T, data: cstring, length: Size_T) ---
/**
 * Deprecated.
 *
 * \deprecated Renamed to mpack_tree_init_data().
 */
@(link_name="mpack_tree_init") mpack_tree_init :: proc "cdecl" (tree: [^]Mpack_Tree_T, data: cstring, length: Size_T) ---
/**
 * Initializes a tree parser from an unbounded stream, or a stream of
 * unknown length.
 *
 * The parser can be used to read a single message from a stream of unknown
 * length, or multiple messages from an unbounded stream, allowing it to
 * be used for RPC communication. Call @ref mpack_tree_parse() to parse
 * a message from a blocking stream, or @ref mpack_tree_try_parse() for a
 * non-blocking stream.
 *
 * The stream will use a growable internal buffer to store the most recent
 * message, as well as allocated pages of nodes for the parse tree.
 *
 * Maximum allowances for message size and node count must be specified in this
 * function (since the stream is unbounded.) They can be changed later with
 * @ref mpack_tree_set_limits().
 *
 * @param tree The tree parser
 * @param read_fn The read function
 * @param context The context for the read function
 * @param max_message_size The maximum size of a message in bytes
 * @param max_message_nodes The maximum number of nodes per message. See
 *        @ref mpack_node_data_t for the size of nodes.
 *
 * @see mpack_tree_read_t
 * @see mpack_reader_context()
 */
@(link_name="mpack_tree_init_stream") mpack_tree_init_stream :: proc "cdecl" (tree: [^]Mpack_Tree_T, read_fn: <nil>, context: rawptr, max_message_size: Size_T, max_message_nodes: Size_T) ---
/**
 * Initializes a tree parser with the given data, using the given node data
 * pool to store the results.
 *
 * Configure the tree if desired, then call mpack_tree_parse() to parse it.
 *
 * If the data does not fit in the pool, @ref mpack_error_too_big will be flagged
 * on the tree.
 *
 * The tree must be destroyed with mpack_tree_destroy(), even if parsing fails.
 */
@(link_name="mpack_tree_init_pool") mpack_tree_init_pool :: proc "cdecl" (tree: [^]Mpack_Tree_T, data: cstring, length: Size_T, node_pool: [^]Mpack_Node_Data_T, node_pool_count: Size_T) ---
/**
 * Initializes an MPack tree directly into an error state. Use this if you
 * are writing a wrapper to another <tt>mpack_tree_init*()</tt> function which
 * can fail its setup.
 */
@(link_name="mpack_tree_init_error") mpack_tree_init_error :: proc "cdecl" (tree: [^]Mpack_Tree_T, error: Mpack_Error_T) ---
/**
 * Initializes a tree to parse the given file. The tree must be destroyed with
 * mpack_tree_destroy(), even if parsing fails.
 *
 * The file is opened, loaded fully into memory, and closed before this call
 * returns.
 *
 * @param tree The tree to initialize
 * @param filename The filename passed to fopen() to read the file
 * @param max_bytes The maximum size of file to load, or 0 for unlimited size.
 */
@(link_name="mpack_tree_init_filename") mpack_tree_init_filename :: proc "cdecl" (tree: [^]Mpack_Tree_T, filename: cstring, max_bytes: Size_T) ---
/**
 * Deprecated.
 *
 * \deprecated Renamed to mpack_tree_init_filename().
 */
@(link_name="mpack_tree_init_file") mpack_tree_init_file :: proc "cdecl" (tree: [^]Mpack_Tree_T, filename: cstring, max_bytes: Size_T) ---
/**
 * Initializes a tree to parse the given libc FILE. This can be used to
 * read from stdin, or from a file opened separately.
 *
 * The tree must be destroyed with mpack_tree_destroy(), even if parsing fails.
 *
 * The FILE is fully loaded fully into memory (and closed if requested) before
 * this call returns.
 *
 * @param tree The tree to initialize.
 * @param stdfile The FILE.
 * @param max_bytes The maximum size of file to load, or 0 for unlimited size.
 * @param close_when_done If true, fclose() will be called on the FILE when it
 *         is no longer needed. If false, the file will not be closed when
 *         reading is done.
 *
 * @warning The tree will read all data in the FILE before parsing it. If this
 *          is used on stdin, the parser will block until it is closed, even if
 *          a complete message has been written to it!
 */
@(link_name="mpack_tree_init_stdfile") mpack_tree_init_stdfile :: proc "cdecl" (tree: [^]Mpack_Tree_T, stdfile: [^]FILE, max_bytes: Size_T, close_when_done: c.bool) ---
/**
 * Sets the maximum byte size and maximum number of nodes allowed per message.
 *
 * The default is SIZE_MAX (no limit) unless @ref mpack_tree_init_stream() is
 * called (where maximums are required.)
 *
 * If a pool of nodes is used, the node limit is the lesser of this limit and
 * the pool size.
 *
 * @param tree The tree parser
 * @param max_message_size The maximum size of a message in bytes
 * @param max_message_nodes The maximum number of nodes per message. See
 *        @ref mpack_node_data_t for the size of nodes.
 */
@(link_name="mpack_tree_set_limits") mpack_tree_set_limits :: proc "cdecl" (tree: [^]Mpack_Tree_T, max_message_size: Size_T, max_message_nodes: Size_T) ---
/**
 * Parses a MessagePack message into a tree of immutable nodes.
 *
 * If successful, the root node will be available under @ref mpack_tree_root().
 * If not, an appropriate error will be flagged.
 *
 * This can be called repeatedly to parse a series of messages from a data
 * source. When this is called, all previous nodes from this tree and their
 * contents (including the root node) are invalidated.
 *
 * If this is called with a stream (see @ref mpack_tree_init_stream()), the
 * stream must block until data is available. (Otherwise, if this is called on
 * a non-blocking stream, parsing will fail with @ref mpack_error_io when the
 * fill function returns 0.)
 *
 * There is no way to recover a tree in an error state. It must be destroyed.
 */
@(link_name="mpack_tree_parse") mpack_tree_parse :: proc "cdecl" (tree: [^]Mpack_Tree_T) ---
/**
 * Attempts to parse a MessagePack message from a non-blocking stream into a
 * tree of immutable nodes.
 *
 * A non-blocking read function must have been passed to the tree in
 * mpack_tree_init_stream().
 *
 * If this returns true, a message is available under
 * @ref mpack_tree_root(). The tree nodes and data will be valid until
 * the next time a parse is started.
 *
 * If this returns false, no message is available, because either not enough
 * data is available yet or an error has occurred. You must check the tree for
 * errors whenever this returns false. If there is no error, you should try
 * again later when more data is available. (You will want to select()/poll()
 * on the underlying socket or use some other asynchronous mechanism to
 * determine when it has data.)
 *
 * There is no way to recover a tree in an error state. It must be destroyed.
 *
 * @see mpack_tree_init_stream()
 */
@(link_name="mpack_tree_try_parse") mpack_tree_try_parse :: proc "cdecl" (tree: [^]Mpack_Tree_T) -> c.bool ---
/**
 * Returns the root node of the tree, if the tree is not in an error state.
 * Returns a nil node otherwise.
 *
 * @warning You must call mpack_tree_parse() before calling this. If
 * @ref mpack_tree_parse() was never called, the tree will assert.
 */
@(link_name="mpack_tree_root") mpack_tree_root :: proc "cdecl" (tree: [^]Mpack_Tree_T) -> Mpack_Node_T ---
/**
 * Returns the error state of the tree.
 */
@(link_name="mpack_tree_error") mpack_tree_error :: proc "cdecl" (tree: [^]Mpack_Tree_T) -> Mpack_Error_T ---
/**
 * Returns the size in bytes of the current parsed message.
 *
 * If there is something in the buffer after the MessagePack object, this can
 * be used to find it.
 *
 * This is zero if an error occurred during tree parsing (since the
 * portion of the data that the first complete object occupies cannot
 * be determined if the data is invalid or corrupted.)
 */
@(link_name="mpack_tree_size") mpack_tree_size :: proc "cdecl" (tree: [^]Mpack_Tree_T) -> Size_T ---
/**
 * Destroys the tree.
 */
@(link_name="mpack_tree_destroy") mpack_tree_destroy :: proc "cdecl" (tree: [^]Mpack_Tree_T) -> Mpack_Error_T ---
/**
 * Sets the custom pointer to pass to the tree callbacks, such as teardown.
 *
 * @param tree The MPack tree.
 * @param context User data to pass to the tree callbacks.
 *
 * @see mpack_reader_context()
 */
@(link_name="mpack_tree_set_context") mpack_tree_set_context :: proc "cdecl" (tree: [^]Mpack_Tree_T, context: rawptr) ---
/**
 * Returns the custom context for tree callbacks.
 *
 * @see mpack_tree_set_context
 * @see mpack_tree_init_stream
 */
@(link_name="mpack_tree_context") mpack_tree_context :: proc "cdecl" (tree: [^]Mpack_Tree_T) -> rawptr ---
/**
 * Sets the error function to call when an error is flagged on the tree.
 *
 * This should normally be used with mpack_tree_set_context() to register
 * a custom pointer to pass to the error function.
 *
 * See the definition of mpack_tree_error_t for more information about
 * what you can do from an error callback.
 *
 * @see mpack_tree_error_t
 * @param tree The MPack tree.
 * @param error_fn The function to call when an error is flagged on the tree.
 */
@(link_name="mpack_tree_set_error_handler") mpack_tree_set_error_handler :: proc "cdecl" (tree: [^]Mpack_Tree_T, error_fn: <nil>) ---
/**
 * Sets the teardown function to call when the tree is destroyed.
 *
 * This should normally be used with mpack_tree_set_context() to register
 * a custom pointer to pass to the teardown function.
 *
 * @param tree The MPack tree.
 * @param teardown The function to call when the tree is destroyed.
 */
@(link_name="mpack_tree_set_teardown") mpack_tree_set_teardown :: proc "cdecl" (tree: [^]Mpack_Tree_T, teardown: <nil>) ---
/**
 * Places the tree in the given error state, calling the error callback if one
 * is set.
 *
 * This allows you to externally flag errors, for example if you are validating
 * data as you read it.
 *
 * If the tree is already in an error state, this call is ignored and no
 * error callback is called.
 */
@(link_name="mpack_tree_flag_error") mpack_tree_flag_error :: proc "cdecl" (tree: [^]Mpack_Tree_T, error: Mpack_Error_T) ---
/**
 * Places the node's tree in the given error state, calling the error callback
 * if one is set.
 *
 * This allows you to externally flag errors, for example if you are validating
 * data as you read it.
 *
 * If the tree is already in an error state, this call is ignored and no
 * error callback is called.
 */
@(link_name="mpack_node_flag_error") mpack_node_flag_error :: proc "cdecl" (node: Mpack_Node_T, error: Mpack_Error_T) ---
/**
 * Returns the error state of the node's tree.
 */
@(link_name="mpack_node_error") mpack_node_error :: proc "cdecl" (node: Mpack_Node_T) -> Mpack_Error_T ---
/**
 * Returns a tag describing the given node, or a nil tag if the
 * tree is in an error state.
 */
@(link_name="mpack_node_tag") mpack_node_tag :: proc "cdecl" (node: Mpack_Node_T) -> Mpack_Tag_T ---
/**
 * Returns the type of the node.
 */
@(link_name="mpack_node_type") mpack_node_type :: proc "cdecl" (node: Mpack_Node_T) -> Mpack_Type_T ---
/**
 * Returns true if the given node is a nil node; false otherwise.
 *
 * To ensure that a node is nil and flag an error otherwise, use
 * mpack_node_nil().
 */
@(link_name="mpack_node_is_nil") mpack_node_is_nil :: proc "cdecl" (node: Mpack_Node_T) -> c.bool ---
/**
 * Returns true if the given node handle indicates a missing node; false otherwise.
 *
 * To ensure that a node is missing and flag an error otherwise, use
 * mpack_node_missing().
 */
@(link_name="mpack_node_is_missing") mpack_node_is_missing :: proc "cdecl" (node: Mpack_Node_T) -> c.bool ---
/**
 * Checks that the given node is of nil type, raising @ref mpack_error_type
 * otherwise.
 *
 * Use mpack_node_is_nil() to return whether the node is nil.
 */
@(link_name="mpack_node_nil") mpack_node_nil :: proc "cdecl" (node: Mpack_Node_T) ---
/**
 * Checks that the given node indicates a missing node, raising @ref
 * mpack_error_type otherwise.
 *
 * Use mpack_node_is_missing() to return whether the node is missing.
 */
@(link_name="mpack_node_missing") mpack_node_missing :: proc "cdecl" (node: Mpack_Node_T) ---
/**
 * Returns the bool value of the node. If this node is not of the correct
 * type, false is returned and mpack_error_type is raised.
 */
@(link_name="mpack_node_bool") mpack_node_bool :: proc "cdecl" (node: Mpack_Node_T) -> c.bool ---
/**
 * Checks if the given node is of bool type with value true, raising
 * mpack_error_type otherwise.
 */
@(link_name="mpack_node_true") mpack_node_true :: proc "cdecl" (node: Mpack_Node_T) ---
/**
 * Checks if the given node is of bool type with value false, raising
 * mpack_error_type otherwise.
 */
@(link_name="mpack_node_false") mpack_node_false :: proc "cdecl" (node: Mpack_Node_T) ---
/**
 * Returns the 8-bit unsigned value of the node. If this node is not
 * of a compatible type, @ref mpack_error_type is raised and zero is returned.
 */
@(link_name="mpack_node_u8") mpack_node_u8 :: proc "cdecl" (node: Mpack_Node_T) -> Uint8_T ---
/**
 * Returns the 8-bit signed value of the node. If this node is not
 * of a compatible type, @ref mpack_error_type is raised and zero is returned.
 */
@(link_name="mpack_node_i8") mpack_node_i8 :: proc "cdecl" (node: Mpack_Node_T) -> Int8_T ---
/**
 * Returns the 16-bit unsigned value of the node. If this node is not
 * of a compatible type, @ref mpack_error_type is raised and zero is returned.
 */
@(link_name="mpack_node_u16") mpack_node_u16 :: proc "cdecl" (node: Mpack_Node_T) -> Uint16_T ---
/**
 * Returns the 16-bit signed value of the node. If this node is not
 * of a compatible type, @ref mpack_error_type is raised and zero is returned.
 */
@(link_name="mpack_node_i16") mpack_node_i16 :: proc "cdecl" (node: Mpack_Node_T) -> Int16_T ---
/**
 * Returns the 32-bit unsigned value of the node. If this node is not
 * of a compatible type, @ref mpack_error_type is raised and zero is returned.
 */
@(link_name="mpack_node_u32") mpack_node_u32 :: proc "cdecl" (node: Mpack_Node_T) -> uint16_t ---
/**
 * Returns the 32-bit signed value of the node. If this node is not
 * of a compatible type, @ref mpack_error_type is raised and zero is returned.
 */
@(link_name="mpack_node_i32") mpack_node_i32 :: proc "cdecl" (node: Mpack_Node_T) -> Int32_T ---
/**
 * Returns the 64-bit unsigned value of the node. If this node is not
 * of a compatible type, @ref mpack_error_type is raised, and zero is returned.
 */
@(link_name="mpack_node_u64") mpack_node_u64 :: proc "cdecl" (node: Mpack_Node_T) -> uint64_t ---
/**
 * Returns the 64-bit signed value of the node. If this node is not
 * of a compatible type, @ref mpack_error_type is raised and zero is returned.
 */
@(link_name="mpack_node_i64") mpack_node_i64 :: proc "cdecl" (node: Mpack_Node_T) -> uint8_t ---
/**
 * Returns the unsigned int value of the node.
 *
 * Returns zero if an error occurs.
 *
 * @throws mpack_error_type If the node is not an integer type or does not fit in the range of an unsigned int
 */
@(link_name="mpack_node_uint") mpack_node_uint :: proc "cdecl" (node: Mpack_Node_T) -> c.uint ---
/**
 * Returns the int value of the node.
 *
 * Returns zero if an error occurs.
 *
 * @throws mpack_error_type If the node is not an integer type or does not fit in the range of an int
 */
@(link_name="mpack_node_int") mpack_node_int :: proc "cdecl" (node: Mpack_Node_T) -> int32_t ---
/**
 * Returns the float value of the node. The underlying value can be an
 * integer, float or double; the value is converted to a float.
 *
 * @note Reading a double or a large integer with this function can incur a
 * loss of precision.
 *
 * @throws mpack_error_type if the underlying value is not a float, double or integer.
 */
@(link_name="mpack_node_float") mpack_node_float :: proc "cdecl" (node: Mpack_Node_T) -> c.float ---
/**
 * Returns the double value of the node. The underlying value can be an
 * integer, float or double; the value is converted to a double.
 *
 * @note Reading a very large integer with this function can incur a
 * loss of precision.
 *
 * @throws mpack_error_type if the underlying value is not a float, double or integer.
 */
@(link_name="mpack_node_double") mpack_node_double :: proc "cdecl" (node: Mpack_Node_T) -> c.double ---
/**
 * Returns the float value of the node. The underlying value must be a float,
 * not a double or an integer. This ensures no loss of precision can occur.
 *
 * @throws mpack_error_type if the underlying value is not a float.
 */
@(link_name="mpack_node_float_strict") mpack_node_float_strict :: proc "cdecl" (node: Mpack_Node_T) -> c.float ---
/**
 * Returns the double value of the node. The underlying value must be a float
 * or double, not an integer. This ensures no loss of precision can occur.
 *
 * @throws mpack_error_type if the underlying value is not a float or double.
 */
@(link_name="mpack_node_double_strict") mpack_node_double_strict :: proc "cdecl" (node: Mpack_Node_T) -> c.double ---
/**
 * Checks that the given node contains a valid UTF-8 string.
 *
 * If the string is invalid, this flags an error, which would cause subsequent calls
 * to mpack_node_str() to return NULL and mpack_node_strlen() to return zero. So you
 * can check the node for error immediately after calling this, or you can call those
 * functions to use the data anyway and check for errors later.
 *
 * @throws mpack_error_type If this node is not a string or does not contain valid UTF-8.
 *
 * @param node The string node to test
 *
 * @see mpack_node_str()
 * @see mpack_node_strlen()
 */
@(link_name="mpack_node_check_utf8") mpack_node_check_utf8 :: proc "cdecl" (node: Mpack_Node_T) ---
/**
 * Checks that the given node contains a valid UTF-8 string with no NUL bytes.
 *
 * This does not check that the string has a null-terminator! It only checks whether
 * the string could safely be represented as a C-string by appending a null-terminator.
 * (If the string does already contain a null-terminator, this will flag an error.)
 *
 * This is performed automatically by other UTF-8 cstr helper functions. Only
 * call this if you will do something else with the data directly, but you still
 * want to ensure it will be valid as a UTF-8 C-string.
 *
 * @throws mpack_error_type If this node is not a string, does not contain valid UTF-8,
 *     or contains a NUL byte.
 *
 * @param node The string node to test
 *
 * @see mpack_node_str()
 * @see mpack_node_strlen()
 * @see mpack_node_copy_utf8_cstr()
 * @see mpack_node_utf8_cstr_alloc()
 */
@(link_name="mpack_node_check_utf8_cstr") mpack_node_check_utf8_cstr :: proc "cdecl" (node: Mpack_Node_T) ---
/**
 * Returns the number of bytes in the given bin node.
 *
 * This returns zero if the tree is in an error state.
 *
 * If this node is not a bin, @ref mpack_error_type is raised and zero is returned.
 */
@(link_name="mpack_node_bin_size") mpack_node_bin_size :: proc "cdecl" (node: Mpack_Node_T) -> Size_T ---
/**
 * Returns the length of the given str, bin or ext node.
 *
 * This returns zero if the tree is in an error state.
 *
 * If this node is not a str, bin or ext, @ref mpack_error_type is raised and zero
 * is returned.
 */
@(link_name="mpack_node_data_len") mpack_node_data_len :: proc "cdecl" (node: Mpack_Node_T) -> uint16_t ---
/**
 * Returns the length in bytes of the given string node. This does not
 * include any null-terminator.
 *
 * This returns zero if the tree is in an error state.
 *
 * If this node is not a str, @ref mpack_error_type is raised and zero is returned.
 */
@(link_name="mpack_node_strlen") mpack_node_strlen :: proc "cdecl" (node: Mpack_Node_T) -> Size_T ---
/**
 * Returns a pointer to the data contained by this node, ensuring the node is a
 * string.
 *
 * @warning Strings are not null-terminated! Use one of the cstr functions
 * to get a null-terminated string.
 *
 * The pointer is valid as long as the data backing the tree is valid.
 *
 * If this node is not a string, @ref mpack_error_type is raised and @c NULL is returned.
 *
 * @see mpack_node_copy_cstr()
 * @see mpack_node_cstr_alloc()
 * @see mpack_node_utf8_cstr_alloc()
 */
@(link_name="mpack_node_str") mpack_node_str :: proc "cdecl" (node: Mpack_Node_T) -> cstring ---
/**
 * Returns a pointer to the data contained by this node.
 *
 * @note Strings are not null-terminated! Use one of the cstr functions
 * to get a null-terminated string.
 *
 * The pointer is valid as long as the data backing the tree is valid.
 *
 * If this node is not of a str, bin or ext, @ref mpack_error_type is raised, and
 * @c NULL is returned.
 *
 * @see mpack_node_copy_cstr()
 * @see mpack_node_cstr_alloc()
 * @see mpack_node_utf8_cstr_alloc()
 */
@(link_name="mpack_node_data") mpack_node_data :: proc "cdecl" (node: Mpack_Node_T) -> cstring ---
/**
 * Returns a pointer to the data contained by this bin node.
 *
 * The pointer is valid as long as the data backing the tree is valid.
 *
 * If this node is not a bin, @ref mpack_error_type is raised and @c NULL is
 * returned.
 */
@(link_name="mpack_node_bin_data") mpack_node_bin_data :: proc "cdecl" (node: Mpack_Node_T) -> cstring ---
/**
 * Copies the bytes contained by this node into the given buffer, returning the
 * number of bytes in the node.
 *
 * @throws mpack_error_type If this node is not a str, bin or ext type
 * @throws mpack_error_too_big If the string does not fit in the given buffer
 *
 * @param node The string node from which to copy data
 * @param buffer A buffer in which to copy the node's bytes
 * @param bufsize The size of the given buffer
 *
 * @return The number of bytes in the node, or zero if an error occurs.
 */
@(link_name="mpack_node_copy_data") mpack_node_copy_data :: proc "cdecl" (node: Mpack_Node_T, buffer: cstring, bufsize: Size_T) -> Size_T ---
/**
 * Checks that the given node contains a valid UTF-8 string and copies the
 * string into the given buffer, returning the number of bytes in the string.
 *
 * @throws mpack_error_type If this node is not a string
 * @throws mpack_error_too_big If the string does not fit in the given buffer
 *
 * @param node The string node from which to copy data
 * @param buffer A buffer in which to copy the node's bytes
 * @param bufsize The size of the given buffer
 *
 * @return The number of bytes in the node, or zero if an error occurs.
 */
@(link_name="mpack_node_copy_utf8") mpack_node_copy_utf8 :: proc "cdecl" (node: Mpack_Node_T, buffer: cstring, bufsize: Size_T) -> Size_T ---
/**
 * Checks that the given node contains a string with no NUL bytes, copies the string
 * into the given buffer, and adds a null terminator.
 *
 * If this node is not of a string type, @ref mpack_error_type is raised. If the string
 * does not fit, @ref mpack_error_data is raised.
 *
 * If any error occurs, the buffer will contain an empty null-terminated string.
 *
 * @param node The string node from which to copy data
 * @param buffer A buffer in which to copy the node's string
 * @param size The size of the given buffer
 */
@(link_name="mpack_node_copy_cstr") mpack_node_copy_cstr :: proc "cdecl" (node: Mpack_Node_T, buffer: cstring, size: Size_T) ---
/**
 * Checks that the given node contains a valid UTF-8 string with no NUL bytes,
 * copies the string into the given buffer, and adds a null terminator.
 *
 * If this node is not of a string type, @ref mpack_error_type is raised. If the string
 * does not fit, @ref mpack_error_data is raised.
 *
 * If any error occurs, the buffer will contain an empty null-terminated string.
 *
 * @param node The string node from which to copy data
 * @param buffer A buffer in which to copy the node's string
 * @param size The size of the given buffer
 */
@(link_name="mpack_node_copy_utf8_cstr") mpack_node_copy_utf8_cstr :: proc "cdecl" (node: Mpack_Node_T, buffer: cstring, size: Size_T) ---
/**
 * Allocates a new chunk of data using MPACK_MALLOC() with the bytes
 * contained by this node.
 *
 * The allocated data must be freed with MPACK_FREE() (or simply free()
 * if MPack's allocator hasn't been customized.)
 *
 * @throws mpack_error_type If this node is not a str, bin or ext type
 * @throws mpack_error_too_big If the size of the data is larger than the
 *     given maximum size
 * @throws mpack_error_memory If an allocation failure occurs
 *
 * @param node The node from which to allocate and copy data
 * @param maxsize The maximum size to allocate
 *
 * @return The allocated data, or NULL if any error occurs.
 */
@(link_name="mpack_node_data_alloc") mpack_node_data_alloc :: proc "cdecl" (node: Mpack_Node_T, maxsize: Size_T) -> cstring ---
/**
 * Allocates a new null-terminated string using MPACK_MALLOC() with the string
 * contained by this node.
 *
 * The allocated string must be freed with MPACK_FREE() (or simply free()
 * if MPack's allocator hasn't been customized.)
 *
 * @throws mpack_error_type If this node is not a string or contains NUL bytes
 * @throws mpack_error_too_big If the size of the string plus null-terminator
 *     is larger than the given maximum size
 * @throws mpack_error_memory If an allocation failure occurs
 *
 * @param node The node from which to allocate and copy string data
 * @param maxsize The maximum size to allocate, including the null-terminator
 *
 * @return The allocated string, or NULL if any error occurs.
 */
@(link_name="mpack_node_cstr_alloc") mpack_node_cstr_alloc :: proc "cdecl" (node: Mpack_Node_T, maxsize: Size_T) -> cstring ---
/**
 * Allocates a new null-terminated string using MPACK_MALLOC() with the UTF-8
 * string contained by this node.
 *
 * The allocated string must be freed with MPACK_FREE() (or simply free()
 * if MPack's allocator hasn't been customized.)
 *
 * @throws mpack_error_type If this node is not a string, is not valid UTF-8,
 *     or contains NUL bytes
 * @throws mpack_error_too_big If the size of the string plus null-terminator
 *     is larger than the given maximum size
 * @throws mpack_error_memory If an allocation failure occurs
 *
 * @param node The node from which to allocate and copy string data
 * @param maxsize The maximum size to allocate, including the null-terminator
 *
 * @return The allocated string, or NULL if any error occurs.
 */
@(link_name="mpack_node_utf8_cstr_alloc") mpack_node_utf8_cstr_alloc :: proc "cdecl" (node: Mpack_Node_T, maxsize: Size_T) -> cstring ---
/**
 * Searches the given string array for a string matching the given
 * node and returns its index.
 *
 * If the node does not match any of the given strings,
 * @ref mpack_error_type is flagged. Use mpack_node_enum_optional()
 * if you want to allow values other than the given strings.
 *
 * If any error occurs or if the tree is in an error state, @a count
 * is returned.
 *
 * This can be used to quickly parse a string into an enum when the
 * enum values range from 0 to @a count-1. If the last value in the
 * enum is a special "count" value, it can be passed as the count,
 * and the return value can be cast directly to the enum type.
 *
 * @code{.c}
 * typedef enum           { APPLE ,  BANANA ,  ORANGE , COUNT} fruit_t;
 * const char* fruits[] = {"apple", "banana", "orange"};
 *
 * fruit_t fruit = (fruit_t)mpack_node_enum(node, fruits, COUNT);
 * @endcode
 *
 * @param node The node
 * @param strings An array of expected strings of length count
 * @param count The number of strings
 * @return The index of the matched string, or @a count in case of error
 */
@(link_name="mpack_node_enum") mpack_node_enum :: proc "cdecl" (node: Mpack_Node_T, strings: <nil>, count: Size_T) -> Size_T ---
/**
 * Searches the given string array for a string matching the given node,
 * returning its index or @a count if no strings match.
 *
 * If the value is not a string, or it does not match any of the
 * given strings, @a count is returned and no error is flagged.
 *
 * If any error occurs or if the tree is in an error state, @a count
 * is returned.
 *
 * This can be used to quickly parse a string into an enum when the
 * enum values range from 0 to @a count-1. If the last value in the
 * enum is a special "count" value, it can be passed as the count,
 * and the return value can be cast directly to the enum type.
 *
 * @code{.c}
 * typedef enum           { APPLE ,  BANANA ,  ORANGE , COUNT} fruit_t;
 * const char* fruits[] = {"apple", "banana", "orange"};
 *
 * fruit_t fruit = (fruit_t)mpack_node_enum_optional(node, fruits, COUNT);
 * @endcode
 *
 * @param node The node
 * @param strings An array of expected strings of length count
 * @param count The number of strings
 * @return The index of the matched string, or @a count in case of error
 */
@(link_name="mpack_node_enum_optional") mpack_node_enum_optional :: proc "cdecl" (node: Mpack_Node_T, strings: <nil>, count: Size_T) -> Size_T ---
/**
 * Returns the length of the given array node. Raises mpack_error_type
 * and returns 0 if the given node is not an array.
 */
@(link_name="mpack_node_array_length") mpack_node_array_length :: proc "cdecl" (node: Mpack_Node_T) -> Size_T ---
/**
 * Returns the node in the given array at the given index. If the node
 * is not an array, @ref mpack_error_type is raised and a nil node is returned.
 * If the given index is out of bounds, @ref mpack_error_data is raised and
 * a nil node is returned.
 */
@(link_name="mpack_node_array_at") mpack_node_array_at :: proc "cdecl" (node: Mpack_Node_T, index: Size_T) -> Mpack_Node_T ---
/**
 * Returns the number of key/value pairs in the given map node. Raises
 * mpack_error_type and returns 0 if the given node is not a map.
 */
@(link_name="mpack_node_map_count") mpack_node_map_count :: proc "cdecl" (node: Mpack_Node_T) -> Size_T ---
/**
 * Returns the key node in the given map at the given index.
 *
 * A nil node is returned in case of error.
 *
 * @throws mpack_error_type if the node is not a map
 * @throws mpack_error_data if the given index is out of bounds
 */
@(link_name="mpack_node_map_key_at") mpack_node_map_key_at :: proc "cdecl" (node: Mpack_Node_T, index: Size_T) -> Mpack_Node_T ---
/**
 * Returns the value node in the given map at the given index.
 *
 * A nil node is returned in case of error.
 *
 * @throws mpack_error_type if the node is not a map
 * @throws mpack_error_data if the given index is out of bounds
 */
@(link_name="mpack_node_map_value_at") mpack_node_map_value_at :: proc "cdecl" (node: Mpack_Node_T, index: Size_T) -> Mpack_Node_T ---
/**
 * Returns the value node in the given map for the given integer key.
 *
 * The key must exist within the map. Use mpack_node_map_int_optional() to
 * check for optional keys.
 *
 * The key must be unique. An error is flagged if the node has multiple
 * entries with the given key.
 *
 * @throws mpack_error_type If the node is not a map
 * @throws mpack_error_data If the node does not contain exactly one entry with the given key
 *
 * @return The value node for the given key, or a nil node in case of error
 */
@(link_name="mpack_node_map_int") mpack_node_map_int :: proc "cdecl" (node: Mpack_Node_T, num: uint8_t) -> Mpack_Node_T ---
/**
 * Returns the value node in the given map for the given integer key, or a
 * missing node if the map does not contain the given key.
 *
 * The key must be unique. An error is flagged if the node has multiple
 * entries with the given key.
 *
 * @throws mpack_error_type If the node is not a map
 * @throws mpack_error_data If the node contains more than one entry with the given key
 *
 * @return The value node for the given key, or a missing node if the key does
 *         not exist, or a nil node in case of error
 *
 * @see mpack_node_is_missing()
 */
@(link_name="mpack_node_map_int_optional") mpack_node_map_int_optional :: proc "cdecl" (node: Mpack_Node_T, num: uint8_t) -> Mpack_Node_T ---
/**
 * Returns the value node in the given map for the given unsigned integer key.
 *
 * The key must exist within the map. Use mpack_node_map_uint_optional() to
 * check for optional keys.
 *
 * The key must be unique. An error is flagged if the node has multiple
 * entries with the given key.
 *
 * @throws mpack_error_type If the node is not a map
 * @throws mpack_error_data If the node does not contain exactly one entry with the given key
 *
 * @return The value node for the given key, or a nil node in case of error
 */
@(link_name="mpack_node_map_uint") mpack_node_map_uint :: proc "cdecl" (node: Mpack_Node_T, num: uint64_t) -> Mpack_Node_T ---
/**
 * Returns the value node in the given map for the given unsigned integer
 * key, or a missing node if the map does not contain the given key.
 *
 * The key must be unique. An error is flagged if the node has multiple
 * entries with the given key.
 *
 * @throws mpack_error_type If the node is not a map
 * @throws mpack_error_data If the node contains more than one entry with the given key
 *
 * @return The value node for the given key, or a missing node if the key does
 *         not exist, or a nil node in case of error
 *
 * @see mpack_node_is_missing()
 */
@(link_name="mpack_node_map_uint_optional") mpack_node_map_uint_optional :: proc "cdecl" (node: Mpack_Node_T, num: uint64_t) -> Mpack_Node_T ---
/**
 * Returns the value node in the given map for the given string key.
 *
 * The key must exist within the map. Use mpack_node_map_str_optional() to
 * check for optional keys.
 *
 * The key must be unique. An error is flagged if the node has multiple
 * entries with the given key.
 *
 * @throws mpack_error_type If the node is not a map
 * @throws mpack_error_data If the node does not contain exactly one entry with the given key
 *
 * @return The value node for the given key, or a nil node in case of error
 */
@(link_name="mpack_node_map_str") mpack_node_map_str :: proc "cdecl" (node: Mpack_Node_T, str: cstring, length: Size_T) -> Mpack_Node_T ---
/**
 * Returns the value node in the given map for the given string key, or a missing
 * node if the map does not contain the given key.
 *
 * The key must be unique. An error is flagged if the node has multiple
 * entries with the given key.
 *
 * @throws mpack_error_type If the node is not a map
 * @throws mpack_error_data If the node contains more than one entry with the given key
 *
 * @return The value node for the given key, or a missing node if the key does
 *         not exist, or a nil node in case of error
 *
 * @see mpack_node_is_missing()
 */
@(link_name="mpack_node_map_str_optional") mpack_node_map_str_optional :: proc "cdecl" (node: Mpack_Node_T, str: cstring, length: Size_T) -> Mpack_Node_T ---
/**
 * Returns the value node in the given map for the given null-terminated
 * string key.
 *
 * The key must exist within the map. Use mpack_node_map_cstr_optional() to
 * check for optional keys.
 *
 * The key must be unique. An error is flagged if the node has multiple
 * entries with the given key.
 *
 * @throws mpack_error_type If the node is not a map
 * @throws mpack_error_data If the node does not contain exactly one entry with the given key
 *
 * @return The value node for the given key, or a nil node in case of error
 */
@(link_name="mpack_node_map_cstr") mpack_node_map_cstr :: proc "cdecl" (node: Mpack_Node_T, cstr: cstring) -> Mpack_Node_T ---
/**
 * Returns the value node in the given map for the given null-terminated
 * string key, or a missing node if the map does not contain the given key.
 *
 * The key must be unique. An error is flagged if the node has multiple
 * entries with the given key.
 *
 * @throws mpack_error_type If the node is not a map
 * @throws mpack_error_data If the node contains more than one entry with the given key
 *
 * @return The value node for the given key, or a missing node if the key does
 *         not exist, or a nil node in case of error
 *
 * @see mpack_node_is_missing()
 */
@(link_name="mpack_node_map_cstr_optional") mpack_node_map_cstr_optional :: proc "cdecl" (node: Mpack_Node_T, cstr: cstring) -> Mpack_Node_T ---
/**
 * Returns true if the given node map contains exactly one entry with the
 * given integer key.
 *
 * The key must be unique. An error is flagged if the node has multiple
 * entries with the given key.
 *
 * @throws mpack_error_type If the node is not a map
 * @throws mpack_error_data If the node contains more than one entry with the given key
 */
@(link_name="mpack_node_map_contains_int") mpack_node_map_contains_int :: proc "cdecl" (node: Mpack_Node_T, num: uint8_t) -> c.bool ---
/**
 * Returns true if the given node map contains exactly one entry with the
 * given unsigned integer key.
 *
 * The key must be unique. An error is flagged if the node has multiple
 * entries with the given key.
 *
 * @throws mpack_error_type If the node is not a map
 * @throws mpack_error_data If the node contains more than one entry with the given key
 */
@(link_name="mpack_node_map_contains_uint") mpack_node_map_contains_uint :: proc "cdecl" (node: Mpack_Node_T, num: uint64_t) -> c.bool ---
/**
 * Returns true if the given node map contains exactly one entry with the
 * given string key.
 *
 * The key must be unique. An error is flagged if the node has multiple
 * entries with the given key.
 *
 * @throws mpack_error_type If the node is not a map
 * @throws mpack_error_data If the node contains more than one entry with the given key
 */
@(link_name="mpack_node_map_contains_str") mpack_node_map_contains_str :: proc "cdecl" (node: Mpack_Node_T, str: cstring, length: Size_T) -> c.bool ---
/**
 * Returns true if the given node map contains exactly one entry with the
 * given null-terminated string key.
 *
 * The key must be unique. An error is flagged if the node has multiple
 * entries with the given key.
 *
 * @throws mpack_error_type If the node is not a map
 * @throws mpack_error_data If the node contains more than one entry with the given key
 */
@(link_name="mpack_node_map_contains_cstr") mpack_node_map_contains_cstr :: proc "cdecl" (node: Mpack_Node_T, cstr: cstring) -> c.bool ---
}
