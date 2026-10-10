(* Highlight_code: what a code view needs to colour a file, in any
   language.

   codemap's split (pfff's highlight_code/, 2010): the categories, their
   colours and a file as lines of coloured spans are the same for every
   language; only turning a language's tokens into categories is its own
   (Highlight_ml for OCaml, later Highlight_c...). So a view draws any
   language it is given the spans of.

   ix: the author's playground's libs/code/highlight, without the
   colours (the editor's own) and what a code map asks of a file.

   The categories are a subset of codemap's (Highlight_code.category,
   some 80), and one of our own: [Capability], a Cap.* type or a caps
   argument, where a program's authority is (the repository's
   capabilities).

   The two tables and this module between them:

       a file's text
          | a language's own: Highlight_ml (OCaml), Highlight_c,
          | Highlight_asm, Highlight_pascal, Highlight_prolog...
          v
       tokens, each its line, column, text and category
          | [lines], here: cut at the line ends
          v
       span list array, a line's spans in order
          | a view's own: mini-emacs's Highlight, a category to a
          v colour of its terminal or its window
       the frame drawn

   so n languages and m views are n + m pieces of code and not n * m,
   and a new language is coloured in every view the day it has a
   lexer. [lines] on two tokens, the second a comment over two lines:

       lines "let x\n(* a\nb *)" [ (1, 0, "let", Keyword);
                                     (2, 0, "(* a\nb *)", Comment) ]
       line 1:  { col = 0; text = "let"; category = Keyword }
       line 2:  { col = 0; text = "(* a"; category = Comment }
       line 3:  { col = 0; text = "b *)"; category = Comment }

   The x is in no span: it was given no token, and a view draws what
   is between spans in its default colour. A view that scrolls asks
   for a line's spans and needs nothing of the lines above it, which
   is the reason for the array.

   design:
   The categories say what a name is, not what it looks like:
   Def_function and Global are both a lowercase identifier to a
   lexer. Colouring by meaning (a definition bold where it is made, a
   parameter apart from a local, another module's value apart from
   one's own) shows a file's structure before it is read, where
   colouring by kind of token shows only that keywords are keywords.
   The price is that a language's side needs more than a lexer: the
   neighbours of a token at least, a parser's tree at best
   (Highlight_ml.mli says which it uses when).

   others:
   Emacs's font-lock, the usual way for thirty years, is a list of
   regular expressions per language, each with a face: quick to
   write, and wrong wherever a language is not regular (a string that
   holds a comment's opening). Editors since about 2018 run a real
   incremental parser for the same job (tree-sitter), or ask the
   compiler through a language server for the meaning of each name
   ("semantic tokens"). ix's editor is inside the system that has the
   compiler, and asks it. *)

type category =
  | Comment
  | Comment_section (* a banner, (*****...*) or its title *)
  | Keyword
  | Keyword_control (* if, match, while, for... *)
  | Keyword_module (* module, struct, #include... *)
  | Def_function (* where a global function is defined *)
  | Def_value (* ... a global value *)
  | Def_type (* ... a type, an exception, a struct *)
  | Def_module (* ... a module *)
  | Parameter (* a function's *)
  | Local (* a name defined inside a function *)
  | Global (* M.x: another module's value *)
  | Module (* M in M.x *)
  | Constructor (* Some, true, an enum's value *)
  | Type
  | Type_var
  | Label
  | Capability
  | Number
  | String
  | Operator
  | Punctuation
  | Attribute (* [@...], a preprocessor's line *)
  | Normal
  | Error
  | Field (* a record's field, where it is declared and where it is read: p.x *)

(* A file ready to draw: line by line, each a list of spans. A span is a
   token's piece on one line (a comment over three lines is three
   spans), its column where it starts, in bytes. *)
type span = { col : int; text : string; category : category }

(* [lines src tokens]: [src]'s lines, from its tokens, each given as its
   first line (from 1), its column (from 0), its text and its category;
   what lies between the tokens (spaces) is not in a span. *)
val lines : string -> (int * int * string * category) list -> span list array
