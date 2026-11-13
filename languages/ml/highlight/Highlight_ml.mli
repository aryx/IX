(* Highlight_ml gives every token of an OCaml file its category (from
   Highlight_code, which every language shares), which is the colour a
   code view draws it in.

   A category says more than a token's kind: a lowercase name may be a
   function being defined, a parameter, another module's value, a type
   or a capability. The category is found from the tokens alone, by
   looking at a token's neighbours (Highlight_ml.ml says which rule
   sees what); this is codemap's fallback when a file does not parse.
   What the tokens cannot tell, such as a shadowed name or a local of a
   nested function, waits for the parser (plan_tinybox_codemap.md,
   step 3).

   A worked example, from the tests:

     let move (p : point) ~dx = Point.add p dx

     let: Keyword         move: Def_function    p: Parameter
     point: Type          ~dx: Label            Point: Module
     add: Global          p, dx: Parameter

   Here we did not have to wait for the parser, since we have
   mini-ml's. [categorize] is the guess from the tokens, and [lines]
   puts over it what Names_ml reads off the compiler's own tree (a
   parameter, a local, a field) where the text parses. The item being
   typed, which does not parse, keeps the guess. The playground has a
   second parser of its own for this (Parse_ml), a tolerant one; an
   editor inside a system that has the compiler can ask the compiler.
   mini-emacs's Ocaml_mode is what calls [lines].

   design:
   There are two sources for a color, and the cheap one comes first. A
   lexer never fails, and it sees one token; a parser knows what a
   name is, but it fails on the line being typed, which is the line
   being looked at. An editor that colors from the parser alone blinks
   at each keystroke, and one that colors from the tokens alone cannot
   tell a parameter from a global. Tree-sitter, in today's editors, is
   one answer (a parser that recovers from errors and reparses only
   what changed); putting the guess under the parse is the small
   answer. *)

(* the tokens of a file, each one with its category *)
val categorize : Token_ml.t list -> (Token_ml.t * Highlight_code.category) list

(* [src] lexed, categorized and cut into lines, ready to be drawn *)
val lines : string -> Highlight_code.span list array

