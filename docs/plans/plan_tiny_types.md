# Plan: clearer types than string, int and bool in t-IX's signatures

The author (2026-11-06), after two passes over tiny/: "ok we've just
transformed the use of string to a more precise and readable type
(Fpath.t) and same for the (ab)use of int (Exit.t). This is specially
useful in .mli (but then has to be done in the .ml too) to make the
signature of functions more readable. Can you find more opportunities
in tiny/ for such use of clearer types than string and int (and even
maybe bool sometimes). Analyze and report."; then, of the report: "let's
make a plan_tiny_xxx document out of this. This is nice."

Proposed, nothing of it built yet. Status, at the end, says what is
done.

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
