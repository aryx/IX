(* Bib: a bibliography's file, BibTeX's .bib, read.
 *
 *   @book{kernighan-ritchie,
 *     author    = {Brian W. Kernighan and Dennis M. Ritchie},
 *     title     = "The C Programming Language",
 *     publisher = {Prentice Hall},
 *     year      = 1978
 *   }
 *
 * An entry is a kind, a key (what \cite names) and fields, each a
 * name and a text between braces or quotes, or a number. What is
 * outside the entries is a comment, as is @comment; @string (a name
 * for a text) and @preamble are passed over. A field's text is given
 * as it is written: it is LaTeX, and its reader's to read.
 *
 * cs-history:
 * BibTeX is Oren Patashnik's (1985), written for LaTeX: the
 * references of a paper in a file of their own, shared by all the
 * papers that cite them, and a program that picks the ones cited
 * and writes them in a journal's style -- a style being a program in
 * a stack language of BibTeX's own (plain.bst is 1,100 lines). Here
 * there is one style, in the LaTeX reader: the authors, the title,
 * where it appeared, the year. *)

type entry = { kind : string; key : string; fields : (string * string) list }

(* the entries, in the file's order; a field's name in lower case *)
val read : string -> entry list
