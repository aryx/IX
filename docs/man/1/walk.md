\title{walk}{1}

# NAME
walk – what is under a directory, a path a line

# SYNOPSIS
**walk**
[ **-df** ]
[ **-n** *depth* ]
[ *name* ... ]

# DESCRIPTION
*Walk* writes the path of everything under each *name*, a line
each: a directory's entries sorted by name, a directory before what
it holds. A directory named is not written itself; a file named is.
With no *name*, the current directory's, the paths without `./`.

What to keep of the paths is another program's, as what to do with
them: `walk | grep` and `walk -f | xargs`.

**-d**
:    Only the directories.

**-f**
:    Only the files.

**-n** *depth*
:    No deeper than *depth*: with 1, a directory's entries and not
     theirs.

# EXAMPLES
```
walk -f | grep '\.ml$'
walk -f src | xargs wc -l
```

# SEE ALSO
\man{ls}{1}, \man{du}{1}, \man{xargs}{1}

# DIAGNOSTICS
A name that cannot be read is said, the others walked; the status is
then `errors`.

# BUGS
It is 9front's walk written from what it does: not its `-n
min,max`, `-e`, `-t`, `-x`, `-u`.
