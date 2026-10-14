\title{basename}{1}{files}

# NAME
basename – a name's last part

# SYNOPSIS
**basename**
[ **-d** ]
*string*
[ *suffix* ]

# DESCRIPTION
*Basename* writes what follows the last `/` of *string*, without
*suffix* when it ends with it; with **-d**, what is before that `/`,
its directory (`.` when there is none). For a script.

# EXAMPLES
```
basename /sys/src/cmd/ls.c .c          ls
basename -d /usr/glenda/lib            /usr/glenda
```

# SEE ALSO
\man{cleanname}{1}; Plan 9's *basename*(1)
