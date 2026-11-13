(* Lexer_c cuts C's text into tokens (Token_c), comments included.

   It is written with ocamllex, as Lexer_ml is. The longest match makes
   "->" one token, "<<=" one token, and "L'x'" a character. The rules
   are those of C99 and of Plan 9's C as 5c's lexer reads it (Lexer.mll
   in xix's compiler); the two are the same except for a few keywords.
   gcc's __attribute__ is a keyword, and the parser skips what follows
   it.

   The preprocessor's lines: a # that starts a line starts a directive.
   It is a [Directive] token, made of the #, the spaces and the word
   ("#define", "# if"). The tokens up to the end of the line are [pp],
   and so are those of the next line while a line ends with a
   backslash. After #include, <u.h> is one [String]. A # inside a
   directive (a macro's # and ##, for stringizing and pasting) is an
   [Operator].

   A worked example (from the tests):

     #define N 10 /* max */
     static int f(char *s) { return s[0] == 'a'; }

     Directive #define  Ident N  Int 10  Comment /* max */ (all pp)
     Keyword static  Keyword int  Ident f  Punctuation (  Keyword char
     Operator *  Ident s  Punctuation )  Punctuation {  Keyword return
     Ident s  ...  Operator ==  Char 'a'  Punctuation ;  Punctuation }

   The lexer never fails: an unclosed comment runs to the end of the
   file, an unclosed string or character runs to the end of its line,
   and a character C does not know is an [Error] token. *)

val tokens : string -> Token_c.t list
