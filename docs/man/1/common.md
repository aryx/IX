\title{common}{1}{system}

# NAME
common – the options every ix program may take: -v, -debug, -quiet

# SYNOPSIS
*program*
[ **-v** | **-debug** | **-quiet** ]
...

# DESCRIPTION
A program of ix says what it does, beside what it prints, on the
standard error, each line headed by its name and the line's level:

```
mini-dotnet: [INFO] read hello.dll: 4096 bytes
mini-dotnet: [INFO] assembly hello loaded: 2 types, 2 methods
```

By default only the warnings are said. Three options say more or
less, and a page that lists them refers here:

**-v**
:    What the program does: the files it reads and writes, what it
     loads and makes (the info level).

**-debug**
:    **-v**'s and the details, for whom looks at the program from
     within (the debug level).

**-quiet**
:    Nothing, not even the warnings.

The last of them given counts. Without them, the environment's
`IX_LOG` sets the level: `warning` (the default), `info` or `debug`,
for a program called by another, or whose options cannot change.

What a program prints as its original does (an error, its output) is
not of these lines, and none of the options change it.

# EXAMPLES
```
dotnet -v /lib/dotnet/fib.dll
IX_LOG=debug asm -o a.5 a.s
```

# SEE ALSO
\man{dotnet}{1}

# BUGS
The programs that take them are few yet: mini-dotnet. A program whose
original gave one of these options a meaning of its own keeps it
(awk's **-v** *var*=*value*): `IX_LOG` is its way.
