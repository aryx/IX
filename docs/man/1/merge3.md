\title{merge3}{1}

# NAME
merge3 – two files changed from a common base, merged

# SYNOPSIS
**merge3**
*mine*
*base*
*theirs*

# DESCRIPTION
*Merge3* compares *mine* and *theirs* with *base*, the file both were
changed from, and writes on the standard output *base* with both
sets of changes. Where the two changed the same lines differently,
or lines that touch, it is a conflict, and the three texts are
written:

```
<<<<<<<<<< mine
mine's lines
========== original
base's lines
========== theirs
theirs' lines
>>>>>>>>>>
```

the first and the third marks with the files' names.

# EXAMPLES
```
merge3 mine base theirs > merged
```

# SEE ALSO
\man{diff}{1}, \man{git}{1}

# DIAGNOSTICS
The status is 0 when the merge is clean, 1 when there is a conflict,
2 for a file that cannot be read or is not text.
