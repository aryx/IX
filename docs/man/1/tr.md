\title{tr}{1}{text}

# NAME
tr – characters changed for others

# SYNOPSIS
**tr**
[ **-cds** ]
[ *string1* [ *string2* ] ]

# DESCRIPTION
*Tr* copies the standard input to the standard output, each character
of *string1* written as the one at its place in *string2* (the last of
*string2* when it is shorter). Characters are UTF-8's, not bytes. In a
string `a-z` is the characters from `a` to `z`; `\`*ooo* and
`\x`*hhhh* a character by its number; `\`*c* the character *c*.

**-d**
:    The characters of *string1* are taken out.

**-c**
:    *String1* is every character it does not have.

**-s**
:    Of the same character of *string2* several times in a row in the
     output, one.

# EXAMPLES
```
tr A-Z a-z
tr -cs A-Za-z '\012'          a word a line
```

# SEE ALSO
\man{sed}{1}, \man{uniq}{1}; *tr*(1)
