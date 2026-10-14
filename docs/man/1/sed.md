\title{sed}{1}{text}

# NAME
sed – the stream editor

# SYNOPSIS
**sed**
[ **-n** ]
[ **-g** ]
[ **-e** *script* ]
[ **-f** *sfile* ]
[ *file* ... ]

# DESCRIPTION
*Sed* reads each line of the *files*, or of the standard input, runs
on it the commands of the script whose addresses choose it, and
writes it. The script is the first argument, or the **-e** scripts and
**-f** files, one after the other.

The commands are Plan 9's, all of them: `p d q = s y a i c n N g G h H
x D P l r w`, `:` labels with `b` and `t`, `{ }`, and `!` after an
address; addresses are numbers, `$` and `/regexp/`, one or two.
*sed*(1) of Plan 9 tells the language.

**-n**
:    A line is written only by `p` and `s///p`.

**-g**
:    Every `s` is `s///g`.

# EXAMPLES
```
sed 's/colour/color/g' notes
sed -n '/BEGIN/,/END/p' file
sed -n '1!G;h;$p'                  the lines last first
```

# SEE ALSO
\man{ed}{1}, \man{grep}{1}, \man{awk}{1}; *sed*(1), *regexp*(6)
