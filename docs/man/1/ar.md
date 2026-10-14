\title{ar}{1}{devtools}

# NAME
ar – a library of objects, for the linker

# SYNOPSIS
**ar**
*key*
*lib*`.a`
[ *object* ... ]

# DESCRIPTION
*Ar* keeps the objects of \man{asm}{1}, \man{cc}{1} and \man{ml}{1}
in one file, a library, with the names each defines, from which
\man{ld}{1} takes those a program needs. The *key*:

`u`
:    The *objects* put in the library, which is made if it is not
     there; one of the same source takes the place of the older.

`t`
:    The library's objects, by their sources.

`v`
:    With `u`, each object said, `a` added or `r` replaced; with `t`,
     the names each defines.

`c`
:    Taken.

# EXAMPLES
```
ar u libc.a print.7 exits.7
ar tv libc.a
```

# DIFFERENCES
The keys `u`, `t` and `v` only: no `r`, `d`, `x`, `m`, `p` nor `q`,
nor a *posname*. The file is ix's own, the objects marshalled with
their index, and not *ar*'s format: only ix's linker reads it.

# SEE ALSO
\man{ld}{1}, \man{mk}{1}; Plan 9's *ar*(1)

# DIAGNOSTICS
A file that is no object is said, and the status is 1.
