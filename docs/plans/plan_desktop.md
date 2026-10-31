# Plan: a desktop around mini-rio (`windows/rio/`, `windows/desktop/`)

The author (2026-10-31): "let's improve rio and its environment to create
a "desktop". First let's move rio's code from windows/ to windows/rio/.
Then let's make a windows program or script that will run rio and a few
other programs at the right location such as a start button that when
clicked show a menu with the application (see also /progs/) with icons,
settings, etc. like in Windows or other Desktop OS. This might need
modifications to rio to control how to create windows from a script."

**Status: stage 0 done** (rio in `windows/rio/`). Nothing else built. The sizes below are estimates, to be replaced by
`make loc`'s numbers as stages end.

## What it is for

One command, `desktop`, and the machine looks like a desktop of the
1990s: a wallpaper with icons, a bar at the bottom of the screen with a
start button, the open windows and a clock, and a menu of the programs
of `/progs`, each with its icon. It runs under mini-9pi, on mini-qemu
and on the boards.

    +--------------------------------------------------------------+
    | [Files]                                                      |
    | [Term]        +----------------------+                       |
    | [Doom]        | files /usr/pad       |                       |
    |               |                      |   +--------+          |
    | +-----------+ |                      |   | stats  |          |
    | | Apps    > | +----------------------+   +--------+          |
    | | Games   > |                                                |
    | | Net     > |                                                |
    | | Settings  |                                                |
    | | Exit      |                                                |
    | +-----------+                                                |
    | [Start] [files] [stats] [rc 3]                        16:42  |
    +--------------------------------------------------------------+

Four kinds of window: desk, under all the others (the wallpaper and its
icons); rio's windows, as they are today; panel, always on top (the bar);
startmenu, over all of them, and hidden when not wanted.

**The idea to keep: the desktop is ordinary programs in windows of rio.**
The panel, the menu and the wallpaper are not in rio, as the window
manager of X is not in the X server. Rio gets only what they cannot do
from outside: which window is above which, who gets the mouse, and where
a new window goes. So rio stays small and a program that knows nothing of
the desktop runs in it unchanged.

## What rio has, and what it lacks

`wctl` already does most of what a script needs: `new -r x0 y0 x1 y1
command`, `move`, `resize`, `top`, `bottom`, `current`, `hide`, `unhide`,
`delete`, each with `-id n`; `apps/files`'s `Helpers.run` uses it. What is
missing, read from the code:

