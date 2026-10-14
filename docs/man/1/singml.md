\title{singml}{1}{devtools}

# NAME
singml – mini-singularity's contracts, and a program checked as safe

# SYNOPSIS
**singml**
[ **-o** *dir* ]
*Name*`.contract`

**singml**
**-safe**
[ **-allow** *Module* ] ...
*file*`.ml`

**singml**
**-given**
[ **-o** *dir* ]
*Main*`.manifest`

**singml**
**-grants**
*Main*`.manifest`

# DESCRIPTION
*Singml* is what mini-singularity, ix's kernel after Microsoft's
Singularity, asks of the language beyond \man{ml}{1}: its programs
run in the kernel's address space and talk through channels, so
the compiler must refuse what could break out of a program, and a
channel's messages must follow its contract.

With a *Name*`.contract`, a contract's declaration, written in
OCaml's syntax, becomes its module, *Name*`.ml` and *Name*`.mli`,
for \man{ml}{1}: each end's operations, one per message it may
send. A message of the other end's, or one with a wrong argument,
does not compile.

```
type request = Ping of int
type reply = Ready | Pong of int
let rec start = send Ready; serve
and serve = function
  | Ping _ -> send Pong; serve
```

**-o** *dir*
:    The files are written in *dir*.

**-safe**
:    The program is looked at, and refused, with status 1, if it
     names `external`, a module that is not one of the standard
     library's that only compute, nor `Sip`, `Contract`, an
     **-allow**'s or one of its own (so `Obj`, `Marshal`, `Unix`), a
     name that starts with `unsafe_`, `input_value`, or an extension
     `[%...]`.

**-allow** *Module*
:    *Module*, a contract's, may be named.

**-given**
:    A manifest, what a program needs of the machine (registers,
     an interrupt), becomes the program's module `Given`.

**-grants**
:    The manifest as the kernel's list of what it grants.

**-h**
:    How, by examples.

# EXAMPLES
```
singml -o out contracts/Intro.contract
singml -safe -allow Pong programs/pong/Main.ml
singml -given -o out programs/console/Main.manifest
```

# SEE ALSO
\man{ml}{1}

# DIAGNOSTICS
An error names the file and the line, `Intro.contract:3: ...`.

# BUGS
*Ml*'s type checker, and the code of the modules allowed, are
trusted.
