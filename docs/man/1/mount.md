\title{mount}{1}

# NAME
mount – a file server's tree put in the name space

# SYNOPSIS
**mount**
[ **-a** | **-b** ]
[ **-cCnq** ]
[ **-k** *keypattern* ]
*service*
*dir*
[ *spec* ]

# DESCRIPTION
*Mount* opens *service*, a file posted in `/srv` or a connection,
and makes *dir* the tree that the server at its other end gives:
each open, read or write of a name under *dir* is then a 9P message
to the server, which can be any program. *Spec* says which of its
trees, when it serves several (for \man{dossrv}{1}, a device).

The name space is the process's own, shared with the processes it
starts: anyone may mount.

**-b**
:    The tree before what is in *dir*: a union, its files found
     first.

**-a**
:    The tree after what is in *dir*.

**-c**
:    A file may be made in the union.

**-C**
:    What is read is cached.

**-q**
:    Nothing said when it fails.

**-n**, **-k** *keypattern*
:    Taken, and nothing done: there is no authentication.

# EXAMPLES
```
dossrv
mount -c /srv/dos /n/c /dev/sdM0/dos
```

# SEE ALSO
\man{bind}{1}, \man{unmount}{1}, \man{dossrv}{1}; Plan 9's *mount* is
in its *bind*(1)

# DIAGNOSTICS
A service that cannot be opened and a mount refused are said, with
the kernel's reason.
