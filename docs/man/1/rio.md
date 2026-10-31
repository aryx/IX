\title{rio}{1}{system}

# NAME
rio – the window system

# SYNOPSIS
**rio** [**-i** *command*]

**window** [*wctl's new flags*] [*command*]

**desktop**

# DESCRIPTION
*Rio* takes the screen, the mouse and the keyboard, and makes them
windows, each with \man{rc}{1} in it. It is a file server: a window's
process has *rio*'s files for that window mounted in `/mnt/wsys` and
bound before `/dev`, so it reads its `cons` and `mouse` and draws in
its window as it would on the whole screen.

Alone, *rio* starts nothing. With **-i**, it runs *command* at its
start, in a process with no window that has a `/dev/wctl` for making
them. *Window* makes one, from there or from inside a window.
*Desktop* is `rio -i` with the windows `$home/lib/desktop/start` asks
for, or else `/lib/desktop/start`.

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
`label`, `snarf`, `text`, `wctl`, `winid`, `winname`, and `wsys`, a
directory with one directory per window, by number, each with that
window's files. `wctl` takes `new`, `resize`, `move`, `top`, `bottom`,
`current`, `hide`, `unhide`, `delete`, `scroll`, `noscroll` and `exit`:
`new` with **-r**, **-hide**, **-label** *word*, **-cd** *dir* and
**-hold** (it stays when its command ends: a window made with a
command otherwise goes then), `resize` and `move` with **-r**,
**-minx**... **-dx**, **-dy** (after a sign, that much more or less),
each with **-id** for another window. All three take **-max**, and
**-at** *where width height*, *where* being `nw`, `n`, `ne`, `w`, `c`,
`e`, `sw`, `s` or `se`: a place whatever the screen's size. A read is
the window's rectangle, then `current` or `notcurrent`, `hidden` or
`visible`, and the layer of one that has a layer.

`new` with **-desk**, **-panel** or **-popup** makes a window of a
layer: a desk below all the others (the whole screen unless placed), a
panel above them, a popup above the panels. These have no border, are
not in the menu, cannot be pointed at, never have the keyboard, and
take the mouse without coming to the front, but for the right button
on a desk, still *rio*'s menu. A press anywhere but in a panel hides
the popups. **-edge** `top`|`bottom`|`left`|`right` *size* places one
along a side; a panel along a whole side takes that much from where
windows go by themselves and from **-at** and **-max**.

# EXAMPLES
```
rio
echo new -r 100 100 500 400 colors > /dev/wctl
echo move -dx +50 > /dev/wctl
window -at ne 320 120 stats
rio -i 'window -at c 640 480 files /usr/pad'
for(w in /dev/wsys/*) cat $w/label
```

# FILES
`/srv/rio.`*pid*, the files posted; `/env/wsys`, its name, in each
window; `/lib/desktop/start`, `$home/lib/desktop/start`, *desktop*'s
windows

# DIFFERENCES
A window's text is not edited: what is typed goes at its end. No
option but **-i** (no **-k**, **-s**, **-f**), and no *label* nor
*wloc* commands: `wctl` and `label` are written instead. `wctl`
takes no **-pid**, and what it cannot do is not said to its writer.
**-at**, **-max**, **-label**, **-hold**, the layers, **-edge** and
`exit` are not Plan 9's;
its *window* takes a rectangle of its own forms, this one `wctl`'s.

# SEE ALSO
\man{rc}{1}, \man{stats}{1}, \man{colors}{1}, \man{page}{1};
Plan 9's *rio*(1) and *rio*(4)
