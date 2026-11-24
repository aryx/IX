(* Marshal.to_string, but with the same bytes whatever OCaml built the
 * program. The toolchain marshals what it writes into a file (an
 * object's code, a library's members, a unit's summary), and make self
 * compares the files built on the card with those built on the host,
 * byte for byte.
 *
 * A block of 8 fields or more, or of a tag of 16 or more, is written
 * with its header, and the header has the collector's two color bits.
 * OCaml 4.14 writes them as 0, and so does mini-ml's Marshal
 * (lib_core/core/Marshal.ml), but OCaml 5 writes them as 3 (extern.c's
 * NOT_MARKABLE). A reader ignores them. So here they are set to 0 in
 * each such header, when this program's Marshal sets them; the first
 * call finds out whether it does by marshalling an array of 8.
 *
 * A value with a custom block other than an int32 or an int64 (a
 * bigarray), or with a closure, is given back as Marshal wrote it. *)

val to_string : 'a -> Marshal.extern_flags list -> string
