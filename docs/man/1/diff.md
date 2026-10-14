\title{diff}{1}{text}

# NAME
diff – how two files differ

# SYNOPSIS
**diff**
[ **-abcefmnruw** ]
*file1* ... *file2*

# DESCRIPTION
*Diff* writes the changes that make *file1* into *file2*: lines
added (`a`), deleted (`d`) or changed (`c`), the first file's after
`<`, the second's after `>`. A file is `-` for the standard input.
Several files are each compared with the file of the same name in the
directory *file2*; two directories, their files of the same names,
and `Only in` *dir*`:` for the others.

**-e**, **-f**
:    An *ed* script that makes *file2* from *file1*; **-f**: in forward
     order, not for *ed*.

**-n**
:    Each change with the files' names and its lines' numbers.

**-c**, **-a**
:    Each change with its context, three lines around it, the lines
     changed marked `-` and `+`; **-a**: the whole file as context.

**-u**
:    Unified: the changes with their context, `-` and `+` lines under
     `@@` headers.

**-b**, **-w**
:    Runs of blanks the same; blanks ignored.

**-m**
:    The names of the files are shown.

**-r**
:    The directories' subdirectories too.

# EXAMPLES
```
diff old.c new.c
diff -u old.c new.c
diff -r dir1 dir2
```

# DIFFERENCES
**-u** is ix's, not Plan 9's.

# SEE ALSO
\man{merge3}{1}, \man{cmp}{1}, \man{git}{1}; *diff*(1)

# DIAGNOSTICS
The status is 0 for files the same, 1 when some differ, 2 for an
error. Binary files are said to differ, and no change counted.
