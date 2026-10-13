\title{man}{1}

# NAME
man – a page of the manual

# SYNOPSIS
**man**
[ **-v** ]
[ **-m** *dir* ]
[ **-T pdf** ]
[ *section* ]
*title* ...

# DESCRIPTION
*Man* finds the pages of the manual named *title* and writes them
for a terminal, as \man{troff}{1} does. With a *section*, a number
from 1 to 8, only that section's page is written; with none, every
section's.

The manual is a tree of files: a page is the file
*dir*`/`*section*`/`*title*. *Dir* is `/sys/man` where there is one,
and `/lib/man` otherwise.

**-m** *dir*
:    The manual is in *dir*.

**-T pdf**
:    The page as a PDF file, on the standard output.

**-v**
:    What was not understood in the page is said, on the standard
     error.

A page is written for *man*(6)'s macros, or in Markdown's lines with
a `\title{name}{section}` as its first line, as this one is.

# EXAMPLES
```
man troff
man 1 man
man -T pdf troff > /tmp/troff.pdf
```

# FILES
`/lib/man/?/*`

# SEE ALSO
\man{troff}{1}

# DIAGNOSTICS
A title with no page is said, and the status is `no page`.
