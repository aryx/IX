\title{dotnet}{1}{languages}

# NAME
dotnet – run a .NET assembly

# SYNOPSIS
**dotnet**
[ **-v** | **-debug** | **-quiet** ]
[ **-trace** ]
[ **-s** ]
[ **-jit** ]
*file*`.dll`
[ *arg* ... ]

**dotnet**
**-S** [ **-jit** [ **-m** 5|7 [ **-refs** ] ] ] | **-tables** | **-size**
*file*`.dll` ...

# DESCRIPTION
*Dotnet* runs a .NET assembly, a file as Microsoft's C# compiler or
\man{tiger}{1} writes it: its metadata read, its classes loaded when
first named, its methods' IL run by an interpreter. The *args* are
given to its Main. Its library is its own, the classes of `System`
that programs use most: Object, String, Console, the exceptions,
StringBuilder, List, Dictionary, the delegates.

**-v**, **-debug**, **-quiet**
:    As every ix program's (\man{common}{1}). **-v** says the files
     read, the assemblies loaded, and with **-jit** the methods taken
     and each one compiled (an instance of a generic one too), its
     size and its call-outs to the interpreter; **-debug** also the
     classes loaded, why each method is not compiled, where its code
     is.

**-trace**
:    Each instruction is said as it runs, on the standard error.

**-s**
:    At the end, the instructions run, and with **-jit** the methods
     compiled.

**-jit**
:    The methods the JIT takes (their arguments, locals and stack of
     int32s and references, not structs, longs, doubles or pointers;
     no try) are compiled each at its first call and run as the
     machine's code; the others by the interpreter. The code reads fields and array
     elements itself; for a call into the library or to a virtual
     method, `new`, a string, a static field or a cast it asks the
     interpreter, an instruction at a time. Where *dotnet* was built
     by mini-ml for Plan 9 on arm (its code in segments: segattach,
     segflush) or for Linux on arm64; elsewhere the interpreter runs
     all. With **-S**, that code as the assembler's text, arm's
     (**-m 5**, the default) or arm64's (**-m 7**), of methods of
     int32s only, and why each other method is not compiled;
     **-refs**, the code **-jit** runs.

**-S**
:    The assembly's types, their fields and methods, and the
     methods' IL, as Microsoft's ildasm writes them; nothing run.

**-tables**
:    The metadata's tables, a row a line.

**-size**
:    The assembly's types, methods and bytes of IL.

# EXAMPLES
```
dotnet /lib/dotnet/hello.dll
dotnet -s /lib/dotnet/queens.dll
dotnet -S /lib/dotnet/fib.dll
dotnet -S -jit -m 7 /lib/dotnet/fib.dll
dotnet -S -jit -m 7 -refs /lib/dotnet/queens.dll
tiger -o /tmp/q.dll /lib/tiger/queens.tig; dotnet /tmp/q.dll
```

# SEE ALSO
\man{tiger}{1}, \man{common}{1}

# DIAGNOSTICS
An exception no one catches is said as .NET says it, `Unhandled
exception.` and its type and message, and the status is 134, as
for a recursion too deep (10,000 calls). What the library has not,
or the machine (several dimensions' arrays, calli), is said with its
method, and the status is 1.

# BUGS
A string's characters are bytes, Latin-1: one above 255 is `?`.
Native integers are 32 bits. No threads, no reflection but a type's
name.
