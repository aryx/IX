\title{netscape}{1}{browsers}

# NAME
netscape – a web browser, in a window

# SYNOPSIS
**netscape** \[ *address* ] \[ *name*`=`*value* ... ]

# DESCRIPTION
*Netscape* is a browser with Netscape Navigator's window (1994): the
buttons Back, Forward and Reload, the Location field, the status bar
under the page. What is under them is an engine of today's kind: the
page fetched (HTTP, and HTTPS by ix's own TLS 1.3), its tree made, its
style sheets cascaded, its boxes laid out, the page drawn; its scripts
run by the engine of \man{node}{1}, on a copy of the tree.

A click in the Location field, an address typed and Enter go to it; a
click on a link follows it. The arrows, Page Up and Page Down, Home,
End, Space and the wheel scroll; Backspace goes back; Control with `+`
or `-`, or with the wheel, zooms the page, and Control with `0` brings
it back to its size: each site's zoom is remembered. Control-Q ends it.

What it is given is a list of *name*`=`*value*:

`url=`*address*
:    The first page: `about:home`, its own, when not said. A file's path is
     an address. The address alone says the same (`netscape
     https://example.com/`): a word with a `:`, a `/` or a `.`.

`scripts=off`
:    The pages' scripts are not run.

`console=on`
:    What the scripts print, and their errors, on the standard error.

`profile=`*dir*
:    Where the cookies, the zooms and the window's size are kept:
     `~/.config/mini-netscape` when not said; `off`, nowhere.

`window=`*w*`x`*h*
:    The window's size at first: the size it had last when not said.

`keep=off`
:    A connection for each request, none kept open.

`settle=off`, `draw=all`, `view=each`
:    The engine's ways of saving time undone, to measure what they save: the
     page laid out again at each of its scripts' changes, each line's shapes
     made before it is shown, the view made again at each frame.

# EXAMPLES
```
netscape url=https://en.wikipedia.org/wiki/OCaml
netscape url=index.html scripts=off profile=off
```

# FILES
`~/.config/mini-netscape`

# SEE ALSO
\man{lynx}{1}, \man{node}{1}, \man{curl}{1}
