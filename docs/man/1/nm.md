\title{nm}{1}{devtools}

# NAME
nm – the names of an executable, an object or a library

# SYNOPSIS
**nm**
[ **-aghnsTu** ]
*file* ...

# DESCRIPTION
*Nm* lists the names of each *file*, a line each: the value in
hexadecimal, a letter, the name, sorted by name. An executable's are
its symbol table's (\man{ld}{1} **-g**), an ELF's its **.symtab**
(Linux's, gcc's too: nm's **r** and **W** as **D** or **T**); an
object's and a library's are what it defines and what it names
without defining, with no value.

**T** text, **D** data, **B** bss, in lower case when the name is
local to its file; **L** a function that calls none; **U** a name
undefined in an object. With **-a** also: **f** a component of a
file's path, **z** a path where a file's lines start (none: where it
ends), **m** a function's frame, **a** a local, **p** a parameter.

**-a**
:    Every entry, the names starting with `.` or `$` too.

**-g**
:    The global names only.

**-u**
:    The undefined names only.

**-n**
:    By value, not by name.

**-s**
:    In the table's order.

**-h**
:    No file's name before each line (there with several files, or a
     library's members).

**-T**
:    A column of signatures before (zeros).

# EXAMPLES
```
nm hello
nm -n /bin/tar | sed 20q
nm -u Tar.5
```

# DIFFERENCES
An object and a library are ix's (\man{asm}{1}'s, \man{cc}{1}'s,
\man{ml}{1}'s), not Plan 9's format. With **-n** names of equal
values stay in the table's order, where Plan 9's are in its qsort's.

# SEE ALSO
\man{where}{1}, \man{ld}{1}, \man{ar}{1}; Plan 9's *nm*(1)
