\title{sort}{1}{text}

# NAME
sort – lines in order

# SYNOPSIS
**sort**
[ **-cmubdfginrw** ]
[ **-t** *x* ]
[ **-o** *output* ]
[ \strong{+}\emph{pos1} [ \strong{-}\emph{pos2} ] ] ...
[ **-k** *pos1*[`,`*pos2*] ] ...
[ *file* ... ]

# DESCRIPTION
*Sort* writes the lines of the *files*, or of the standard input, in
order: their bytes', so their characters' in UTF-8, unless keys and
options say another.

A key is \strong{+}\emph{pos1} \strong{-}\emph{pos2}: from field *pos1* to
before field *pos2*, counted from 0 (*f*`.`*c*: *c* characters into the field),
followed by its own letters of those below (`+1n`: the second field as
a number); or POSIX's **-k** *pos1*`,`*pos2*, counted from 1 and
inclusive. The first key decides, then the next; lines the keys do
not part are compared whole. A field ends at blanks, or at the
character of **-t**.

**-n**, **-g**
:    By the number a line (or a key) starts with; **-g**: with an
     exponent.

**-f**, **-d**, **-i**
:    Capitals and small letters the same; only letters, digits and
     blanks counted; only visible ASCII counted.

**-b**, **-w**
:    Blanks at a key's start, or all blanks, not counted.

**-r**
:    The order reversed.

**-u**
:    Of the lines the keys say equal, one.

**-c**
:    Nothing written: the status says whether the input is in order.

**-o** *output*
:    Written to *output*, which may be one of the files.

# EXAMPLES
```
sort -u words
sort -t: +2n /adm/users
du -a | sort -rn | sed 10q
```

# DIFFERENCES
No **-M** (months). **-m**, **-T** *dir* and **-l** are taken and do
nothing: all is sorted in memory, without temporary files, so a file
larger than the memory cannot be sorted.

# SEE ALSO
\man{uniq}{1}, \man{tr}{1}; *sort*(1)
