\title{wc}{1}{text}

# NAME
wc – lines, words and characters counted

# SYNOPSIS
**wc**
[ **-lwrbc** ]
[ *file* ... ]

# DESCRIPTION
*Wc* writes the number of lines, words and bytes of each *file*, or of
the standard input, and their total when there are several files. A
word is what is between spaces, Unicode's.

**-l**, **-w**, **-c**
:    Only the lines, the words, the bytes.

**-r**
:    The characters, UTF-8's.

**-b**
:    The bytes that are no character.

# EXAMPLES
```
wc -l *.ml
```

# SEE ALSO
\man{du}{1}; *wc*(1)
