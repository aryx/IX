\title{ml}{1}

# NAME
ml – the OCaml compiler, for arm and arm64

# SYNOPSIS
**ml**
[ **-m** *arch* ]
[ **-S** | **-gas** ]
[ **-o** *out* ]
[ **-I** *dir* ]
[ **-i** ]
[ **-M** ]
*file*`.ml`

**ml**
[ **-m** *arch* ]
[ **-o** *out* ]
**-start** *unit* ...

**ml**
**-pp**
*file*`.ml`

# DESCRIPTION
*Ml* compiles a unit of OCaml, the language ix is written in, to its
object, *file*`.5` or *file*`.7`, for \man{ld}{1}. It behaves as
ocaml-light's *ocamlopt*. Another unit's names are read from its
`.mli`, or its `.ml`, in the source's directory and then in each
**-I** *dir*. A program is its units' objects, the object that
**-start** makes, and the runtime, linked.

**-m 5**
:    For arm. What is done with no **-m**.

**-m 7**
:    For arm64.

**-o** *out*
:    The object is *out*.

**-I** *dir*
:    The units are looked for in *dir* too.

**-L** *dir*
:    *Dir* is ix's `lib_core`: its standard library's directories
     and `commons/`, each an **-I**.

**-S**
:    The assembly, printed, and no object. **-gas**: GNU's, for arm.

**-i**
:    The types of the unit's toplevel, as `ocamlopt -i`.

**-M**
:    The units that the file names.

**-start** *unit* ...
:    The program's start: the units initialized in that order. A
     unit of a library that the program does not use is not linked.

**-pp**
:    The file printed as OCaml with ix's extensions rewritten
     (`[%bits]`, `[%list]`, `type t = [%mli]`, `[@@deriving show]`,
     the classes of `[@@class]` and `[%using]`), with `#` lines to the
     source's: a preprocessor for another OCaml compiler.

**-facts**, **-flow**
:    No object: the unit as facts for \man{datalog}{1}, of which
     function may be which variable's value, or of its functions in
     SSA form.

**-h**
:    How, by examples, and the options to debug the compiler
     (**-dast**, **-dscope**, **-dir**, **-dssa**, **-O**...).

# EXAMPLES
```
ml -i fact.ml
ml -m 7 fact.ml
ml -pp Prelude.ml
```

# SEE ALSO
\man{ld}{1}, \man{singml}{1}, \man{datalog}{1}

# DIAGNOSTICS
An error names the file and the line,
`fact.ml:2: this expression has type ...`, and the status is not 0.

# BUGS
The language is the subset of OCaml that ix is written in: a
program that ocamlopt takes may be refused.
