\title{cat}{1}{files}

# NAME
cat – files one after another, on the standard output

# SYNOPSIS
**cat**
[ *file* ... ]

# DESCRIPTION
*Cat* reads each *file* in turn and writes it on the standard output,
or the standard input when there is none. No option.

# EXAMPLES
```
cat notes
cat part1 part2 > whole
```

# DIFFERENCES
Plan 9's page has *read* too (one line of a file): ix has no *read*.

# SEE ALSO
\man{tail}{1}, \man{xd}{1}; Plan 9's *cat*(1)

# DIAGNOSTICS
A file that cannot be opened, read or written stops it, said with the
system's reason; the status is then that message.
