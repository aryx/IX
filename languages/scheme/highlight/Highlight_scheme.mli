(* Highlight_scheme: a Scheme file's text given its categories
 * (Highlight_code's, shared by every language), the colour an editor
 * draws it in. Written for ix, as the playground's Highlight_ml for
 * OCaml, far simpler: Scheme's text is parentheses and names.
 *
 *     (define (sum n)              define: Keyword, sum: Def_function
 *       (if (< n 1) 0              if: Keyword_control, 1 and 0: Number
 *           (+ n (sum (- n 1))))) ; a comment      the rest plain
 *
 * A name after an opening parenthesis is a keyword if it is one of
 * the special forms'; after (define and (define ( it is what is
 * defined. Nothing fails: a string or a #| comment not closed goes to
 * the text's end. *)

val lines : string -> Highlight_code.span list array
