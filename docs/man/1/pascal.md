\title{pascal}{1}{languages}

# NAME
pascal – the Pascal language, compiled to P-code and run

# SYNOPSIS
**pascal**
[ **-S** ]
[ **-disk** ]
[ **-seed** *n* ]
[ **-s** ]
*file*`.pas` ...

# DESCRIPTION
*Pascal* compiles each *file*, in one pass as Pascal-P and UCSD
Pascal did, to P-code, the code of a stack machine, and runs it on
that machine. A *file* that is not found here is looked for among
the programs that come with it.

The language: integer, boolean, char, subranges, arrays and records;
`const`, `type`, `var`; procedures and functions, nested, recursive,
`forward`, with value and `var` parameters; `if`, `case`, `while`,
`repeat`, `for`; `write`, `writeln`, `read`, `readln` (the next
line typed) and `random`.

**-S**
:    The P-code, an instruction a line, with its address and the
     line of the source; nothing is run.

**-disk**
:    The names of the programs that come with it: `HELLO.PAS`,
     `QUEENS.PAS`, `HANOI.PAS`...

**-seed** *n*
:    `random`'s numbers from the seed *n*, and not from 1, which
     gives the same numbers every time.

**-s**
:    At the end, the instructions the machine ran.

**-h**
:    How, by examples.

# EXAMPLES
```
pascal hello.pas
pascal -S hello.pas
pascal QUEENS.PAS
pascal -seed 7 GUESS.PAS
```

# SEE ALSO
\man{turbopascal}{1}, \man{forth}{1}

# DIAGNOSTICS
An error of the compiler is said with its line and column, and
nothing is run; an error at run time (a range checked, a division by
zero, the stack used up) with Turbo Pascal's number for it and its
line. The status is then 1.

# BUGS
No reals, sets, pointers, files or `with`.
