\title{xargs}{1}

# NAME
xargs – a command run with the input's lines as its arguments

# SYNOPSIS
**xargs**
[ **-n** *lines* ]
[ **-p** *procs* ]
*command*
[ *arg* ... ]

# DESCRIPTION
*Xargs* reads its standard input and runs *command* with its *args*
and then the input's lines, ten at a time, as many times as it
takes. A line is one argument, with its blanks. Nothing is run when
there is no line. A *command* with no `/` in its name is looked for
in `/bin` too.

**-n** *lines*
:    So many lines a run.

**-p** *procs*
:    So many runs at once; one when not said.

# EXAMPLES
```
walk -f | grep '\.c$' | xargs wc -l
```

# SEE ALSO
\man{walk}{1}, \man{rc}{1}

# BUGS
The status is always success: a run that failed is not counted.
