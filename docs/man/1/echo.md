\title{echo}{1}{shell}

# NAME
echo – its arguments, on the standard output

# SYNOPSIS
**echo**
[ **-n** ]
[ *arg* ... ]

# DESCRIPTION
*Echo* writes its arguments, a space between two, then a newline, in
one write: a line written to a device's `ctl` file is one message. No
backslash means anything.

**-n**
:    The first argument: no newline.

# EXAMPLES
```
echo hello, world
echo -n 'a prompt: '
echo kill > /proc/$pid/ctl
```

# SEE ALSO
\man{rc}{1}; *echo*(1)
