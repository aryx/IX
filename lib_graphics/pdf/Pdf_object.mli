(* Pdf_object: the eight kinds of thing a PDF file is made of, and
   their syntax -- PostScript's, without the programs.

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

   The same parser reads a page's content (Pdf_render): there the
   words that are no value -- m, l, Tj, re -- are operators, given
   back as [keyword]s.

   cs-history:
   The syntax is PostScript's (Adobe, 1984; itself from the Forth
   family: values pushed, then a word that uses them), kept when PDF
   dropped PostScript's procedures, loops and variables. That is why
   a page's content still reads "100 200 m" -- operands first.

   Reference: ISO 32000-1:2008, section 7.3. *)
(* ix: mini-chrome's libs/pdf/Pdf_object.mli; parse's optional length is parse_with's, said; parse is with none (docs/plans/plan_pdf.md) *)

type t =
  | Null
  | Bool of bool
  | Int of int
  | Real of float
  | String of string
  | Name of string
  | Array of t list
  | Dict of dict
  | Stream of dict * string (* its bytes as in the file: filters not undone *)
  | Ref of int (* an object's number *)

and dict = (string * t) list

(* [parse_with ~length s i]: the object that starts at i (spaces and
 * comments skipped), and where it ends. A stream's /Length may be a
 * reference: [length] finds it; failing that, the bytes go up to
 * "endstream". "<< /A 1 /B [2 (x)] >>" is
 * Dict [("A", Int 1); ("B", Array [Int 2; String "x"])] *)
val parse_with : length:(t -> int option) -> string -> int -> t * int

(* the same, no reference followed (ix: the length was optional) *)
val parse : string -> int -> t * int

(* a word that is no value (an operator), if the object is one *)
val keyword : t -> string option

(* a number, whole or not (0 for anything else) *)
val to_float : t -> float

val to_int : t -> int

(* the syntax's characters *)
val is_space : char -> bool

val is_regular : char -> bool
val hex : char -> int

(* past spaces and comments *)
val skip : string -> int -> int

(* a run of regular characters from i, and where it ends *)
val word : string -> int -> string * int
