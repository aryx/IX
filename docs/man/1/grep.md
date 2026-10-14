\title{grep}{1}{text}

# NAME
grep – the lines that match a pattern

# SYNOPSIS
**grep**
[ **-bchiLlnsv** ]
[ **-e** *pattern* | **-f** *patternfile* | *pattern* ]
[ *file* ... ]

# DESCRIPTION
*Grep* writes the lines of each *file*, or of the standard input,
that the regular expression *pattern* matches: Plan 9's expressions,
with `|`, `( )`, `*`, `+` and `?`. Several **-e**, or a pattern of
several lines, are alternatives. With several files a line is written
after its file's name.

**-e** *pattern*
:    The pattern, which may start with a `-`.

**-f** *patternfile*
:    The patterns are the file's lines.

**-v**
:    The lines that do not match.

**-i**
:    Capitals and small letters the same.

**-n**
:    Each line after its number.

**-c**
:    Only how many lines match.

**-l**, **-L**
:    Only the names of the files with a match, without one.

**-h**
:    No file's name before a line.

**-s**
:    Nothing written: the status only.

# EXAMPLES
```
grep -n main *.c
walk -f | grep '\.ml$'
```

# DIFFERENCES
**-b** is taken and does nothing (Plan 9's: no output buffer). A line
is matched by each pattern in turn, where Plan 9's grep makes one
automaton of them all: the same lines, slower.

# SEE ALSO
\man{sed}{1}, \man{awk}{1}, \man{ed}{1}; *grep*(1), *regexp*(6)

# DIAGNOSTICS
The status is `no matches` when no line was written.
