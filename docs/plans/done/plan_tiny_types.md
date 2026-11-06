# Plan: clearer types than string, int and bool in t-IX's signatures

The author (2026-11-06), after two passes over tiny/: "ok we've just
transformed the use of string to a more precise and readable type
(Fpath.t) and same for the (ab)use of int (Exit.t). This is specially
useful in .mli (but then has to be done in the .ml too) to make the
signature of functions more readable. Can you find more opportunities
in tiny/ for such use of clearer types than string and int (and even
maybe bool sometimes). Analyze and report."; then, of the report: "let's
make a plan_tiny_xxx document out of this. This is nice."

Done (2026-11-06): the eight stages and fd, in docs/plans/done/.
Status, at the end, says what each stage did and what was left.
Extended the same day, inside the code rather than the signatures:
"After the plan", at the end.

## The short answer

A signature is where a reader starts (a program's `.mli` is its door,
tiny/README.md), and `int -> int -> int -> unit` says nothing a name
would not say better. Four kinds of change, the cheapest first:

```
   kind                  example                         costs
   an alias              type fd = int                   a line; nothing checked
   an abstract type      type fd  (int inside)           a conversion at each door;
                                                         OCaml checks it on the host
   a variant             Trap_sys | Trap_fault | ...     the conversion where the
                                                         number is read or written
   a record              { is_dir : bool; size : int }   its labels, one name space
```

What comes first: the six mains still returning an int, then
TinyLibSystem's descriptors and processes, then the GUI's boxes, then
the bools that say nothing at the call. The kernel's enumerations and
the many-int functions after, where the conversions cost lines.

## What was done before this plan (2026-11-06)

