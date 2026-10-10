(* Pascal_compile: Pascal to P-code, in one pass.

   Wirth's compilers read the program once, from left to right, and
   emit the code as they recognize it: there is no syntax tree. Each
   rule of the grammar is a function (recursive descent, as in
   Formula.mli), and each function, as it parses, checks the types and
   writes the instructions of what it parsed:

       parse_term reads "b * 2":
         parse_factor: b is a variable at offset 6   -> lod 0,6
         sees *, parse_factor: 2 is a constant       -> ldc 2
         both integers, so                           -> mpi

   The code of a term comes out in reverse Polish order simply because
   an operator is emitted after its operands are parsed. That is the
   whole code generator of a one-pass compiler, and it is why Pascal's
   grammar is what it is: everything declared before it is used
   (constants, types, variables, then procedures, then the body), so
   that when the parser meets a name it already knows what it is and
   where it lives. Where that can't be -- two procedures calling each
   other -- Pascal has "forward": the heading first, the body later.

   Jumps forward (the end of an if, a call to a procedure compiled
   later) go to *labels*, numbered as they are needed and given an
   address when the parser gets there; a last step replaces each label
   by its address. Pascal-P patched its jumps in place instead
   (backpatching): the same idea.

   The language: Wirth's Pascal (the User Manual and Report, 1974)
   without reals, sets, pointers, files, variant records, goto and
   with: integer (16 bits, as on the machines of Turbo Pascal's time:
   maxint is 32767), boolean, char, subranges (1..10, checked when
   assigned), arrays (of arrays: a[i, j]) and records; constants
   (strings too, for write); procedures and functions, nested, with
   value and var parameters, recursion and forward; if, case (with
   Turbo Pascal's else), while, repeat, for; write, writeln (a width
   after a colon: write(x:5)), read, readln, and the functions abs, sqr,
   odd, ord, chr, succ, pred, eoln and Turbo's random(n).

   The first error stops the compilation, with its line and column, as
   Turbo Pascal did (it then put the editor's cursor there): "Error:
   Type mismatch".

   design:
   A language made for its compiler. One pass was the economy of
   1970: to read a program twice, or to keep it whole as a tree, cost
   memory and time that a computer shared by a university gave
   sparingly, and Wirth wanted a compiler fast and small enough for
   students' programs. So the text goes by once and what is kept is a
   table of names. Pascal's rules follow from it one by one: declarations
   first and in a fixed order, forward, a keyword at the start of
   every construct so that one token decides which function parses
   it, no expression whose type depends on what comes after. A
   grammar that a recursive descent can follow without ever going
   back is called LL(1); Wirth wrote his languages to be that, where
   C needed yacc (mini-yacc) and a table of typedef names.

   others:
   What one pass cannot do is anything that needs the whole of a
   procedure before its first instruction: keep a variable in a
   register, drop code that is never reached, see that i * i is
   computed twice. mini-cc and mini-ml build a tree first for that,
   and passes over it. Turbo Pascal stayed with one pass and
   machine code of the plainest kind, and won on the time from a
   key's press to a program running; the program's own speed came
   from machine code being its target, with no machine in between.

   References: Niklaus Wirth, "Algorithms + Data Structures =
   Programs" (Prentice-Hall, 1976), chapter 5 (PL/0), and "Compiler
   Construction" (Addison-Wesley, 1996; Oberon-0): a compiler of this
   shape built step by step. *)

type error = { line : int; col : int; message : string }

val compile : string -> (Pcode.program, error) result
