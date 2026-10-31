\title{csc}{1}{languages}

# NAME
csc – compile a reduced C# to .NET

# SYNOPSIS
**csc**
[ **-o** *file*`.dll` ]
*file*`.cs`

# DESCRIPTION
*Csc* compiles a program of C#, reduced to what simple programs
use, to a .NET assembly, which \man{dotnet}{1} runs, and Microsoft's
`dotnet` too, with the *file*`.runtimeconfig.json` written beside
it. The assembly is *file*`.dll`, in the current directory, or the
**-o** one. One file a program; its `Main` is where it starts.

The C# is that of C# 1, with `foreach` and the library's generic
classes:

-    Classes and interfaces; their fields, methods, constructors
     (`: base(...)`, `: this(...)`; a default one where none is
     written), properties with a getter; static fields' initial
     values; `public`, `private`, `protected`, `internal`, `static`,
     `abstract`, `virtual`, `override`, `sealed`, `new`, `readonly`.
     A class may name one declared after it.
-    Statements: blocks, local variables, `if`, `while`, `do`, `for`,
     `foreach` (over an array or a collection of the library),
     `return`, `break`, `continue`, `throw`, `try` with `catch` and
     `finally`.
-    Expressions: numbers (`int`, `long`, `double`), strings,
     characters, `true`, `false`, `null`; fields, methods, indexing;
     `new` of an object or an array, an array's initial elements;
     arithmetic, comparisons, `&&`, `||`, `!`, `?:`; `=` and
     `+=` ..., `++`, `--`; casts, `is`; `out` and `ref` arguments.

The library is \man{dotnet}{1}'s: what *csc* accepts of `System`
(Object, String, Console, StringBuilder, List, Dictionary, the
exceptions) is what *dotnet* has, from the same description of it. A call's overload is the one whose arguments convert at the least
cost, as C#'s rules say (the same type, then a widening or a parent
class, then a box to `object`): `Console.WriteLine(n + 1)` with `n`
an `int` calls `WriteLine(int)`.

# EXAMPLES
```
csc hello.cs; dotnet hello.dll
csc -o /tmp/q.dll queens.cs; dotnet -s /tmp/q.dll
csc shapes.cs; dotnet -S shapes.dll
```

# SEE ALSO
\man{dotnet}{1}, \man{tiger}{1}

# DIAGNOSTICS
An error is said with its file and line, the first one only, and
nothing is written; the status is 1:

```
vec.cs:4: class expected, not struct
generic.cs:4: { expected, not <
strings.cs:26: a character '$'
```

# BUGS
No structs, no generic classes or methods of the program's own (the
library's are used: `List<int>`), no delegates or lambdas, no
`switch`, no string interpolation (`$"..."`), no properties with a
setter, no operator overloading. Not on mini-9pi's card yet: its
programs are compiled on the host.
