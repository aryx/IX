(* What of Forth is written in Forth: the control structures (words
 * that are IMMEDIATE, and compile a jump), the defining words over
 * CREATE and DOES>, and a few of the stack's.
 *
 *     : CONSTANT CREATE , DOES> @ ;       a word that defines words
 *     42 CONSTANT ANSWER                  ANSWER .   prints 42
 *
 * CONSTANT has two times in it. What is before DOES> runs when
 * CONSTANT does: CREATE makes a new word from the next name of the
 * text, and the comma puts 42 after it. What is after DOES> runs
 * each time the new word does, with the address of its data on the
 * stack: @ fetches the 42. An array, a record's field, a state
 * machine's state are made the same way, a line each: the language
 * has no data structure built in, and the means to make any.
 *
 * design:
 * The language is its own library. Forth (the OCaml) has the words
 * that touch the machine and two jumps; IF, DO and VARIABLE are here,
 * in the language, as a program's own would be. It is Lisp's bet,
 * macros over a small core, without a tree: a Forth macro is a word
 * that runs while a definition is compiled and writes into it. *)
val text : string
