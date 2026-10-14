\title{date}{1}{time}

# NAME
date – the date and the time

# SYNOPSIS
**date**
[ **-un** ]
[ *seconds* ]

# DESCRIPTION
*Date* writes the time now, or the time *seconds* after the start of
1970, as a line:

```
Thu Jan  1 00:00:00 GMT 1970
```

**-n**
:    The time as its number of seconds since 1970.

**-u**
:    Taken: the time is always Greenwich's.

# EXAMPLES
```
date
date -n
date 2147483647
```

# DIFFERENCES
The time is always GMT's: `/env/timezone` is not read, and **-u**
changes nothing. A *seconds* that is no number is 0. No *clock*.

# SEE ALSO
\man{cal}{1}, \man{timesync}{1}; Plan 9's *date*(1)
