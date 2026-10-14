\title{mk}{1}{devtools}

# NAME
mk – files made from others, by the rules of a mkfile

# SYNOPSIS
**mk**
[ **-f** *mkfile* ]
[ **-aeiknstuH** ]
[ **-d**[**egp**] ]
[ **-w** *file* ]
[ *var*`=`*value* ... ]
[ *target* ... ]

# DESCRIPTION
*Mk* is Plan 9's: it reads `mkfile` and remakes the *targets* that are
older than what they are made from, running each rule's recipe with
`$MKSHELL` (`sh` when not set), several at once when `$NPROC` says.
The mkfile's language is Plan 9's *mk*(1): variables that are lists
of words, `<file` to include, `%` and `&` in metarules, regular
expressions (`:R:`), attributes (`:V:`, `:Q:`, `:N:`, `:P:`...),
`$target`, `$prereq`, `$stem`, archives' members `lib.a(x.o)`. With
no target, the first rule's.

```
hello: hello.o
	cc -o $target $prereq
%.o: %.c
	cc -c $stem.c
```

**-n**
:    The recipes written and not run; **-e**: why each would run.

**-a**
:    Everything remade; **-t**: the targets touched instead.

**-k**
:    Going on after a recipe that failed.

**-s**
:    The targets one after the other.

**-w** *file*
:    As if *file* were just modified.

**-u**
:    How long 0, 1, 2... recipes ran at once.

**-d**[**egp**]
:    The jobs, the graph, the rules, written.

**-H**
:    Out of date by content and not by date: the files' sums kept in
     `.mkhash`.

*var*`=`*value*
:    Over the mkfile's *var*.

**-h**
:    The options and a mkfile, by example.

# DIFFERENCES
**-H** is ix's. **-i** is taken: a missing intermediate is always
made. `$MKSHELL` is `sh` by default on another system than Plan 9's.

# SEE ALSO
\man{rc}{1}, \man{ar}{1}; Plan 9's *mk*(1), the language whole, and
Andrew Hume's paper, "Mk: a Successor to Make"

# DIAGNOSTICS
A target with no rule, a cycle, a recipe that failed are said; the
status is then not empty.
