(* mini-scheme: a small Scheme and How to Design Programs' Beginning
 * Student (docs/plans/plan_scheme.md), on a terminal: files run,
 * expressions evaluated, a prompt, the stepper's steps printed. No
 * window: big-bang's worlds and the images drawn are mini-drscheme's.
 * Its usage: [help] in CLI.ml, what mini-scheme -h prints.
 *
 *     text                             the modules, a text's way
 *        | Sexpr_read      parentheses to a tree, each part with
 *        |                 its place in the text
 *     Sexpr.t  ---------- Scheme_step: Beginning Student's programs
 *        |                 rewritten step by step, nothing run
 *        | Scheme_syntax   the forms checked, the derived ones (let,
 *        |                 cond, and, or...) rewritten into seven
 *     Scheme.expr
 *        | Scheme_eval     the CESK machine, a step at a time
 *        |    or Scheme_secd, Landin's machine (-secd)
 *        |-- Scheme_prims    car, +, string-append: in OCaml
 *        |-- Scheme_prelude  map, filter, sort: in Scheme
 *        '-- Scheme_image    a picture, a value
 *     Scheme.t             printed (Scheme.print), Scheme's way or
 *                          the teaching languages'
 *
 * Two languages on one machine. Scheme, the small Lisp of the lambda
 * papers, with closures, proper tail calls and call/cc: what the
 * machine is made to show. And Beginning Student, the first of How
 * to Design Programs' teaching languages, Scheme with most of it
 * taken away, so that a beginner's mistake is an error said in the
 * beginner's words and a program can be run as algebra (-step).
 *
 * evolution:
 * Scheme, from 1975 to Racket. Gerald Sussman and Guy Steele wrote a
 * small Lisp at MIT's AI Lab to understand Carl Hewitt's actors, and
 * the series of memos that followed, the "lambda papers" (1975 to
 * 1980), found in it most of what languages are made of: a
 * procedure call is a goto that passes arguments, a loop is a tail
 * call, assignment and control can be written with lambda, and a
 * compiler can be the same rewriting (Steele's RABBIT, 1978). The
 * name was to be Schemer, after the AI languages Planner and
 * Conniver; the file system kept six letters. The language was then
 * kept small by a committee that put in only what all its members
 * agreed on: the Revised Reports, to R5RS (1998), fifty pages;
 * R6RS (2007) grew and split its users, R7RS (2013) went back to a
 * small language. Abelson and Sussman's course and book (SICP, 1985)
 * made it the language of MIT's first course for twenty years. PLT
 * Scheme (Matthias Felleisen's group, from 1995) built a teaching
 * environment and then a language of languages around it, and took
 * the name Racket in 2010.
 *
 * why-study:
 * It is the shortest way from the lambda calculus to a language one
 * can program in, and the place where the words were sorted out:
 * closure, continuation, tail call, hygiene each have their paper
 * here and their module beside this one. JavaScript was Scheme's
 * closures and first-class functions under Java's syntax, by its
 * author's account, which is why a browser's engine and this
 * directory share their difficulties.
 *
 * References: Gerald Sussman and Guy Steele, "Scheme: An Interpreter
 * for Extended Lambda Calculus" (MIT AI Memo 349, 1975), and the
 * memos after it: "Lambda: The Ultimate Imperative" (1976), "Lambda:
 * The Ultimate Declarative" (1976), "Debunking the 'Expensive
 * Procedure Call' Myth" (1977), "The Art of the Interpreter" (1978).
 * Harold Abelson and Gerald Sussman with Julie Sussman, "Structure
 * and Interpretation of Computer Programs" (MIT Press, 1985; second
 * edition 1996): chapters 3 to 5 are this directory's subject, the
 * environment, the evaluator, the machine. Richard Kelsey, William
 * Clinger and Jonathan Rees, editors, "Revised^5 Report on the
 * Algorithmic Language Scheme" (1998). Matthias Felleisen, Robert
 * Findler, Matthew Flatt and Shriram Krishnamurthi, "How to Design
 * Programs" (MIT Press, 2001; second edition 2018). *)

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
