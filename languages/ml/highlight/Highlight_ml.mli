(* Highlight_ml: every token of an OCaml file given its category
   (Highlight_code's, shared by every language), the colour a code
   view draws it in.

   A category says more than a token's kind: a lowercase name is a
   function being defined, a parameter, another module's value, a type
   or a capability. From the tokens alone, for now: codemap's fallback
   when a file does not parse, looking at a token's neighbours
   (Highlight_ml.ml says which rule sees what). What they cannot tell
   -- a name shadowed, a local of a nested function -- waits for the
   parser (plan_tinybox_codemap.md, step 3).

   Worked example (the tests'):

     let move (p : point) ~dx = Point.add p dx

     let: Keyword         move: Def_function    p: Parameter
     point: Type          ~dx: Label            Point: Module
     add: Global          p, dx: Parameter

   Here the parser did not have to be waited for: it is mini-ml's.
   [categorize] is the guess from the tokens, and [lines] puts over it
   what Names_ml reads off the compiler's own tree (a parameter, a
   local, a field), where the text parses; the item being typed, which
   does not, keeps the guess. The playground has a second parser for
   this (Parse_ml), tolerant and its own; an editor inside the system
   that has the compiler asks the compiler. mini-emacs's Ocaml_mode is
   who calls [lines].

   design:
   Two sources for a color, the cheap one first. A lexer never fails
   and sees one token; a parser knows what a name is and fails on the
   line being typed, which is the line being looked at. An editor
   that colors from the parser alone blinks at each keystroke, one
   that colors from the tokens alone cannot tell a parameter from a
   global. Tree-sitter, in today's editors, is one answer (a parser
   that recovers from errors and reparses only what changed); the
   guess under the parse is the small one. *)

(* the tokens of a file, each with its category *)
val categorize : Token_ml.t list -> (Token_ml.t * Highlight_code.category) list

(* [src] lexed, categorized and cut into lines, ready to draw *)
val lines : string -> Highlight_code.span list array

