(* This module expands words to lists of strings, because rc's only
 * value is a list.
 *
 *     x=(a b c)
 *     $x        a b c          three words, never re-split
 *     $#x       3
 *     $"x"      'a b c'        ($ and a double quote, then x) one word, joined
 *     $x(2)     b              $x(2 3) b c, $x(2-) b c, $x(9) nothing
 *     $3        $*(3)          and $#3 is 1 or 0
 *     $$y       the variable whose name is $y's value
 *
 * {b Concatenation distributes} (principia's exec.c, Xconc):
 *
 *     a^(b c)          ab ac        one with each
 *     (a b)^(c d)      ac bd        pairwise
 *     (a b)^(c d e)    error: mismatched list lengths in concatenation
 *     ()^a             error: null list in concatenation
 *     ()^()            ()
 *     $x.o             a.o b.o c.o  the lexer's free caret, $x^.o
 *
 * This is not mk's rule: mk glues .o to the last word only, giving
 * a b.o.
 *
 * `{cmd} is cmd's output split on the characters of $ifs, and
 * `sep{cmd} splits it on those of sep. A variable's value, a count and
 * a backquote's output are literal, and never globbed again:
 * x='*'; echo $x prints *. Only the characters written unquoted in the
 * source are pattern characters (Glob). A variable's name is itself a
 * word, which is expanded and must give one word, or rc says
 * "variable name not singleton!".
 *
 * design:
 * Input is never scanned more than once. That is Duff's first
 * principle: rc is "not a macro processor". In the Bourne shell a
 * variable is a string, and using it pastes its text into the
 * command, which is then split on blanks and globbed again. So a file
 * named "my file" becomes two arguments unless every $x is written
 * "$x", and the shell has four kinds of quoting to say when not to
 * split. If a value is a list, nothing needs splitting again, one
 * quote is enough, and the whole table above follows. `{cmd} is the
 * same choice: it is parsed with the command around it, where
 * Bourne's `cmd` is a string that is parsed later and needs
 * backslashes "exponential in the nesting depth".
 *
 * others:
 * The shells after rc agree. fish's variables are lists, PowerShell's
 * are objects, and in bash and zsh the advice is to use arrays and to
 * write "${x[@]}", which is rc's $x with seven more characters.
 *
 * References: rc(1), "Variables", "Concatenation"; principia's
 * exec.c (Xdol, Xcount, Xqdol, Xsub, subwords, Xconc) and processes.c
 * (Xbackq); Tom Duff, "Rc -- The Plan 9 Shell" (1990), "Design
 * Principles"; S. R. Bourne, "The UNIX Shell" (Bell System Technical
 * Journal, 1978), the shell of strings re-split on IFS that rc
 * replaces. *)

exception Error of string

(* what expansion needs from the shell *)
type ctx = {
  var : string -> string list;              (* [] if unset *)
  backquote : string -> Ast.cmd -> string;  (* runs it, and gives its output *)
  pipefd : Ast.side -> Ast.cmd -> string;       (* <{cmd}: a /dev/fd name *)
}

(* the words a word expands to, each still knowing its quoting *)
val expand : ctx -> Ast.word -> Glob.word list

(* [split seps s]: s cut at each of the characters of [seps] *)
val split : string -> string -> string list

(* the one string a word must expand to, e.g. a variable's name *)
val singleton : ctx -> Ast.word -> string
