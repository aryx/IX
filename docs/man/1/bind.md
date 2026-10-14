\title{bind}{1}{system}

# NAME
bind – a name of the name space made another

# SYNOPSIS
**bind**
[ **-q** ]
[ **-b** | **-a** | **-c** | **-bc** | **-ac** ]
*new*
*old*

# DESCRIPTION
*Bind* makes *old* be *new* too, in this process's name space and
those that share it (the shell's): a file, or a directory with what
is under it.

**-b**, **-a**
:    *New* goes before, or after, what *old* already is: a union of
     directories.

**-c**
:    Files may be created there.

**-q**
:    Nothing said when it fails.

It is Plan 9's system call: on another system it only fails.

# EXAMPLES
```
bind -a $home/bin/rc /bin
bind '#c' /dev
bind -b /mnt/wsys /dev
```

# DIFFERENCES
No **-C** (a mount's cache). *mount* and *unmount* have pages of their
own.

# SEE ALSO
\man{mount}{1}, \man{unmount}{1}; Plan 9's *bind*(1) and *bind*(2)

# DIAGNOSTICS
What failed is said with the system's reason, unless **-q**.
