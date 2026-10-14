\title{man}{1}{typesetting}

# NAME
man – a page of the manual

# SYNOPSIS
**man**
[ **-v** ]
[ **-m** *dir* ]
[ **-T pdf** ]
[ *section* ]
[ *title* ... ]

# DESCRIPTION
*Man* finds the pages of the manual named *title* and writes them
for a terminal, as \man{troff}{1} does. With a *section*, a number
from 1 to 8, only that section's page is written; with none, every
section's.

With no *title*, the *section*'s pages are listed, by groups, each with
what its NAME says it is; with no *section* either, every section's:

```
man 1
```

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
a `\title{name}{section}{group}` as its first line, as this one is.
The group is where the page is listed: `shell`, `files`, `text`,
`calc`, `time`, `processes`, `system`, `devtools`, `languages`, `typesetting`,
`apps`, `browsers`, `network`, `emulators`, `games`, in that order,
others after them; a page that says none, as Plan 9's, is in `other`.
A page of ix's program that has a twin in Plan 9 says how the two
differ, under DIFFERENCES.

# EXAMPLES
```
man troff
man 1
man 1 man
man -T pdf troff > /tmp/troff.pdf
```

# FILES
`/lib/man/?/*`

# SEE ALSO
\man{troff}{1}

# DIAGNOSTICS
A title with no page is said, and the status is `no page`.
