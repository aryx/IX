\title{chmod}{1}{files}

# NAME
chmod – a file's permissions changed

# SYNOPSIS
**chmod**
*mode*
*file* ...

# DESCRIPTION
*Chmod* gives each *file* the *mode*: in octal (`644`), or as
*who* *op* *what*. *Who* is letters of `u`, `g`, `o`, `a` (the owner,
the group, the others, all; all when none); *op* is `+` (given), `-`
(taken) or `=` (these and no other); *what* is letters of `r`, `w`,
`x`, and of the file's own bits: `a` (append only), `l` (one opener
at a time), `t` (temporary).

# EXAMPLES
```
chmod 755 script
chmod a-w notes
chmod +a log
```

# SEE ALSO
\man{ls}{1}; Plan 9's *chmod*(1)

# DIAGNOSTICS
A file whose mode could not be changed is said, and the next tried;
the status is empty even then, as Plan 9's. A bad *mode*: `mode`.
