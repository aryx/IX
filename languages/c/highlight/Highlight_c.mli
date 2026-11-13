(* Highlight_c gives every token of a C file its category, which says
   the colour a code view draws it in (the categories are
   Highlight_code's, shared by every language).

   There are two passes, as in Highlight_ml. First, a token's kind
   gives it a first category: a keyword, a number, a comment, or, for a
   name in capitals, a constant, by C's habit. Then the tree (Parse_c)
   says what each name is:
   - a function or a global that is defined;
   - a parameter, or a local within its block;
   - a field (declared, or used in p->x, s.x, or .x = in an
     initializer);
   - a type, an enum's constant, or a label;
   - a #define's name and its parameters.
   What did not parse keeps the first category.

   A worked example (from the tests):

     static int f(Proc *p) { int n = p->len; return n; }

     static: Keyword  int: Type  f: Def_function  Proc: Type
     p: Parameter  n: Local  p: Parameter  len: Field  n: Local

   Here only the first pass was copied. The first comment of
   Highlight_c.ml says that the playground's Parse_c and Ast_c, a
   thousand lines, were not. So the above is the playground's answer,
   and this module gives the first category alone:

     static: Keyword  int: Type  return: Keyword_control
     f, Proc, p, n, len: Normal  (N or O_RDWR would be Constructor,
     as names in capitals)

   A banner comment (a line of stars) and the comment that two banners
   frame are Comment_section. Highlight_ml got its second pass back
   from mini-ml's parser (Names_ml). The same is not done with
   mini-cc's parser, because it declares names as it reads, keeps no
   tree of a file, and needs the headers that a file includes, while a
   highlighter is asked to color one file as it is. [lines] is called
   by mini-emacs's C_mode.

   design:
   C is the language a highlighter cannot parse honestly. What a name
   is depends on the declarations before it, typedefs above all (see
   the compiler's Lexer.mli), and those are in headers, behind macros
   that a highlighter does not expand. So the C colors of every editor
   are guesses of this kind, made from capitals and from neighbours,
   until the editor asks a compiler that has seen the build's flags;
   that is what the language servers (clangd) are for. *)

(* the tokens of a file, each with its category *)
val categorize : Token_c.t list -> (Token_c.t * Highlight_code.category) list

(* [src] lexed, categorized and cut into lines, ready to draw *)
val lines : string -> Highlight_code.span list array

