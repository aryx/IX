\title{lex}{1}{devtools}

# NAME
lex – a lexer's description made a lexer, in OCaml

# SYNOPSIS
**lex**
[ **-o** *out*`.ml` ]
[ **-v** ]
*file*`.mll`

# DESCRIPTION
*Lex* reads a lexer's description, written as for *ocamllex*, and
writes the lexer in OCaml, *file*`.ml`, for \man{ml}{1}: one
automaton for all of a rule's regular expressions, run by `Lexing`'s
engine. The longest match wins, then the first clause.

```
let digit = ['0'-'9']
rule token = parse
  | digit+ as n  { INT (int_of_string n) }
  | eof          { EOF }
```

A regular expression: `'c'`, `"str"`, `_`, `eof`, `['a'-'z']`,
`[^ '"']`, a name, `r*`, `r+`, `r?`, `r1 r2`, `r1 | r2`, `r as x`.
A rule may have parameters.

**-o** *out*`.ml`
:    The lexer's file.

**-v**
:    Each rule's states and clauses, written.

**-h**
:    The description, by example.

# EXAMPLES
```
lex Lexer.mll
```

# DIFFERENCES
Plan 9's *lex*(1) is Lesk's, for C: actions in C, `yylex`, `-tvn9`.
This is *ocamllex*'s twin, OCaml's descriptions and actions, as ix's
compilers are written. Not read: `r1 # r2`, `shortest`, refill.

# SEE ALSO
\man{yacc}{1}, \man{ml}{1}; Plan 9's *lex*(1); OCaml's manual, its
chapter on *ocamllex*

# DIAGNOSTICS
An error names the file and the line, `Lexer.mll:3: ...`.
