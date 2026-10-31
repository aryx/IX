\title{acid}{1}{devtools}

# NAME
acid – a debugger that is a language

# SYNOPSIS
**acid**
[ **-l** *library* ] ...
[ *pid* | *program* [ *pid* ] ]

# DESCRIPTION
*Acid* is Plan 9's debugger: it reads its libraries (each a file of
acid), then the standard input, a statement at a time, and prints
each statement's value. Its statements are C's (**if** *e* **then**
*s* **else** *s*, **while** *e* **do** *s*, **loop** *a*, *b* **do**
*s*), with lists (**head**, **tail**, **append**, **delete**,
**{**a**,** b**}**), and functions (**defn**, with **local** and
**return**). A value has a format, given by a backslash: *x*\\**D**
decimal, \\**X** hexadecimal, \\**s** a string, \\**c** a character.

A *program* gives its symbols as variables (a global's value is its
address, **\***n1 what is there), and *f*:*v* the address of
*f*'s parameter or local *v*. A process, started by **new**() or given
by its *pid*, gives its memory (**\***addr; **@**addr in the file)
and its registers (**\***PC, **\***R0).

The rest is the library's, written in acid: *port.acid* and the
machine's (*arm.acid*, *arm64.acid*):

**new**()
:    Starts the program, stopped before its first instruction.

**bpset**(*f*), **bpdel**(*f*)
:    A breakpoint at a function, or at an address: **filepc**("x.c:28")
     is a line's.

**cont**(), **step**(), **next**()
:    Runs to the next breakpoint; one instruction; one line, over the
     calls.

**stk**(), **lstk**()
:    The stack: each frame's function, its parameters, where it is
     (its file and line); **lstk** its locals too.

**src**(*addr*), **asm**(*f*), **regs**(), **mem**(*addr*, *fmt*)
:    The source around an address; a function disassembled; the
     registers; memory.

**ml**(*v*), **mlvars**()
:    An ML value, by its type when **ml -g** described it (else by
     its words); every global of the program. A unit's global is
     *M*.*x*.

A program's types are acid's declarations (**aggr**, **complex** *T*
*v*): from \man{cc}{1} **-a**'s file of a C source, given by **-l**;
in the program, as \man{cc}{1} **-g** and \man{ld}{1} **-g** write
them; or, in gcc's program, from its DWARF. A value of a structure
type then prints field by field (n1, n1.next->name, **\***walk:n).

On Plan 9, *acid* debugs the arm programs of \man{cc}{1}, \man{ml}{1}
and \man{asm}{1}, linked by **ld -g -H2**. On Linux (arm64) it debugs
an ELF of the machine by ptrace: theirs, linked by **ld -g -H7**, and
gcc's.

**-l** *library*
:    Reads *library* first. The default is the directory of
     **$ACIDLIB**, else ix's *debuggers/acid/lib* above the
     executable, else */lib/acid*: *port.acid* and the program's
     machine's. A **-l** naming a *port.acid* replaces both.

**-h**
:    How, by examples.

# EXAMPLES
The language alone:

```
acid
acid: defn fact(n) { if n <= 1 then return 1; return n*fact(n-1); }
acid: fact(10)\D
3628800
```

A C program (*debuggers/tests/acid/linux/target.c*), compiled by gcc
on Linux; its types are its DWARF's:

```
gcc -g -O0 -o target target.c
acid ./target
acid: new()
acid: bpset(leaf)
acid: cont()
acid: lstk()
leaf(a=0x0)+0x0 target.c:27
walk(n=0xaaaaaaac0038,k=0xa)+0x30 target.c:37
	q=0x200000001
main+0x18 target.c:43
acid: *walk:n
acid: step()
```

A parameter is stored by the function's first instructions: at a
breakpoint on the function, it is not yet. A line after it shows it:

```
acid: bpset(filepc("target.c:28"))
```

The same program by ix's compiler (*L* is ix's *_mk/7/lib_core*):

```
cc -m 7 -g -o target.7 target.c
ld -m 7 -g -H7 -o target target.7 $L/libc.a
acid ./target
```

An ML program (*debuggers/tests/acid/mlvalues/Values.ml*); *I* is
**-I** of each of ix's *lib_core*'s directories, and the start
unit names the library's units, in order:

```
U=`{ar t $L/lib_core.a | sed 's,.*/,,; s,\.ml$,,'}
ml -m 7 -O3 -g -I . $I -o Values.7 Values.ml
ml -m 7 -O3 -start $U Values Std_exit -o Values.start.7
ld -m 7 -g -H7 -nofollow -o target Values.start.7 $L/lib_core.a \
	Values.7 $L/std_exit.7 $L/runtime.7 $L/libc.a
acid ./target
acid: new()
acid: bpset(f2_down)
acid: cont()
acid: stk()
acid: ml(Values.tree)
Node (Leaf, "b", Node (Leaf, "c", Leaf))
acid: mlvars()
```

An ML function's name is its symbol's: *f2_down* is the second
function of its unit. **ml -g** says a unit's file by its path in ix
(*apps/rio/Rio.ml*): **src** finds it in **srcpath**'s directories,
*./* and */src/* (the card's); on the host, ix's directory added:

```
acid: srcpath = append srcpath, "/home/you/ix/"
```

An assembly program, each instruction its line:

```
asm -m 7 -o hello.7 hello_linux_arm64.s
ld -m 7 -g -H7 -E _start -o target hello.7
acid ./target
acid: newproc("")
acid: step()
acid: src(*PC)
```

*debuggers/tests/acid/*'s *.acid* files are sessions, each with its
output beside it (*.out*); *acid_linux.sh* and *acid_proc.sh* build
their programs.

# FILES
*debuggers/acid/lib/port.acid*, *arm.acid*, *arm64.acid*

# SEE ALSO
\man{cc}{1}, \man{ml}{1}, \man{asm}{1}, \man{ld}{1}, \man{5i}{1}, \man{nm}{1}

# BUGS
On Linux, gcc's program is debugged at **-O0**: an optimized
function's frame ends the stack. A DWARF location in a register or
a location list is not read. A local of ML is not shown: it is on
ML's own stack, not in the tables.