| Gap | Today | Why the desktop needs it |
|---|---|---|
| A command at start | Rio takes no option (`-i` is rio(1)'s) | Nothing can start the session |
| A wctl outside a window | The file server's attach wants a window's number; `Wm.control` drops a command whose window is gone | The start script has no window, and should not need one |
| The windows' list | No `/dev/wsys`; `-id n` needs a number nobody can list | The panel's task buttons |
| A window ending with its program | It stays, an empty terminal, until deleted | Closing a game must close its window |
| A label for `new` | `rc n`, until the program writes `label` | The task buttons' names |
| Places that do not depend on the screen | `-r` in pixels, and rc has no arithmetic | The boards' screens differ (1280x800 on the Pi 1 and 2) |
| Layers | One list, the front window is the one with the keyboard (`Wm.current`) | A panel on top without taking the keyboard; a wallpaper below |
| Mouse in a window that is not in front | A click brings it to front; only the front window's program reads the mouse (`Rio.main`) | The panel must take clicks and leave the keyboard where it is |
| No border | `Window.width` for all, `Display.screen` insets by 4 | Panel and wallpaper |
| Exit from a program | Only the menu's Exit | The start menu's Exit |
| A directory for `new` | `-cd` refused (its directory is rio's: `Helpers.mli` says so) | Opening a file from the desk |

## Design

### The start of a session

`desktop` is an rc script, `rio -i /lib/desktop/start`, and that second
file is the part the author edits to choose what runs and where, as
Plan 9's `riostart`:

    #!/bin/rc
    window -desk desk
    window -panel -edge bottom 28 panel
    window -popup -hide startmenu
    window -at ne 320 120 stats
    window -at c 640 480 files /usr/pad

`window` is a script of a line or two (`echo new $* > /dev/wctl`), Plan 9's
name. Rio's `-i` runs its command in a process that has the file server's
**root** mounted (attach with an empty name) before `/dev`: a `wctl` that
takes `new`, and `wsys/`. It has no window; what it prints goes to the
console rio was started from.

### What is added to wctl

- `-at nw|n|ne|w|c|e|sw|s|se width height`: a place in the work area (the
  screen less the panels), and `-max`: all of it. A script then does not
  depend on the screen. Rio's numbers stay for those who want them.
- `-desk`, `-panel`, `-popup`: the window's layer, below.
- `-edge top|bottom|left|right size`: a panel along an edge.
- `-label text` (by default the command's first word), `-cd dir` (Plan
  9's), `-hold`: stay after the program ends.
- `exit`, the root's: what the menu's Exit does.

### `/dev/wsys`, the windows' list

As Plan 9's: a directory with one directory per window, each the same files
as `/dev`. The panel lists it and reads each `label` and `wctl`; a button
pressed writes `current` to that window's `wctl`. **Polled once a second to
begin with** (a dozen small 9P requests). If stage 8 shows that to cost on
the Pi 1, a file whose read waits for a change is added then.

### A window that ends with its program

As rio: a window with a command goes away when the last of its files is
closed, which is its program and its children ending. The file server
counts a window's open files at `opened` and `clunk`. An `rc` started by
New stays as it is, since it does not end. `win-wctl`'s recorded screen
(`new ... echo made by wctl`) then changes, and is recorded again.

### Layers

Three kinds of window besides the normal ones, in a second list so that
`Wm.windows`, `Wm.current` and the code on them stay what they are:

| Layer | Place | Keyboard | Mouse | Border | Rio's menu |
|---|---|---|---|---|---|
| desk | below all | no | left and middle its own; the right button stays rio's menu | no | not listed, not pointed at |
| normal | as today | as today | as today | yes | as today |
| panel | above all | no | all its own, no change of front window | no | not listed, not pointed at |
| popup | above panels | no (stage 4) | all its own; **a press anywhere else hides it** | no | not listed, not pointed at |

`Wm.at` looks in popup, panel, normal, desk order. `Wm.front` tops the
panels and popups again after the window it tops. New windows and `-at`
avoid what panels take of the screen. A sweep is left free, as a person
may want a window under the panel. No border is said as Plan 9 says it, by
a window name starting with `noborder`; `Display.screen` today takes that
to mean the whole screen (the kernel's case) and has to tell the two apart.

### Why the start menu is a window

A program in a window can draw only in its window, and the menu is larger
than the button. The choices:

- **Its own window, in the popup layer (chosen).** A real layer of the
  kernel, so a game animating below cannot draw over it. Started hidden at
  the session's start, so the click is a `current` and an `unhide` and not
  the loading of a program from the card. Rio's "a press elsewhere hides
  it" is what makes it feel like a menu, in about three lines.
- Lib_graphics's `Menu.hit` on `Display.whole`, as rio's own menu. No rio
  change, but it draws over what is there and copies it back, so a game
  running below would draw through it and the copy back would be stale;
  and it holds the mouse only while a button is down, not Windows's click,
  move, click.
- The panel growing itself to the menu's size at each click: a new image
  each time, the panel's whole width or two windows anyway.
- The menu in rio: the opposite of the idea above.

### What the programs are written with

Panel, startmenu and desk run all the time, on a Pi 1, so they are on
`lib_graphics` directly, as rio is: they wait on the mouse and a
once-a-second alarm and draw only what changed. `Plan9_loop` runs a frame
loop, which suits a program one is looking at, so **settings** is on
`lib_gui` (it is only there while open, and its toolkit has the fields and
the buttons).

Each is a program of its own, `windows/desktop/` being one directory with
several `executable`s, as `apps/files` has files and open.

### The programs table and `/progs`

`/progs`'s directories hold programs but do not say which draw, what they
are called for a person, their icon or their size; `curl` and `doom` are
both just files. So a table on the card, `/lib/desktop/apps`:

    # group  name          icon     size       command
    apps     Files         folder   640x480    files /usr/pad
    apps     Office        office   800x600    office
    games    Tetris        tetris   360x600    tetris
    games    Doom          doom     max        doom
    devtools Emacs         emacs    800x600    emacs
    net      Netscape      netscape 900x700    netscape
    system   Terminal      term     640x400    rc -i

- **The menu's groups are `/progs`'s directories**, in that order, with a
  person's names: Apps, Games, Internet (net), Developer tools (devtools),
  System, Examples. No new classification to keep.
- **Command-line programs are not in the table** (`ps`, `curl`, and
  `utilities/`). The menu has a "All programs" item, `files /progs`, so
  everything on the card can still be reached.
- **A test holds the table to the Makefile**: each command is in a
  `CARD_*`, and each program of `CARD_system`, `CARD_apps`, `CARD_devtools`,
  `CARD_games` and `CARD_net` is in the table or in the test's short list of
  those left out. A new game then cannot be forgotten.

### Icons

Pictures in text files, `windows/desktop/icons/doom.txt`, a character a pixel
and a palette at the top, 32 by 32 (16 by 16 in the menu, a second file
when the small one needs its own drawing), as `Cursors` holds rio's cursors.
Diffable, needing no decoder in programs that run all the time, and drawn
here rather than taken from anywhere: no licence question.
`apps/files`'s `Icons` are `Playground` shapes, so are not shared: the desk's
icons of files, if it comes to that, go through `files` itself.

### Settings

`$home/lib/desktop/settings`, `key=value`, read by the panel and the desk
when its date changes (the panel's alarm looks), written by `settings`:

- the wallpaper: a colour, or a picture (`lib_graphics/images`'s decoders,
  which only `desk` then links);
- the panel's edge, the clock's 12 or 24 hours;
- mouse: `/dev/mousectl`'s swap and acceleration;
- sound: `/dev/volume`;
- what the machine is: memory, cores, kernel's version, the address (read
  only).

Not a screen mode: the kernel takes it at boot.

### Title bars

Windows-like windows have them, rio's do not, its border is the handle.
**Late (stage 7) and a setting**, since everything else works without them:
the label and close, hide and maximize buttons in a small layer of rio's, on
top of the window and moved with it. The program's image stays what it is,
so no program changes. The window's image cannot hold them: `Display.screen`
gives the program all but 4 pixels of it.

## Stages

Each with what shows it works. Fast checks read text, or run on Linux; the
recorded screens under mini-qemu are run once at each stage's end
(`check-rio`), not during development.

| Stage | What | Size | Shows it works |
|---|---|---:|---|
| 0 | rio in `windows/rio/`, its tests in `windows/rio/tests/` | 0 | **done**: builds by dune and mini-mk; see below |
| 1 | A scripted session: `-i`, the root's `wctl`, `/dev/wsys`, windows ending with their program, `-at`, `-max`, `-label`, `-cd`, `-hold`, `exit`, `window`, `desktop`, `/lib/desktop/start` | rio +150 | A session: `desktop`, three programs at their places, `ls /dev/wsys`, one ends and its window goes. `Wctl.parse` unit tests on Linux |
| 2 | Layers: `-desk`, `-panel`, `-edge`, `-popup`, no border, the mouse's routing, the work area | rio +120 | A small test program in each layer: keys stay in the front window, a game below does not draw over a popup, a press elsewhere hides it, Delete cannot point at the panel |
| 3 | `panel`: start button, a button a window, clock. A press on a window's button: to front; on the front one's: hide (minimize) | 300 | Unit tests of the layout on Linux (a list of windows gives buttons, too many are shortened). A session |
| 4 | `startmenu`, the table, submenus, the icons for what the card has; click, move, click, and a press and drag too. Terminal, Settings, All programs, Exit | 400, and icons | The table's test against the Makefile. A session opens Tetris from the menu, closes it, its button goes |
| 5 | `desk`: wallpaper, a column of icons from `$home/lib/desktop/icons`'s lines (same format as the table), double click | 250 | A session. `files` opened there and a file given to its program: **plan_files never ran that under rio**, so this is its first check |
| 6 | `settings` and what reads them | 300 | The file written, panel and desk changed without restart |
| 7 | Title bars, a setting | rio +100 | Every `win-*` session as it was with the setting off |
| 8 | On the boards, Pi 1 and Pi 2 first, and `mini-qemu -ips 200` before them: what the idle desktop costs (it should be under 1% of the processor), what opening the menu costs (under 100 ms), a game's fps with the desktop against without | | Numbers here, screens compared by `live.py`: an fps claim needs the screens |
| 9 | Later, "at some point": `expose` and the kernel's shrinking draw (below) | 150, kernel +30 | Thumbnails of a covered window and a hidden one, a game's moving; a click brings the right window to front; the time of a redraw on the Pi 1 |

Rio goes from about 1,550 lines to about 1,900, the desktop about 1,250,
plus the icons (which `make loc` should not count as code, to be seen).

## Exposé, later

The author (2026-10-31): "It would be good at some point to have a feature
like Expose from macOS but I don't know if the way draw and rio and 9pi are
written make this possible".

**It is possible, and mini-9pi is unusually well placed for it**, from
reading the code; nothing of this has been tried. All windows shrink to a
grid, live, one is clicked and comes to front. Doing that needs each window's
pixels whether it is covered or not, and Plan 9's memlayer would not give
them: it keeps a window's visible part on the screen and only the hidden
parts apart. **`Memlayer` here is not that**: "each window's pixels all in
its own image: its content is always whole", and the screen is built from
those images. That is already the structure of a compositor, chosen for
simplicity, and it is what macOS's Exposé stood on. So:

| What it needs | Today |
|---|---|
| All of a window's pixels, covered or not | **There**: `Memlayer`, always whole |
| Also of a hidden window | **There**: `Hide` only moves its image's place on the screen, it "draws as before" |
| Another program reaching them | **There**: a window's image is named (`Display.name`), its name in `winname`, which `Display.named` opens |
| Thumbnails above everything, while programs go on | **Stage 2**: a popup window as large as the screen. Programs draw in their own images, under it, and notice nothing |
| The windows' list; bringing one to front | **Stage 1**: `/dev/wsys`, `current` in its `wctl` |
| Drawing an image smaller | **Missing**: `Draw.scale` (draw's `z`, ix's own) only makes larger. Plan 9's draw has no scaling at all |

So **`expose` can be a program**, one more in `windows/desktop/`, with no
change to rio beyond stages 1 and 2:

    for each window in /dev/wsys:  named image, by its winname
    place them in a grid; each: Draw.shrink window into the popup
    the mouse on one: a border; pressed: current, unhide, and hide myself
    every half second or so: the thumbnails again (so they are live)

The only new piece is **`Draw.shrink`**, a draw message `Z` beside `z`:
1/k of a window, for a whole k, with one loop like `Machine.Imag.scale`'s.
A whole k keeps it small and the windows' sizes are then a little approximate,
as the grid does not need exact ones. Each pixel taken as it is (nearest) is
the simple path; text in a thumbnail may then be hard to read, and averaging
k by k is the separate, switchable improvement if it is.

- **Cost, the thing to measure.** At most a screen's worth of pixels a redraw
  in a loop of the kernel: a guess of tens of milliseconds on the Pi 1, not
  measured. If too dear, thumbnails are refreshed one at a time, or once.
- **Without the kernel's message.** `expose` can read a window through `r`
  (`Display.file`, 60,000 bytes a read), shrink it itself and load it: no
  kernel change, but only good for still pictures. A way to try the idea
  first, not the end.
- **Races.** A window deleted or resized while being drawn from: its name
  is gone, the draw is refused. `expose` catches that and takes the list again.
- **How it is started.** A panel button first. A key or a corner of the
  screen would be rio's to watch; later, and only if the button is not enough.
- **Only on `Memlayer`.** `PIXEL=c` (the C pixels, whose `Kdraw.scale` already
  says no) has none of it, as for `z`: a message refused, `can_scale`'s way.
- **Not attempted:** the windows sliding to their places. One cannot
  animate that cheaply on a Pi 1, and the use is in the grid.

The same `shrink` could later draw previews on the panel's task buttons.

## Decisions taken (for the author to undo)

1. **`windows/desktop/` beside `windows/rio/`**, and rio's tests in
   `windows/rio/tests/`.
2. **Layers and popups in rio, everything else in programs.**
3. **Rio's right-button menu stays** on the desk and on normal windows: the
   start menu is added, nothing is taken away. The panel's right button is
   its own.
4. **Windows end with their programs**, as Plan 9's. `-hold` keeps them.
5. **`desktop` is typed, never started at boot**; `rio` alone stays bare rio,
   starting nothing (the author: "no need to start a boot; I actually prefer
   to have to run desktop (or windows) program, also have the ability like
   before to just run rio that does not start anything except rio"). All
   that the desktop adds to rio is asked for by `-i` and by `wctl`'s words, so
   without them it is as before, but for decision 4.
6. **A hand-written table over walking `/progs`**, with a test tying them.
7. **Title bars last, and a setting.** The author's call whether they should
   be on by default, since the request says "like in Windows" and rio's look
   says otherwise.
8. **No tiny twin**: tiny-windows and its programs are left as they are.

Not here: a file manager on the desk (mini-files is that, opened from an
icon), desktop folders that are real directories, drag and drop between
programs, notifications, a keyboard key for the start menu, multiple
workspaces, transparency.

## Stage 0: the move

`git mv` of `windows/*` to `windows/rio/`, so `.ml` and `.mli` are 100%
renames. Changed: `TOP` and the `../lib_` paths of the two mkfiles, the
top `mkfile`'s `DIRS`, `kernels/9pi/Makefile`'s `IXDIRS` and `CARD_*`,
`tests/self.rc`, and the path in comments and docs that said `windows/`
(`done/` plans keep the path of their day).

## Related work (from memory, to check before quoting in a `.mli`)

The desktop metaphor is the Xerox Star's (1981), icons on a surface; the Lisa
and the Macintosh made it common, with the Apple menu and, for the windows
that are open, later the Finder's application menu. NeXTSTEP's Dock (1989)
and CDE's front panel (1993) are panels; **Windows 95's start button and
taskbar** (1995) are the shape asked for here. In X, this is three clients:
window manager, panel and desktop, agreeing through window properties
(EWMH: `_NET_WM_WINDOW_TYPE_DOCK`, `_DESKTOP`, `_NET_WM_STRUT` for the work
area, `_NET_CLIENT_LIST` for the task list); the layers, `-edge` and `wsys`
above are the same four ideas, as `wctl` words and a directory. Plan 9 has
`riostart` and `window` but no panel: `-i` and `window` here are Plan 9's,
the layers are not. More on rio's lineage in
[`notes_rio_related_work.md`](../related-work/notes_rio_related_work.md).
