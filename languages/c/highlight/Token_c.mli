(* Token_c holds C's text as tokens, and keeps every one of them.

   As in Token_ml for OCaml, the comments are tokens, and each token has
   its text, as it is in the file, and its place, so that a view can
   draw a file from its tokens alone.

   C has a language above C, the preprocessor's. A line starting with #
   is a directive, up to its end (or further, after a backslash).
   Nothing here runs the directives: no #include is read and no macro is
   expanded. But their tokens say that they are in a directive ([pp]),
   so that the parser can read them apart (Parse_c reads a #define's
   name and the branches of an #if). *)

type kind =
  | Comment (* /* ... */, // ... *)
  | Keyword (* int, struct, if, return, sizeof, ... *)
  | Ident (* x, Proc, USED: any name, whatever it names *)
  | Int (* 42, 0xFF, 10UL, 0777 *)
  | Float (* 1.5, 1e-3, .5f *)
  | Char (* 'a', '\n', L'x' *)
  | String (* "...", L"...", <u.h> after #include *)
  | Operator (* + -> ++ <<= ? : ... *)
  | Punctuation (* ( ) [ ] { } , ; *)
  | Directive (* #include, # define: the # of a directive and its word *)
  | Error (* a character C does not know *)

type t = {
  kind : kind;
  text : string; (* as in the file *)
  offset : int; (* the offset of its first byte, from 0 *)
  line : int; (* the line of its first character, from 1 *)
  col : int; (* from 0, in bytes *)
  pp : bool; (* whether it is on a directive's line(s), directive included *)
}

val show_kind : kind -> string

(* whether a name is written like NAME, N2 or O_RDWR, which by C's
 * habit is a macro or an enum's constant *)
val is_constant : string -> bool