- Paths: `Fpath.t` in TinyLibSystem's file calls, TinyLibGUI's
  `read_file`/`write_file`, tiny-machine's file options; TinyLibCore's
  `Fpath` and `Fpath_` (`/`, `//`, `!!`), and tiny-ml's operators
  (OCaml's rules) and modules of one level for them. The words a tool
  prints as typed (the shell's, the utilities') stay strings, made a
  path at one door. Code lines: +10 in the programs (tiny-vcs -19).
- Exits: `val main : < caps > -> string array -> Exit.t` in the eleven
  programs on TinyLibSystem.main (TinyLibCore's `Exit`); `Err` for the
  words said after the program's name, `Code` for the rest; the old
  main (main_int) and `TinyLibSystem.argv`, dead by `mini-analyze
  -dead`, removed.

## The constraints

1. **tiny-ml's one name space** for types, constructors and record
   labels, the whole program's (TinyML.mli). A program's own `Code`
   took Exit.Code's place twice (tiny-linker's item, now `Chunk`;
   TinyMLMachine's target, now `Indirect`). So a new constructor is
   named for its type (`Fs_dir`, not `Dir`), and an alias too (`vaddr`
   in the kernel's memory, not an `addr` that the network has again).
   Before each stage: `grep -rnw` the new names over tiny/.
2. **Alias or abstract.** An alias is free, in tiny-ml too, which reads
   abbreviations, and makes the signature readable; OCaml still takes a
   pid for an fd. An abstract type is checked, by OCaml on the host
   (tiny-ml reads a .mli's vals, not its abstraction), and costs a
   conversion where the number is needed. Abstract for TinyLibSystem's
   fd and pid, the seam every tool stands on; aliases elsewhere,
   unless a stage finds a mix-up.
3. **Both systems.** TinyLibSystem has two files (the host's, libml's);
   a type in its .mli is defined in both.
4. **No labels in tiny-ml.** A bool that needs a name at the call
   becomes a variant of two constructors, not `~split:bool`.
5. **The wire and the registers stay numbers.** A variant for IL's
   message kinds, or a trap's cause, is converted where the packet or
   the register is read and written, in one place each.

## The survey (2026-11-06, read)

The 568 signatures of tiny/'s `.mli` files with a string, an int or a
bool (TinyLibCore's left out: they are OCaml's).

### 1. First

**A. The mains still returning an int.** Host-only, on `Cap.main`:
tiny-cpu (`main`, `interpret`), tiny-machine (`main`, `run`),
TinyMachineFetch, TinyMachineSocket, TinyMkfs, Mkfont. The ten's shape.

**B. TinyLibSystem.**

| now | proposed | why |
|---|---|---|
| a descriptor as `int` (39 calls) | `type fd` | `seek : int -> int -> unit`, `dup2 : int -> int -> unit`, `read : int -> int -> string` |
| a process as `int` (10 calls) | `type pid` | `fork`, `kill`, `wait`, `wait_any`, `shell` |
| rc's status as `string` | `type status = string` | `wait`'s; `exec`'s string is another thing, the reason |
| `stat : ... -> bool * int` | `{ is_dir : bool; size : int }` | a pair to remember |
| `time`, `millis`, `sleep : int` | aliases `seconds`, `ms` | the unit is in the comment only |
| `exit : ... -> int -> 'a` | `Exit.t -> 'a` | as main |

**C. A box in TinyLibGUI.** `(int * int * int * int)`, 24 times: `laid`,
`place`, `over`, `mouse`, `key`, `redraw` (its signature past a line),
`inside`, TinyBrowserScreen's `laid_tools`. `type box = int * int * int
* int` (x, y, width, height). TinyKernelGraphics's `rect` is corners,
`{ x0; y0; x1; y1 }`: two conventions, two names, not one merged.

### 2. Kernel numbers that are enumerations

| where | now | proposed |
|---|---|---|
| TinyKernelMachine | a trap's cause, `c_sys`, `c_illegal`, `c_fault`, `c_intr : int` (36 uses) | a variant, made where the trap reads its register |
| TinyKernelFS | a file's type 1 (directory) or 2 (file), `fs_kind`, `fs_create` (21 uses) | a variant |
| TinyKernelFS | `fs_lookup`'s 0 for none | `int option` |
| TinyKernelFS | `fs_* : int -> int -> ...`, a tree's number then an inode's | aliases `tree`, `inode` |
| TinyKernelFS | `fs_io`'s command 1 or 2 | a variant, to memory or to the disk |
| TinyKernelNetwork | IL's kinds (`il_sync`, `il_data`, `il_ack`...; 65 uses), ICMP's ask and answer | variants |
| TinyKernelNetwork | `il_message : int -> int -> int -> int -> int -> string -> string`, `il_read`'s 6-tuple | a record, the header (kind, ports, id, ack) |
| TinyKernelNetwork | an IP address, 4 bytes as a `string` | an alias |
| TinyKernelMemory | `mem_*`'s addresses | an alias (`vaddr`) |
| TinyKernelProcs | `ended : (int * int * int) list` (pid, parent, status) | a record |

### 3. Bools that say nothing at the call

| function | the bool | instead |
|---|---|---|
| `TinyLinker.link : bool -> ...` | text and data split (-n) | `Joined \| Split` |
| `TinyCTree.assign : bool -> expr -> expr -> expr` | (to read) | a variant |
| `TinyMLCompile.bind : ... -> bool -> ...` | recursive | `Rec \| Nonrec` (names to check) |
| `TinyBrowserTokens.tokens : reader -> string -> bool -> ...` | the last message | `Last \| More` |
| `TinyBrowserLines.word : flow -> string -> int -> string -> bool -> unit` | a space before | a variant; two strings and an int around it too |
| `TinyAppTemperature.number : string -> int * bool` | whether it is a number | `int option` |
| `TinyKernelMemory.mem_load : ... -> bool` | the text to write | a variant |
| `TinyLibGUI.write_file : ... -> bool` | all written | as it is, or a result |

Clear already, kept: `set_executable`'s bool, setters (`focus`,
`hover`), predicates (`is_dir`, `readable`).

### 4. Ints in a row

| function | now | idea |
|---|---|---|
| `TinyLibDraw.d_draw` | 9 ints (dst, src, mask, x0, y0, x1, y1, px, py) | the kernel's rect and a point |
| `TinyLibDraw.d_image`, `d_fill`, `d_line` | 6 ints | the same |
| `TinyKernelAudio.mix` | 8 ints (ring, size, at, wave, hz, to_hz, volume, length) | a record, the wave a variant (0 to 3) |
| `TinyLinker.aout` | `int -> int -> string -> string` (memory, data_at) | aliases at least |
| `TinyEditorScreen.create` | `int -> int -> string -> string` (cols, rows, the name shown, the text) | the worst: name and text swap silently; a record, or the text a type |
| `TinyEditorScreen.key`, `TinyLibGUI.key` | a key, a byte as `int` (arrows 128 to 131) | `type key = int` |
| TinyLibPlayground (`bold`, `italic`...), TinyBrowserLines (`bold`, `emph`...) | a style, bits in an `int` | `type style = int` |
| TinyBrowserScreen (`c_white`...), `TinyLibDraw.d_colour` | a colour as `int` | `type colour = int` |

### 5. Strings that are one kind of text

- A URL: TinyBrowserAddress (`resolve : string -> string -> string ->
  string`), TinyBrowserHttp, TinyMachinePeer's `www_*`: `type url =
  string`.
- A symbol: TinyMLMachine (`block : string -> string -> dword list ->
  unit`, `entry`, `closure_sym`...), tiny-c's `sym`, `globl`: `type sym
  = string`.
- TinyLibSymbols: `labels : string -> (string * int) array`, a label and
  its address: aliases.

## Decisions (proposed, for the author)

1. Abstract `fd` and `pid` in TinyLibSystem; aliases elsewhere, a stage
   making one abstract when it finds a mix-up.
2. Each new name grepped over tiny/ first (constraint 1); a type's
   prefix when it is common (`Fs_dir`, `Trap_sys`).
3. A stage is a commit: its types in the .mli and the .ml (the
   author: "especially useful in .mli, but then has to be done in the
   .ml too"), its code lines counted before and after
   (scripts/stats/loc.py's counter), as the Fpath pass was.
4. Nothing printed changes: the messages and statuses compared with
   the commit before, as the Exit pass was (12 cases).

## The stages (each checked before the next)

1. The six mains on Exit.t (1A).
2. TinyLibSystem: `fd`, `pid`, `status`, the stat record, `exit` on
   Exit.t, the time's aliases (1B); both systems.
3. TinyLibGUI's box (1C), TinyBrowserScreen with it.
4. The bools of section 3, and `TinyEditorScreen.create`.
5. The kernel: the trap's cause, the FS's kind, inode and tree, the
   lookup's option (section 2, its first half).
6. The network's kinds and IL's header record; the memory's `vaddr`;
   `ended`'s record.
7. The draw protocol and the mixer (section 4); the style, colour and
   key aliases.
8. The string aliases (section 5).

Checks at each: `make test-tix` (34 jobs, a minute); `make
self-quick-tix` when tiny-ml, the toolchain, the kernel or TinyLibCore
change (6 minutes); `mini-analyze -dead` on tiny/
(analyzers/datalog/tests/tiny_check.sh -dead) for what a stage left
unused; `bugs_tiny.txt` recorded again when only its lines moved.

## What it costs, roughly

The passes before: +10 code lines in the programs for Fpath (tiny-vcs
-19), about as many for Exit. An alias is a line; a variant a few,
and its conversions where the number is read or written; a record its
type and its labels. Stages 1 to 4 small and local; 5 to 7 more,
where the kernel and the draw protocol meet numbers.

## Open questions

- An abstract `fd` on tiny-kernel: libml's is a number for the
  kernel's calls; `type fd = int` there, abstract only in the .mli,
  as `Fpath.t` is a string in TinyLibCore's .ml?
- `TinyCTree.assign`'s bool: what it says, to read before naming it.
- The style bits: an int with names, or a record of bools (bold,
  italic...)? The messages to the kernel carry the int.
- The host-only programs past tiny-machine (TinyMachineSocket's fifos,
  sdl/TinyCalls) call `Sys` and `Unix` bare: capabilities first
  (caps-for-every-access), the types with them.

## Status

2026-11-06: proposed; the survey above.

2026-11-06, stage 1 built (the author: "let's start"): the six
host-only mains on Exit.t, and on TinyLibSystem.main, which says
Err's words after the program's name as the others' (lib_core's
Exit.exit logs them instead): tiny-cpu, tiny-machine, tiny-mkfs,
Mkfont, tiny-machine-fetch, tiny-machine-socket. tiny-cpu's
`interpret` and tiny-machine's `run` keep an int, the image's exit
and the kernel's halt code, numbers the guest gives; main makes
them OK or Code. tiny-machine-fetch says its failures on the
standard output, the kernel's answer, so Code 1, not Err. Their
dune stanzas, tiny/mkfile (tiny-cpu, tiny-machine, tiny-mkfs) and
tiny_check.sh's lists take TinyLibSystem. The same messages and
statuses as before in 15 cases (usage, a missing file, a bad image
or font); +2 code lines over the six.

2026-11-06, stage 2 built, without fd (the author: "maybe fd should be
postpone, given we now use in_channel (and Chan.i) a bit more?", then
"ok let's postpone and do the orthogonal one like pid, rc's status,
etc., as planned"): fd waits for the Chan work, which takes the
files read whole (tiny-build's digest, cat, cmp); what stays a
descriptor is the shell's plumbing (dup2, save, pipe, redirections)
and tiny-db's file read and written at offsets, where `type fd` is
then worth it; tiny-kernel's in_channel is the descriptor itself, a
third name for one number. Built: TinyLibSystem's `pid`, `status`
(rc's), `stat` (`st_dir`, `st_size`: Unix's prefix, the labels one
name space in tiny-ml), `seconds` and `milliseconds`, in both
systems. pid an alias, not abstract: mini-ml reads no `private`, and
an abstract pid would need a conversion at each print. `fork` and
`shell` give a `pid option` (old: an int for three answers, -1 when
tiny-kernel's processes are all taken, 0 in the child; fork's
failure now a Failure, which the shell's fork makes its own Error
again, the one its children's handler takes); `exit` takes an Exit.t
(Err's words said first: Cap.stderr). +36 code lines over seven
files.

2026-11-06, stage 3 built (the author: "let's move forward"):
TinyLibGUI's `box` (x, y, width, height) and `'msg boxes`, the boxes
with their actions, which the comments already called so ([mouse g
boxes model ...]): `laid`, `place`, `over`, `mouse`, `key`, `redraw`,
`inside` and the repaint's `Same`; TinyBrowserScreen's `laid_tools`
and TinyDebugger's model on them. TinyOffice's strokes and
TinyWindows' sweeps are two corners, not a box: left. -5 code lines
(the .mli's shorter; the .ml +2, its two types).

2026-11-06, stage 4 built (the author: "let's commit and move
forward"): the bools that said nothing at the call, each a variant
named for what it chooses, or two functions:
- tiny-linker's `link`: `sections`, `In_order | Text_first` (-n);
- tiny-c's assignment: `Asg_set | Asg_update`, in `assign` and the
  tree's `Asg` (x op= y's new value reads the old one: the address
  kept for it, Dup);
- tiny-ml's let: `rec_flag`, `Nonrecursive | Recursive` (OCaml's
  names), in the tree's `Let` and `ILet` and `bind` (16 places);
- the browser's tokenizer: `tokens reader message` and `tokens_end
  reader`, the old bool (the last message) left inside, `scan`;
- the temperature converter's `number`: `int option`, not the number
  and whether it was one;
- the kernel's `mem_load`: `text_state`, `Text_new | Text_shared` (a
  copy that runs has it, segments), which the exec makes an offset.
`TinyEditorScreen.create` and `TinyOffice.create` take the file as
an Fpath.t, so that its name and its text, two strings, cannot be
given one for the other (the name kept as text inside, for the
messages and the editor's colours). Left: `TinyBrowserLines.word`'s
bool is a word's own data (a `Word` the HTML reader made: whether a
space comes before), not a mode; the word as a record goes with
stage 7. dead_tiny.txt recorded again (the tokenizer's dead in the
host programs, which link it unused, under its new names). +22 code
lines.

2026-11-06, stage 5 built (the author: "let's commit and move
forward"): the kernel's numbers that were enumerations, a variant
each where they enter the kernel, the number kept where it is the
machine's or the disk's:
- a trap's cause: TinyKernelMachine's `cause` (`Trap_sys`,
  `Trap_illegal`, `Trap_fault`, `Trap_intr`), `cause_of` where
  k_run, k_step or a core's mailbox gives it; the scheduler's
  `trapped` a match (old: c_sys... compared in an if chain);
  `cause_code` for the one message that says the number ("trap 3
  at ..."), the same output; tiny-machine's side (TinyMachineDevices)
  keeps the numbers, its registers';
- the FS: `tree` and `inode` aliases in its signatures, `file_kind`
  (`Fs_dir | Fs_file`) in `fs_kind` and `fs_create` (1 and 2 kept on
  the disk and in the entries the kernel gives ls), `fs_lookup` an
  `inode option` (old: 0 for none), `fs_io`'s command a `disk_io`
  (`Disk_read | Disk_write`), made the device's 1 or 2 where the
  kernel pokes it. +33 code lines (8 of them the FS's tests).

2026-11-06, stage 6 built (the author: "excellent! Let's commit and
move forward"):
- the network: IL's seven kinds a variant, `il_kind` (`Il_sync` ...
  `Il_close`), Plan 9's numbers only on the wire (`il_code`,
  `il_kinds`: an array by Array.of_list, tiny-ml reading no [| |]);
  IL's header a record, `il_header` (`ih_kind`, `ih_sport`,
  `ih_dport`, `ih_id`, `ih_ack`), which `il_message` takes and
  `il_read` gives with the message (old: five ints, and a 6-tuple
  back); ICMP's kinds `Echo_ask | Echo_answer | Icmp_other of int`
  (the peer's trace says another's number); tiny-machine's peer and
  the network's test on them;
- the memory: `vaddr` and `kaddr`, the process's address and the
  kernel's, in TinyKernelMemory's signatures; `mem_address`'s -1
  kept, not an option: it is asked at each read and write, and an
  option allocates (the comment above sys_rw: an allocation a call
  once slowed the kernel enough to reorder a test's lines);
- the processes: `ended` a list of `ending` records (`end_parent`,
  `end_pid`, `end_status`; old: a triple).
+35 code lines (24 the network's: its types, the numbers' two ways,
the headers written whole).

2026-11-06, stage 7 built (the author: "excellent, let's commit and
move forward"):
- the draw protocol: TinyLibDraw's `image` (an image's number, a
  colour one too), `pixel` (a colour's byte), `rect` (two corners),
  `point`, `style`, and `cursor` (`Cursor_arrow | Cursor_hand`, 0 and
  1 on the wire); `d_draw : image -> image -> image -> rect -> point
  -> string` (old: nine ints), `d_fill`, `d_line`, `d_text`,
  `d_styled`, `d_pixels`, `d_image` on them; the calls, which
  computed two corners each time, give them as a tuple; TinyWindows'
  rectangles were these tuples already; the messages' bytes the same
  (the recorded screens unchanged); the graphics test's own wrappers
  keep its flat numbers;
- the kernel's mixer: `wave` (`Square | Triangle | Sawtooth | Noise`,
  TinyLibPlayground's names) and a `tone` record (`t_wave`, `t_hz`,
  `t_to_hz`, `t_samples`, `t_volume`), which `Tone` carries and `mix`
  takes after the ring's three numbers (old: eight ints, the wave's
  number compared in an if chain, now a match);
- a key: TinyLibPlayground's `key`, in its game, TinyLibGUI's `key`
  and canvas, and TinyEditorScreen's `key` and `pending`;
- the browser's `look`, a run's bits, in TinyBrowserLines.
Left: TinyLibPlayground's `bold`, `italic`... are not TinyLibDraw's
style bits but the style shifted above a colour's byte, a colour with
its style, kept ints; `TinyBrowserLines.word`'s bool (a space before
the word) is the HTML reader's data, carried by its `Word` items: a
record for the word would change the reader for one bool, not done;
`TinyLinker.aout`'s two ints (the memory, where the data starts)
left. +35 code lines (8 the tests', 12 TinyLibDraw's types).

2026-11-06, stage 8 built (the author: "le's commit and move
forward"), the strings' kinds, aliases each: TinyBrowserAddress's
`url` (in its functions, TinyBrowserHttp's `request` and `asked`,
tiny-machine's peer's `www_`); TinyKernelNetwork's `ip_addr` (four
bytes in a string, stage 6's left: `net_machine`, `ip_packet`,
`ip_read`, the connections' and the stack's fields, the peer's
`net_dotted`); TinyMLMachine's `sym`, an assembly's label (the
targets, `DCode` and `DVal`, `block`, `entry`, `closure_sym`...);
tiny-c's `sym`; TinyLibSymbols's `label` and `symbols`, a program's
labels with their addresses. +6 code lines.

The plan done but for fd (stage 2), postponed until the Chan work has
taken the files read and written whole; then the shell's plumbing
and tiny-db's file are what a `type fd` would name. In all, the
eight stages: +164 code lines (stage 3 -5, the others +2 to +36),
for signatures that say what their ints, strings and bools are.

2026-11-06, fd, after the Chan work (the author: "let's do the
renaming fd if needed, unless Chan or in_channel would be better types
where it's currently used", then "let's commit part a and move
forward"): part A, TinyLibSystem's descriptor calls on `type fd` (an
alias, as pid), the shell's redirection target and tiny-db's file
record on it (3f19609b). Part B, a channel where it says more than a
descriptor: the utilities' inputs (cat, wc, grep, sort, tail, xd, ps,
by `each_input`, the standard input `TinyLibSystem.stdin`), `cmp`,
tiny-build's digest (a piece at a time: a file need not fit in the
heap) and tiny-vcs's append to its store (`with_open_append`, closed
before head is written). For them `In_channel.input`, OCaml 4.14's,
in TinyLibCore and in lib_core's In_channel (mini-ml's, which
mini-analyze reads ix by too). `with_open_*`'s Failure names the file
on both systems ("f: cannot open" on tiny-kernel, where it said only
"cannot open": tiny-assembler, tiny-c, tiny-ml now say which file
there too), as the host's Sys_error did. Left on descriptors: the
shell's plumbing, tiny-db's file at offsets, `tee` (several files
written as the input comes), `cp` (each_path says a failure after
the source's name, where a channel's open would say its own file
again). The messages the same in 17 cases, but cmp's missing file,
now named ("cmp: nofile: ...").

Done, 2026-11-06 (the author: "let's close the plan"): the eight
stages and fd built, the plan moved to docs/plans/done/. Left, each
on purpose and said in its stage: TinyLibPlayground's styles (a
colour's byte with its style above it, kept ints); TinyBrowserLines'
word's bool (the HTML reader's data, a record for one bool not done);
TinyLinker.aout's two ints; tee and cp on descriptors; mem_address's
-1 (an option would allocate at each read and write). Tiny-machine's
-net directory, left a string here, became an Fpath.t later
(b9dbcc88), once its Sys calls went by CapSys. Learnt on the way: tiny-ml's one
name space for constructors and labels makes a new type's names carry
its prefix (Trap_, Fs_, Il_, ih_, end_, st_), and a common one (Code)
was taken twice by a program's own; mini-ml reads no `private`, so the
numbers' types are aliases, readable but not checked.

## After the plan: inside the code (2026-11-06)

The plan typed what a signature says. The author then went on in the
code, from their own edit of TinyAppCalculator.ml: "we should
leverage the type system when we can and when it arguably leads to
clearer code"; a magic value said by a comment ("' ' = None") is the
case to look for.

- The calculator (47fc24d1, 958ce4b0): the model's op a char option,
  result an int option (old: an int and a bool saying whether there
  is one). An `operation` variant for the four was left: "it's fine
  to not use the variant for now for this toy example; for a more
  complex program we should".
- The keys (386502e1, c1044a69, 9411d9d8): TinyLibPlayground.key, an
  int (the console's byte, the arrows 128 to 131), is
  `Char of char | Ctrl of char | Enter | Backspace | Escape | Up |
  Down | Left | Right`; key_of_byte, where a loop reads the console,
  the one place that knows the bytes. m-ix's Playground keyboard
  (held keys as bools, the browser's names as strings) was looked at
  and not taken: tiny-machine sends no key-up, and the programs want
  each key in order. Plan 9's runes, its arrows in the private use
  area, left for later ("we can always revisit later"). The editor's
  and the office's commands read as Emacs's (`Some (Ctrl 'x'), Ctrl
  's'`); five last arms `Char _` became `_`, the compiler refusing
  them once Ctrl came. Names this common (Char, Up, Left) may meet a
  program's own in tiny-ml's one name space: none does today.

### The sentinels: a survey

About 50 documented -1, 0 or "" meaning none in tiny/, in three
kinds:

- A, a program's state, an option or a variant reads better: the
  office's `sel` (43 uses) and `hit`; TinyLibGUI's menu_state
  (`opened`, `item`, -1 none each); the browser's nav (`nv_goal` or
  -1, `nv_goal_id` "" for none, `nv_fetch` -1 for the page, a variant
  Page | Picture, `nv_wire` -1 when the page is all there, an fd
  option); TinyLibPlayground's `speaker` and TinyDebugger's `t` and
  `pc` (-1: running).
- B, a function's "where, or -1": TinyEditorScreen.find,
  TinyBrowserText.find and its entities, TinyBrowserTokens' tag,
  TinyBrowserHttp's; an int option as OCaml's index_from_opt, after
  a timing where they run at each character (an option allocates).
  TinyLibRegex's groups (-1 unmatched, an array as Str's) kept.
- C, the machine's and the system calls' formats, kept: the calls'
  -1 (Plan 9's), the devices' registers (0: off), the disk's 0 hole,
  the draw messages' -1 no mask, the kernel's addresses (0: not
  made), as mem_address's -1 was. Between: TinyKernelProcs' `parent`
  (0), its ended count and `core` (-1; the scheduler reads `core` at
  each switch, a timing first), TinyKernelFiles' trace's three -1
  (cold: an option each).

The order: sel, the GUI's menu, the browser's nav, the debugger and
the speaker, then B and the kernel's trace. A commit each.

- sel: TinyOfficeModel's `sel` an int option and `hit` one too (they
  are compared: the click is on the box edited, `on_it`). Inside an
  edit a box is selected, so `selected` and `selected_box` give it
  (Invalid_argument when none: an editing without its box is a bug),
  for the parts' 13 `List.nth o.page o.sel`. A click's or a right
  button's box a match. +18 lines.

- The GUI's menu: TinyLibGUI.menu_state's `opened` and `item` int
  options (old: -1 none each), and `title_at` and `item_at`, which
  find them, too; menu_mouse a match on the menu open, the title and
  the item under the mouse, in the old order of its four cases;
  menu_view's open menu a match. The office and the browser use it;
  the browser's two tests of `opened` against -1 now against None.
- The browser's nav: `nv_wire` and `nv_fetch`, which changed together
  (a descriptor, -1 when the page is all there; the picture it
  brings, -1 for the page), one variant, `Wire_off | Wire_page of fd
  | Wire_picture of fd * id`; `hang_up` closes it (written twice
  before); the loop a match on it, the keys and the mouse its last
  arms. `nv_goal` an int option, `nv_goal_id` a string option, and
  TinyBrowserAddress.fragment, which makes it, gives one (old: "" for
  none). Seen on the way and left for later: a picture's `pc_got`
  (rows got, -1 not asked, -2 failed, -3 asked: a state, a variant),
  the document's `dc_file` (-1 none), next_picture's -1 for no
  picture; u_dial's -1 is the system call's (kept, C).
- A picture's `pc_got` (rows got, -1 not asked, -3 asked, -2 none to
  be had): `Pic_unasked | Pic_asked | Pic_failed | Pic_rows of int`.
  picture_message a match on it (the answer's first line when asked,
  a row while rows come); draw_slice's rows got from it, 0 before.
  +8 lines.
- The browser's last: the document's `dc_file` an int option (None
  before a helper's file is open, or when it could not be: body_end
  says so); next_picture's on_screen and first int options (old: -1
  for none). Seen and left: TinyBrowserLines.run's `pic` (-1: not a
  picture's slice) and `link` ("" none), in every run of a page;
  `dc_type` ("" until the head has come) and `dc_status` (0 when no
  head said). +7 lines.
- The debugger's `pc` an int option ref, where the process is stopped
  (old: -1 running): `over` takes it, `n` giving it, backtrace and
  panes a match. Its `t`, the trace's descriptor, kept: -1 only until
  u_trace at start, which ends the program when it fails, then always
  one. TinyLibPlayground's `speaker` an int option (u_open's -1 made
  None where it returns).
- The kernel's trace: TinyKernelFiles.trace's `call` (the call a
  process is stopped before), `ret` (the call whose end it waits for)
  and `over` (the breakpoint whose word it runs) int options (old: -1
  none each); the scheduler's run matches `Some { call = Some n; _ }`,
  waited `Some ({ ret = Some n; _ } as t)`. Only a traced process
  reaches them. +2 lines.
- B, the "where, or -1" functions, int options: TinyBrowserText.find
  (its callers in the HTTP head, the hidden styles, the site and the
  tokens), the entities (a table and List.assoc_opt, old: a match of
  30 cases and -1), entity_code, TinyBrowserTokens.tag_end,
  TinyBrowserHttp.head_end (a match of the two ends' four cases), and
  TinyEditorScreen.find (search, replace-string). No timing: the
  option is made once, at the function's return, not in its loop over
  the characters (mem_address's was at each access). -5 lines. Seen
  and left: TinyWindows' item under the mouse (-1), TinyEditorScreen's
  cursor `cut` in a line's pieces (-1), TinyLibDraw's message reader
  (-1 when no message: the protocol's, C).
- The browser's run: TinyBrowserLines.run's `pic`, three meanings in
  an int (-1 text, -2 the bottom half of a large heading's line, the
  picture's number times 256 plus the slice), a variant `part`:
  `Run_text | Run_lower | Run_slice of int * int`; draw_line a match
  on it, next_picture a filter_map of the slices' pictures not yet
  asked. Its `link` a string option (old: "" none), and so the
  element's `href` it comes from and the table's items. No timing:
  Run_text and Run_lower are constants, a slice's pair is made once a
  picture's row of lines, and a link's Some once an <a>, shared by its
  runs. The run's copies `{ r with ... }`, one field a line. +23
  lines, most the record and the type a field a line in the .ml and
  .mli. Left: `dc_type` ("" until the head has come) and `dc_status`
  (0 when no head said).
- The document's `dc_type` a string option (old: "" until the head
  has come) and `dc_status` an int option (old: 0 when no head said),
  from TinyBrowserHttp.status, now an int option (None when the first
  line is not HTTP's; the test's host prints it 0 as before). take a
  match on dc_type; body_start returns the media type it sets, and
  body is given it, so neither reads the field after the head. +8
  lines. Seen and left: the screen's `sc_state`, a string that is
  "reading", "done", or why there is no page (a variant).
- The screen's `sc_state`, a string that was "reading", "done", or
  why there is no page: `Page_reading | Page_done | Page_none of
  string` (Page_, as TinyCalls, which the browser opens, has a
  Reading); draw_status a match on it. +14 lines, most the type, a
  case a line, in the .ml and the .mli. The survey's browser items
  are all done.
- TinyWindows' menu: its items a variant, `Item_new | Item_move |
  Item_delete | Item_exit` (old: their places, 0 to 3, matched as
  numbers, `item = 3` the exit; Item_, as lib_core has an Exit and
  TinyDatabase a Delete), the list of items each with its name; the
  item under the mouse an item option (old: -1 none), from
  List.nth_opt. The release a match: exit, chosen, or nothing. +15
  lines, most the type a case a line. Checked by tiny-kernel's
  sessions, which open the menu and choose New (their screens).
