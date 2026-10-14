\title{cc}{1}{devtools}

# NAME
cc – the C compiler, for arm and arm64

# SYNOPSIS
**cc**
[ **-m** *arch* ]
[ **-S** ]
[ **-x** ]
[ **-o** *out* ]
[ **-I** *dir* ]
[ **-D** *name*[=*value*] ]
*file*`.c`

# DESCRIPTION
*Cc* compiles *file*`.c`, Plan 9's C, to its object, *file*`.5`
or *file*`.7` in the current directory, for \man{ld}{1}. It is the
twin of *5c* and *7c*: the same instructions, the same listing.
There is no preprocessor apart: `#include`, `#define` and `#if`
are read by the compiler. Other flags of *5c*'s are taken and do
nothing.

**-m 5**
:    For arm, as *5c*. What is done with no **-m**.

**-m 7**
:    For arm64, as *7c*.

**-o** *out*
:    The object is *out*.

**-I** *dir*
:    An `#include` is looked for in *dir* too.

**-D** *name*[=*value*]
:    *name* is defined, as by a `#define`.

**-S**
:    The listing of the code, *5c*'s, byte for byte, and no object.

**-x**
:    Each function's trees.

**-simple**
:    Another back end, whose contract is the program's behavior and
     not *5c*'s bytes: a stack machine. With it, **-dir** prints its
     code, **-O** runs all its optimizations and one as **-Oincs**
     runs that one.

**-facts**, **-flow**
:    No object: the file as facts for \man{datalog}{1}, those of a
     pointer analysis (what is assigned to what, who calls whom), or
     each function's code (who follows whom, what is read and
     written). **-dflow** gives the compiler's own liveness, to
     compare.

**-h**
:    How, by examples.

# EXAMPLES
```
cc -m 5 -I/sys/include -I/arm/include hello.c
ld -m 5 -o hello hello.5 libc.a
5i hello
cc -m 7 -facts hello.c > hello.dl
```

# SEE ALSO
\man{asm}{1}, \man{ld}{1}, \man{5i}{1}, \man{datalog}{1},
\man{8c}{1}

# DIAGNOSTICS
An error names the file and the line, `hello.c:5: syntax error`,
and the status is not 0.
