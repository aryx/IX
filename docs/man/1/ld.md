\title{ld}{1}

# NAME
ld – the linker, for arm and arm64

# SYNOPSIS
**ld**
**-m** *arch*
[ **-H2** | **-H6** | **-H7** | **-H0** **-T** *address* ]
[ **-nofollow** ]
[ **-v** ]
[ **-map** ]
[ **-E** *entry* ]
[ **-o** *out* ]
*file* ...

# DESCRIPTION
*Ld* links the objects of \man{asm}{1}, \man{cc}{1} and
\man{ml}{1}, and libraries made by \man{ar}{1}, into an executable,
`a.out` unless **-o** says otherwise. It encodes the instructions in
words: the bytes are those of goken's *5l* and *7l*.

Of a library, the members that define a name still undefined are
taken. A name declared `GLOBL n(SB), $32, $0` is weak: no member is
taken for it, and where nothing defines it its address is 0 and a
call to it is no call. So a program in ML links only the units of
the library that it uses.

**-m 5**, **-m 7**
:    For arm, or for arm64.

**-H7**
:    An ELF file. What is done with no **-H**.

**-H2**
:    Plan 9's *a.out*.

**-H6**
:    Mach-O.

**-H0**
:    No header: a kernel's image, its text at the address of **-T**.

**-E** *entry*
:    The program starts at *entry*, and not at `_main`.

**-nofollow**
:    The code laid in the objects' order, and not along its flow as
     *5l* does: the same program, not goken's bytes.

**-v**
:    Each instruction, its address and its word.

**-map**
:    *out*`.map` is written too: each function's address and name.

**-h**
:    How, by examples.

# EXAMPLES
```
asm -m 5 hello_linux_arm.s
ld -m 5 -E _start hello_linux_arm.5
5i a.out
ar u my.a hello.5
ld -m 5 -o hello my.a libc.a
```

# SEE ALSO
\man{asm}{1}, \man{cc}{1}, \man{ml}{1}, \man{5i}{1}, \man{ar}{1},
\man{8l}{1}

# DIAGNOSTICS
A name defined nowhere is said with the file and the line that use
it: `hello.c:0: undefined: print`.
