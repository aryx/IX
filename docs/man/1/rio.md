\title{rio}{1}{system}

# NAME
rio – the window system

# SYNOPSIS
**rio**

# DESCRIPTION
*Rio* takes the screen, the mouse and the keyboard, and makes them
windows, each with \man{rc}{1} in it. It is a file server: a window's
process has *rio*'s files for that window mounted in `/mnt/wsys` and
bound before `/dev`, so it reads its `cons` and `mouse` and draws in
its window as it would on the whole screen.

The right button's menu: **New** (a rectangle swept with that button:
a window), **Resize** (a window pointed at, then its new rectangle),
**Move** (a window dragged), **Delete**, **Hide** (the window is then
a name in the menu, which brings it back), and **Exit**. The left
button on a window gives it the keyboard; Delete, or Control-C, typed
in it interrupts its processes. A window's border is a handle: the
left or middle button there pulls that side or corner, the right one
moves the window.

In a window, the scroll bar and the arrows scroll its text, the left
button selects, and the middle button's menu has **snarf**,
**paste**, **send**, and **scroll** or **noscroll** (a full window
then holds what its program writes until it is scrolled).

A window's files: `cons`, `consctl`, `mouse`, `cursor`, `kbd`,
`label`, `snarf`, `text`, `wctl`, `winid`, `winname`. `wctl` takes
`new`, `resize`, `move`, `top`, `bottom`, `current`, `hide`,
`unhide`, `delete`, `scroll` and `noscroll`: `new` with **-r** and
**-hide**, `resize` and `move` with **-r**, **-minx**... **-dx**,
**-dy** (after a sign, that much more or less), each with **-id**
for another window. A read is the window's rectangle, then
`current` or `notcurrent`, `hidden` or `visible`.

# EXAMPLES
```
rio
echo new -r 100 100 500 400 colors > /dev/wctl
echo move -dx +50 > /dev/wctl
```

# FILES
`/srv/rio.`*pid*, the files posted; `/env/wsys`, its name, in each
window

# DIFFERENCES
A window's text is not edited: what is typed goes at its end. No
option (**-i**, **-k**, **-s**, **-f**), and no *label*, *window* nor
*wloc* commands: `wctl` and `label` are written instead. `wctl`
takes no **-cd** nor **-pid**, and what it cannot do is not said to
its writer.

# SEE ALSO
\man{rc}{1}, \man{stats}{1}, \man{colors}{1}, \man{page}{1};
Plan 9's *rio*(1) and *rio*(4)
