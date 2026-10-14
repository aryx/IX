\title{awk}{1}{text}

# NAME
awk – patterns and actions, on fields

# SYNOPSIS
**awk**
[ **-F** *fs* ]
[ **-v** *var*`=`*value* ]
[ **-f** *progfile* | *prog* ]
[ *file* ... ]

# DESCRIPTION
*Awk* runs the program *prog*, or the files of **-f**, on each line of
the *files* (or of the standard input), the line cut into fields `$1`,
`$2`, ... `$NF`. A rule is a pattern and an action:

```
awk '$2 > 1970 { n++; print $1 } END { print n, "lines" }' file
```

The language is the one of Aho, Weinberger and Kernighan's book, as
Plan 9's: functions, `getline`, `printf`, arrays by strings, `print >
file` and `| "command"`, and the built-in functions and variables;
*awk*(1) of Plan 9 tells it. An argument *var*`=`*value* among the
files is an assignment, done when reached.

**-F** *fs*
:    The field separator; `t` is a tab.

**-v** *var*`=`*value*
:    An assignment done before `BEGIN`.

**-h**
:    How, by examples.

# DIFFERENCES
**-safe** and **-d** are taken and do nothing; **-mf** and **-mr** are
said and ignored. An error in the program's text is said once, where
Plan 9's awk may say two more. `toupper` and `tolower` know ASCII's and
Latin-1's letters only. `if (x) /re/` is read as a division. A
command of `system` or a pipe is run by rc.

# SEE ALSO
\man{sed}{1}, \man{grep}{1}, \man{hoc}{1}; *awk*(1)

# DIAGNOSTICS
An error says the line and the record; the status is then 1, as when
`exit` is given a number not 0.
