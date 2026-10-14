\title{rc}{1}{shell}

# NAME
rc – the shell

# SYNOPSIS
**rc**
[ **-eiIlrvxp** ]
[ **-c** *command* ]
[ **-m** *rcmain* ]
[ *file* [ *arg* ... ] ]

# DESCRIPTION
*Rc* is Plan 9's shell, Tom Duff's: it runs the *file* with its
*args*, the **-c** *command*, or what is typed, with a prompt on a
terminal. Its language is Plan 9's *rc*(1), read the same way: a
variable is a list, `$x(2)`, `$#x`, `a^b`, `` `{cmd} ``, `if not`,
`for`, `while`, `switch`, `~`, `fn`, redirections with their
descriptors (`>[2]`, `>[1=2]`), `<{cmd}`, and the builtins `cd`,
`.`, `eval`, `exec`, `exit`, `flag`, `shift`, `wait`, `whatis`.

```
x=(a b c); echo $x^.c $#x
fn greet { echo hello $1 }; greet you
ls /nothing >[2] /dev/null || echo failed: $status
```

It starts by running `rcmain`, as Plan 9's does: the profile if it
is a login shell, then the command, the file or the terminal.

**-e**
:    A command that fails ends *rc*.

**-x**
:    Each command written before it runs.

**-i**, **-I**
:    Interactive, or not, whatever the input is.

**-l**
:    A login shell: `$home/lib/profile` read first.

**-m** *rcmain*
:    Another `rcmain`.

**-h**
:    The flags and the language, by examples.

# DIFFERENCES
`rfork` and `finit` are taken and do nothing. **-r**, **-v** and
**-p** are set, for `flag` to read, and do nothing else (Plan 9's
**-v** writes the input as it is read, **-p** imports no function).
No **-s**, **-d** nor **-V**. On another system than Plan 9's, the
status a program gives back is a number, made a string.

# SEE ALSO
\man{echo}{1}, \man{test}{1}, \man{xargs}{1}, \man{rio}{1}; Plan 9's
*rc*(1), the language whole, and Duff's paper, "Rc -- The Plan 9
Shell"

# DIAGNOSTICS
`$status` is the last command's: empty for success. *Rc*'s own is
`$status` at its end.
