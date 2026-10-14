\title{pwd}{1}{files}

# NAME
pwd – the directory one is in

# SYNOPSIS
**pwd**

# DESCRIPTION
*Pwd* writes the current directory's name, as the kernel keeps it:
the name it was reached by, cleaned (`a/b/..` is `a`), and not found
by walking up.

# EXAMPLES
```
pwd
```

# DIFFERENCES
No *pbd* (the name's last part, for a prompt).

# SEE ALSO
\man{cleanname}{1}, \man{rc}{1}; Plan 9's *pwd*(1)
