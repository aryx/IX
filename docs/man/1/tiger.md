\title{tiger}{1}{languages}

# NAME
tiger – compile Tiger to .NET

# SYNOPSIS
**tiger**
[ **-o** *file*`.dll` ]
*file*`.tig`

# DESCRIPTION
*Tiger* compiles a program of Tiger, Andrew Appel's language of his
"Modern Compiler Implementation" books, with fork-tiger's
exceptions (`exception`, `raise`, `try` ... `handle`), to a .NET
assembly, which \man{dotnet}{1} runs (and Microsoft's `dotnet`, with
the *file*`.runtimeconfig.json` written beside it). The assembly is
*file*`.dll`, in the current directory, or the **-o** one. The
program's value, if an integer, is its status.

The library: `print`, `printi`, `flush`, `getchar`, `ord`, `chr`,
`size`, `sizea`, `substring`, `concat`, `not`, `exit`.

# EXAMPLES
```
tiger /lib/tiger/queens.tig; dotnet queens.dll
tiger -o /tmp/q.dll /lib/tiger/queens.tig
```

# SEE ALSO
\man{dotnet}{1}

# DIAGNOSTICS
An error is said with its file, line and column, and nothing is
written; the status is 1.

# BUGS
A `try` inside an expression whose other operands are computed is
refused by Microsoft's JIT (InvalidProgramException).
