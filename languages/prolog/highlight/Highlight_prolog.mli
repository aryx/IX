(* Highlight_prolog: a Prolog file's text given its categories
 * (Highlight_code's, shared by every language), the colour an editor
 * draws it in. Written for ix (docs/plans/plan_prolog.md, stage 6);
 * Datalog's files are the same text.
 *
 *     % a comment
 *     append([], L, L).                 append: Def_function, L: Local
 *     append([H|T], L, [H|R]) :-        :- Keyword
 *         append(T, L, R), !.           ! Keyword_control
 *     :- dynamic counter/1.             dynamic: Keyword_module
 *     greet :- write('hello'), nl.      'hello': String
 *
 * A name that starts a clause is what the clause defines; a clause
 * starts at the file's start and after a full stop (a dot before a
 * blank or the end). A variable starts with a capital or _. Nothing
 * fails: a quote or a comment not closed goes to the text's end. *)

val lines : string -> Highlight_code.span list array
