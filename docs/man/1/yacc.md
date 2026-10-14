\title{yacc}{1}{devtools}

# NAME
yacc – a grammar made a parser, in OCaml

# SYNOPSIS
**yacc**
[ **-b** *prefix* ]
[ **-v** ]
*file*`.mly`

# DESCRIPTION
*Yacc* reads a grammar, written as for *ocamlyacc*, and writes its
LALR(1) parser in OCaml, *file*`.ml` and *file*`.mli`, for
\man{ml}{1}, run by `Parsing`'s engine. Precedences (`%left`,
`%right`, `%nonassoc`, `%prec`), a token's type, `$1`, `$sloc` and
`$loc`, and menhir's standard rules (`list(x)`, `x*`, `x+`, `x?`,
`separated_list(sep, x)`, `option(x)`...) are read.

A conflict is decided as yacc does, by the precedences, else the
shift or the earlier rule, and counted. A token in no rule, a rule
no start symbol leads to, a precedence that decides nothing are
warned of.

**-b** *prefix*
:    The parser is *prefix*`.ml` and *prefix*`.mli`.

**-v**
:    The automaton, its states and their actions, in
     *prefix*`.output`.

**-h**
:    The grammar, by example.

# EXAMPLES
```
yacc Parser.mly
yacc -v -b Pic_parser pic/Pic_parser.mly
```

# DIFFERENCES
Plan 9's *yacc*(1) is Johnson's, for C. This is *ocamlyacc*'s twin,
OCaml's grammars and actions. Not read: the `error` token, an action
in the middle of a rule, the rest of menhir's.

# SEE ALSO
\man{lex}{1}, \man{ml}{1}; Plan 9's *yacc*(1); OCaml's manual, its
chapter on *ocamlyacc*

# DIAGNOSTICS
An error names the file and the line, `Parser.mly:3: ...`. A syntax
error at run time raises `Parsing.Parse_error`.
