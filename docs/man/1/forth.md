\title{forth}{1}

# NAME
forth – the Forth language

# SYNOPSIS
**forth**
[ **-e** *text* ] ...
[ **-trace** ]
[ **-s** ]
[ *file*`.fs` ... ]

# DESCRIPTION
*Forth* interprets Forth: words between spaces, a stack of data, a
stack of returns, and a dictionary, a word defined by `:` compiled
to threaded code. The *files* are interpreted in order, a line at a
time, then each **-e** *text*, all in one dictionary. With none, the
lines typed are interpreted, and `ok` is said after each. `BYE`
ends.

**-e** *text*
:    *Text* is interpreted.

**-trace**
:    Each word that is run, with the stack before it, indented by
     the depth of the stack of returns.

**-s**
:    At the end, the words that were run.

**-h**
:    How, by examples.

A cell has 63 bits; an address counts cells, and a character takes
one (`C@` is `@`).

# EXAMPLES
```
forth -e '2 3 + .'
forth -e ': SQUARE DUP * ;  7 SQUARE .'
forth -e ': SQUARE DUP * ;  SEE SQUARE'
forth sieve.fs
```

# SEE ALSO
\man{pascal}{1}, \man{scheme}{1}, \man{prolog}{1}

# DIAGNOSTICS
A mistake is said with its file and line, the word then `?`; the
stacks are emptied, the rest of that text is left, and the status
is 1.

# BUGS
No floats, double numbers, blocks, words for files (`INCLUDE`),
`KEY` or `ACCEPT`, vocabularies or assembler.
