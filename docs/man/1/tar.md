\title{tar}{1}{files}

# NAME
tar – files and directories in one archive, and back

# SYNOPSIS
**tar**
*key*
[ *archive* ]
[ *name* ... ]

# DESCRIPTION
*Tar* writes files and whole trees into one file, an archive, lists
what is in one, and takes it out again. The *key* is letters, with a
`-` or without; the first of them says what to do:

**c**
:    A new archive of the *names*, directories with all that is under
     them.

**r**
:    The *names* added at the end of the archive.

**t**
:    The names in the archive, or those under the *names* given.

**x**
:    The archive's files made, or those under the *names*; a missing
     directory is made, a name from `/` is made under the current
     directory.

The other letters:

**f**
:    The archive is the file named by the next argument (or by the
     rest of the key); without **f**, the standard input or output.

**v**
:    With **t**, each name's mode, length and time; with **c**, **r**
     and **x**, the names on the standard error.

**z**
:    Compressed by \man{gzip}{1}: written so with **c**, read so
     with **t** and **x**, as is any archive named `.tgz` or `.tar.gz`.

**k**
:    With **x**, a file that is there is kept.

**T**
:    With **x**, the files given the archive's times and modes.

**u**, **g**
:    With **c**, the next argument the owner's or the group's number
     in the headers (else 0).

**R**
:    Names from `/` taken out as they are.

**P**
:    The old format: no owners' names, names of 100 characters at most.

**s**
:    Past a header whose checksum is wrong, to the next good one.

# EXAMPLES
```
tar cf src.tar src mkfile
tar tvf src.tar
tar xf src.tar src/lib
tar czf src.tgz src
```

# DIFFERENCES
The archive is POSIX's ustar, as Plan 9's tar writes it, byte for
byte. Its lines of **tv** are what Plan 9's was meant to print (its
modes are missing there). The archive is read and written whole in
memory. Only gzip compresses: Plan 9's also runs `compress` and
`bzip2` for `.tar.Z` and `.tar.bz2`. **i** is taken and does nothing.

# SEE ALSO
\man{gzip}{1}, \man{cp}{1}, \man{walk}{1}; Plan 9's *tar*(1)

# DIAGNOSTICS
A name that cannot be read or made is said and skipped; an archive
that ends too soon, or a bad checksum without **s**, ends it, with
the message as its status.
