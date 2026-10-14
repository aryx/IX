\title{cleanname}{1}{files}

# NAME
cleanname – a name made its shortest form

# SYNOPSIS
**cleanname**
[ **-d** *pwd* ]
*name* ...

# DESCRIPTION
*Cleanname* writes each *name* with no `.` nor empty part, and no
`..` that a part before it answers. No file is looked at: the name is
text, as the kernel takes it. With **-d** *pwd*, a name that does not
start at the root is taken from that directory.

# EXAMPLES
```
cleanname a//b/./c/../d                a/b/d
cleanname -d /usr/glenda lib/../bin    /usr/glenda/bin
```

# SEE ALSO
\man{basename}{1}, \man{pwd}{1}; Plan 9's *cleanname*(1)
