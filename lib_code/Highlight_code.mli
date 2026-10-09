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
   some 80), and one of our own: [Capability], a Cap.* type or a caps argument, where a
   program's authority is (the repository's capabilities). *)

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
