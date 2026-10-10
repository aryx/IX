(* Highlight_c: every token of a C file given its category
   (Highlight_code's, shared by every language), the colour a code view
   draws it in.

   Two passes, as Highlight_ml: a token's kind gives a first category
   (a keyword, a number, a comment; a name in capitals a constant, by
   C's habit), then the tree (Parse_c) says what each name is -- a
   function or a global defined, a parameter, a local within its
   block, a field (declared, p->x, s.x, .x = in an initializer), a type,
   an enum's constant, a label, a #define's name and parameters. What
   did not parse keeps the first category.

   Worked example (the tests'):

     static int f(Proc *p) { int n = p->len; return n; }

     static: Keyword  int: Type  f: Def_function  Proc: Type
     p: Parameter  n: Local  p: Parameter  len: Field  n: Local

   Here only the first pass was copied (Highlight_c.ml's first line
   says so: the playground's Parse_c and Ast_c, a thousand lines, were
   not), so the above is the playground's answer and this module's is
   the first category alone:

     static: Keyword  int: Type  return: Keyword_control
     f, Proc, p, n, len: Normal  (N or O_RDWR would be Constructor,
     a name in capitals)

   A banner comment, a line of stars, and the comment it frames are
   Comment_section. Highlight_ml got its second pass back from
   mini-ml's parser (Names_ml); the same from mini-cc's is not done:
   its parser declares as it reads and keeps no tree of a file, and
   needs the headers a file includes, where a highlighter is asked to
   color one file as it is. mini-emacs's C_mode is who calls [lines].

   design:
   C is the language a highlighter cannot parse honestly. What a name
   is depends on the declarations before it, typedefs above all
   (Lexer.mli of the compiler), and those are in headers, behind
   macros a highlighter does not expand. So every editor's C colors
   are guesses of this kind, by capitals and by neighbours, until it
   asks a compiler that has seen the build's flags; that is what the
   language servers (clangd) are for. *)

(* the tokens of a file, each with its category *)
val categorize : Token_c.t list -> (Token_c.t * Highlight_code.category) list

(* [src] lexed, categorized and cut into lines, ready to draw *)
val lines : string -> Highlight_code.span list array

