\title{asm}{1}{devtools}

# NAME
asm – the assembler, for arm and arm64

# SYNOPSIS
**asm**
[ **-m** *arch* ]
[ **-o** *out* ] [ **-project** *dir* ]
[ **-v** | **-debug** | **-quiet** ]
*file*`.s`

# DESCRIPTION
*Asm* reads *file*`.s`, written in Plan 9's syntax for its
assemblers *5a* and *7a*, and writes its object, *file*`.5` or
*file*`.7`, for \man{ld}{1}. The object holds the instructions as
they are written; their encoding in words is the linker's, so an
instruction not known is said by the linker, with its file and line.

**-m 5**
:    For arm, as *5a*. What is done with no **-m**.

**-m 7**
:    For arm64, as *7a*.

**-o** *out*
:    The object is *out*.

**-project** *dir*
:    The project's top, from here (mkconfig gives its `$TOP`): the
     object names its source by its path from there
     (`assembler/Asm.ml`), the same wherever it was compiled and the
     tree is, which \man{ld}{1}'s **-map** manifest says. Without it,
     the source as given.

**-h**
:    How, by examples.

The syntax, a source operand before its destination:

```
TEXT _start(SB), $0
	MOVW $1, R0
	SWI $0
GLOBL msg(SB), $13
DATA msg+0(SB)/8, $"Hello, w"
```

**-v**, **-debug**, **-quiet**
:    As every ix program's (\man{common}{1}). **-v** says the file
     assembled, each `#include`, each **-data** file, and the object
     written.

# EXAMPLES
```
asm -m 5 hello.s
ld -m 5 -E _start -o hello hello.5
5i hello
```

# SEE ALSO
\man{ld}{1}, \man{cc}{1}, \man{5i}{1}, \man{8a}{1},
\man{common}{1}

# DIAGNOSTICS
An error names the file and the line, *file*`.s:3: ...`, and the
status is not 0.
