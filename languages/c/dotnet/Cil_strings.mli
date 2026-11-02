(* C's strings for mini-cc -dotnet: the literals, and print's formats
 * compiled.
 *
 * A literal is an sbyte[] (int8[], NUL ended) in a static field of the
 * program, made at its first use from a .NET string (ldstr, then
 * <cstr>, which takes each char's low byte: the writer's user strings
 * are Latin-1, a byte a char), and the same field for the same bytes.
 * A pointer to it is a Ptr<int8> as any char*: a program may write in
 * a literal, as in Plan 9's C.
 *
 * print and sprint are not calls: their format, a literal, is compiled
 * where they are, as mini-ml's Printf (Il_printf). The arguments are
 * computed first, in order (Cil_exprs), then each piece of text or verb
 * is a call of libc.c's _puts, _putc or _putint between _begin
 * (sprint's buffer, or nil) and _end (the count):
 *
 *     print("%d: %s\n", n, s)     _begin(nil); _putint(n, 10, 0, 0, 0);
 *                                 _puts(": ", 0, 0); _puts(s, 0, 0);
 *                                 _puts("\n", 0, 0); _end()
 *
 * The verbs are Plan 9's, as goken's libc and the tests' have them:
 * %d %x %X %o %b %c %s, flags - and 0 and a width, h and l, and %u a
 * verb of its own (%ud prints the number, then a d). *)

open Cil_types

(* Check.outstring's: the literals' bytes, their offsets *)
val outstring : string -> int -> int
val reset : unit -> unit

(* a .NET string to a C string (int8[], NUL ended): the method *)
val cstr : c -> int
(* a literal's bytes, from its .string name's type and offset *)
val literal_bytes : int -> Tree.typ -> int -> string
(* its array pushed *)
val literal_array : c -> code -> string -> unit

(* libc.c's functions whose calls the compiler makes (_puts, exits...) *)
val helper : c -> string -> int

(* a format's pieces: sprint's buffer (pushed by the function), the
 * arguments and what pushes each, the format's text *)
val format :
  c -> code -> int -> (unit -> unit) option -> (Tree.expr * (unit -> unit)) list ->
  string -> unit
