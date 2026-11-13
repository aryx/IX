(* Lexer_ml cuts OCaml's text into tokens (Token_ml), comments included.

   Written with ocamllex (the plan's decision, plan_tinybox_codemap.md):
   OCaml's lexical grammar is a list of regular expressions, and ocamllex
   turns it into one automaton that takes the longest match: "::" is
   one token, not two ":", "let*" is one keyword, "'a'" is a character
   and "'a" is a type variable. The rules are ocaml-light's (those of
   OCaml 1.07), with what later versions of OCaml added and this
   repository uses.

   A worked example, from the tests:

     let f ~x = (* hi *) M.g x "s" 'c' 'a

     Keyword let  Lident f  Label ~x  Operator =  Comment (* hi *)
     Uident M  Operator .  Lident g  Lident x  String "s"  Char 'c'
     Type_var 'a

   It never fails: a file that OCaml would reject is still cut, so that
   a view can colour it. An unclosed comment or string runs to the end,
   and a character that OCaml does not know is an [Error] token. *)

val tokens : string -> Token_ml.t list
