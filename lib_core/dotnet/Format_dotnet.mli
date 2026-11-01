(* Format's printf functions on .NET, in place of lib_core's (as
 * Printf_dotnet's): the format, the compiler's function of its literal,
 * applied to the formatter's pp_print_string. Its @ directives are
 * text there (@. a newline, the boxes nothing): what is printed is
 * Format's without its line breaking, the same while the lines fit. *)

val fprintf : Format.formatter -> ('a, Format.formatter, unit) format -> 'a
val printf : ('a, Format.formatter, unit) format -> 'a
