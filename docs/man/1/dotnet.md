\title{dotnet}{1}{languages}

# NAME
dotnet – run a .NET assembly

# SYNOPSIS
**dotnet**
[ **-trace** ]
[ **-s** ]
*file*`.dll`
[ *arg* ... ]

**dotnet**
**-S** | **-tables** | **-size**
*file*`.dll` ...

# DESCRIPTION
*Dotnet* runs a .NET assembly, a file as Microsoft's C# compiler or
\man{tiger}{1} writes it: its metadata read, its classes loaded when
first named, its methods' IL run by an interpreter. The *args* are
given to its Main. Its library is its own, the classes of `System`
that programs use most: Object, String, Console, the exceptions,
StringBuilder, List, Dictionary, the delegates.

**-trace**
:    Each instruction is said as it runs, on the standard error.

**-s**
:    At the end, the instructions run.

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
tiger -o /tmp/q.dll /lib/tiger/queens.tig; dotnet /tmp/q.dll
```

# SEE ALSO
\man{tiger}{1}

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
