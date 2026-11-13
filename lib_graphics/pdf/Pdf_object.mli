(* Pdf_object has the eight kinds of thing that a PDF file is made of,
   and their syntax, which is PostScript's without the programs.

     null   true false   42   -3.14   /Name   (a string)   <68656c6c6f>
     [ 1 2 /three ]                    an array
     << /Type /Page /Count 3 >>        a dictionary: names and values
     12 0 R                            a reference to object 12
     << /Length 5 >> stream            a stream: a dictionary, then
     hello                             bytes -- a page's drawing, a
     endstream                         font, a picture

   A string in parentheses has escapes (\n, \), \101 in octal) and may
   hold balanced parentheses as they are; between < and > it is
   hexadecimal. A name may spell a byte #20. % starts a comment.

   The same parser reads a page's content (Pdf_render). There, the
   words that are not values (m, l, Tj, re) are operators, and they
   are given back as [keyword]s.

   cs-history:
   The syntax is PostScript's (Adobe, 1984), which itself comes from
   the Forth family, where values are pushed and then a word uses
   them. It was kept when PDF dropped PostScript's procedures, loops
   and variables. That is why a page's content still reads
   "100 200 m", with the operands first.

   Reference: ISO 32000-1:2008, section 7.3. *)
(* ix: from mini-chrome's libs/pdf/Pdf_object.mli. parse's optional
 * length is parse_with's explicit one, and parse is without one
 * (docs/plans/done/plan_pdf.md) *)

type t =
  | Null
  | Bool of bool
  | Int of int
  | Real of float
  | String of string
  | Name of string
  | Array of t list
  | Dict of dict
  | Stream of dict * string (* its bytes as in the file, filters not undone *)
  | Ref of int (* an object's number *)

and dict = (string * t) list

(* [parse_with ~length s i] is the object that starts at i (after the
 * spaces and comments), and where it ends. A stream's /Length may be a
 * reference, which [length] follows; when it cannot, the bytes go up
 * to "endstream". "<< /A 1 /B [2 (x)] >>" is
 * Dict [("A", Int 1); ("B", Array [Int 2; String "x"])] *)
val parse_with : length:(t -> int option) -> string -> int -> t * int

(* the same, with no reference followed (ix: the length was optional) *)
val parse : string -> int -> t * int

(* the word, if the object is a word that is not a value (an
 * operator) *)
val keyword : t -> string option

(* a number, whole or not (0 for anything that is not a number) *)
val to_float : t -> float

val to_int : t -> int

(* the syntax's characters *)
val is_space : char -> bool

val is_regular : char -> bool
val hex : char -> int

(* [skip s i] is the position past the spaces and comments at i *)
val skip : string -> int -> int

(* the run of regular characters from i, and where it ends *)
val word : string -> int -> string * int
