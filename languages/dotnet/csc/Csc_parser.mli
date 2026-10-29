(* The reduced C#'s text to its tree (Csc_ast), by recursive descent
 * over the tokens (Csc_lexer), each with its line.
 *
 * By hand, where mini-tiger's grammar is ocamlyacc's: C# is not
 * LALR(1). (T)x is a cast or a parenthesized expression by what follows
 * the parenthesis (C#'s 7.7.6: a cast if T is a predefined type, or if
 * an operand starts after it); `a < b` is a comparison but List<int> a
 * type; a statement that starts with a name is a declaration if a type
 * and a name follow, else an expression. Each needs to look past a
 * whole type, which the parser does by trying one and going back.
 * Roslyn's parser is written by hand too, for the same reasons.
 *
 *     List<int> primes = new List<int>();    try_type: List<int>, then a
 *                                            name and = : a declaration
 *     (Exceptions)o                          a type, ), a name: a cast
 *     (n % p == 0)                           an expression *)

exception Error of string * int

val program : string -> Csc_ast.program
