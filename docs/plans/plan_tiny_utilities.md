# Plan: tiny-utils, the small programs of a system (cat, ls, wc...) in one file, on the host and on tiny-kernel

The author (2026-10-15): "What could be a TinyUtilities.ml? the
equivalent of m-ix utilities/, but tiny"; then, of the answer (one
executable with a name per utility, filters and walkers): "write the
plan and start".

**Step 1 done (2026-10-15)**: tiny-utils on the host, 14 utilities in
373 lines (268 of code), the same output and status as the twins in
the 64 cases of `tiny/tests/TinyUtilities_test.sh`. Section 7 says what
was found.

**Step 2 done (2026-10-15)**: cp, mv, touch, test (and `[`), pwd and
sleep; 20 utilities in 485 lines (353 of code), the same as the twins
in 109 cases.

## 1. What it is

m-ix's `utilities/` has about 40 programs in 10 directories (3,600
lines), each one a faithful copy of Plan 9's program of the same name,
with its options and its quirks. Each file repeats the same frame: read
the options, open each file or read the standard input, report a file
that cannot be opened, compute, print, return a status.

`tiny/TinyUtilities.ml` keeps what these programs are about and drops
the compatibility. Once the options are gone, most of each program is
the frame, and the frame can be written once:

- **One executable, many names.** `tiny-utils wc f` runs wc, and so
  does a link named `wc` (BusyBox's trick, 1995). The utilities are
  rows of one table: a name, a usage line, a function from the
  arguments to the exit status.
- **Most utilities are filters**: a function over a stream of bytes
  that arrives in pieces. cat prints each piece; wc counts the lines,
  words and bytes, carrying "inside a word" from one piece to the next;
  xd carries the bytes of an unfinished line; tee writes each piece to
  several places. Opening the files, falling back to the standard
  input, and reporting a file that cannot be opened is one function,
  `each_input`, shared by all of them. The pieces are printed as they
  come, so cat at the console or in a pipe of tiny-kernel (whose pipes
  hold 512 bytes) does not wait for the end of its input.
- **The others walk a file tree**, and they are all one fold: `fold
  path f` calls `f` with the path, whether it is a directory, its size,
  and a function that folds the entries when called. Calling that
  function before printing gives walk (pre-order); calling it first and
  summing the results gives du (post-order); calling it first and then
  removing the path gives `rm -r`. ls is the fold stopped at depth 1.
- **The same file on both systems**, as `TinyShell.ml` already is: it
  names only `TinyLibSystem` and the standard library's pure functions,
  so dune builds it for the host, and tiny-ml builds it for tiny-kernel
  with `TinyLibStd.ml` and the kernel's `TinyLibSystem.ml`. tiny-kernel
  then has one set of tools, tested on the host first, in place of the
  six small C programs of `TinyKernel/user/`.

What is dropped: most options (each utility keeps the one or two that
carry its idea: `wc -lwc`, `tail -n`, `rm -r`, `mkdir -p`, `du -a`,
`xd -b -c`, `cmp -s`), UTF-8 (wc counts bytes, not characters), floating
point in seq, the formats of `ls -l` (tiny-kernel has no owners, modes
or times), `namespace/` (tiny-kernel has no bind or mount), `process/`
until the kernel can list its processes, and `calc/` (that is
`TinyAppCalculator`). Error messages are uniform, "tool: file:
reason", instead of each program's own wording.

What is kept from the twins is their output, where it costs nothing:
wc's columns of 7, xd's lines, du's kilobytes and tab, cmp's two
messages, ls's sorted names. That makes the twins the test.

## 2. The utilities

| family | utilities | twin |
|---|---|---|
| filters | cat, wc, tail, tee, xd | `utilities/files`, `misc`, `pipe`, `byte` |
| walkers | ls, walk, du, rm, mkdir | `utilities/files`, `misc` |
| the rest, a few lines each | echo, seq, basename, cmp | `utilities/misc`, `compare` |
| later (step 2) | cp, mv, touch, test, pwd, sleep | `utilities/files`, `misc`, `process` |

cmp is not a fold: it reads its two files whole, which is the simplest
way to walk two streams at once.

## 3. What TinyLibSystem must add

`TinyLibSystem.mli` is the interface both systems give. Today it has
what tiny-shell needs; the utilities need five more functions:

- `read fd max`: up to `max` bytes, `""` at the end (for the filters,
  which must not wait for the end of their input).
- `write fd s`: for tee's files.
- `stat file`: whether it is a directory, and its size; `Failure` with
  the reason when it is not there.
- `mkdir caps dir` and `remove caps file` (a file, or an empty
  directory).

On the host these are Unix's calls. On tiny-kernel, `read` and `write`
are `u_read` and `u_write`, `stat` reads the file's entry in its
directory (the size is already there, in user.h's `dirent`), and
`mkdir` and `remove` need two new externals in `mlsys.c`, over the
kernel's `mkdir` and `unlink` calls, which the C programs already use.
tiny-kernel has no rename, so mv will be a copy and a remove there.

## 4. Links on tiny-kernel

The kernel's files are not copied into its heap: a file of the boot
image is a `Rom (address, size)` node that points into the image. A
link can therefore cost nothing. If the Makefile writes, for each
utility, an entry whose size line is `=utils`, the kernel's `load` can
give that name the same `Rom` node as `utils`. Without this, the
image would carry the 200 KB executable once per utility (14 copies
would be about 3 MB, and the image must stay under 4.5 MB).

## 5. Tests

`tiny/tests/TinyUtilities_test.sh` runs each utility and its twin
(`bin/mini-xxx`) on the same arguments, in a directory made for the
test, and compares the standard output and the exit status. Standard
error is not compared, since the messages were made uniform on
purpose. Two known differences are handled in the script: du -a lists
in sorted order, where the twin uses the directory's order (both
outputs are sorted before the comparison), and ls -l is not tested.

On tiny-kernel (step 3), `make check` runs the same commands through
rc, and its expected output is recorded once it has been checked
against the host's.

## 6. Steps

1. **On the host**: `TinyUtilities.ml` and `.mli`, with the frame, the
   fold, and the 14 utilities of the first three rows; the five
   additions to the host's `TinyLibSystem`; a dune stanza (`tiny-utils`);
   the differential test.
2. **More utilities**: cp, mv, touch, test (rc scripts on tiny-kernel
   need it), pwd (which needs a getcwd in `TinyLibSystem`), sleep.
   `TinyLibSystem` gains four more functions for them: `rename`,
   `touch`, `getcwd` and `sleep` (in milliseconds: tiny-ml has no
   floats). On tiny-kernel (step 3), `rename` is a copy and a remove
   that refuses a directory, as 9P's mv does; `touch` makes a file and
   does nothing else, since the kernel keeps no times; `getcwd` needs a
   call the kernel does not have yet (each process has its directory,
   as a list of names); `sleep` is `u_ready` on no descriptors.
3. **On tiny-kernel**: the kernel's `TinyLibSystem.ml` gets the five
   functions, `mlsys.c` and `calls.ml` get `u_mkdir` and `u_unlink`,
   `load` learns links, and the Makefile builds `utils` and its names.
   The C programs `cat.c`, `echo.c`, `ls.c`, `wc.c`, `mkdir.c` and
   `rm.c` stay in `user/` (tiny-kernel's steps link to them), but the
   image takes the ML ones. The check's expected output changes where ls
   and wc print differently (ls.c prints a type and a size).
4. **The rest of t-ix**: tiny/mkfile's `PROGS`, tiny/README.md's row,
   docs/manuals/t-ix.md.

The size I expect: 300 to 400 lines, about 80 of them for the frame
and the fold, then 5 to 20 lines per utility.

## 7. What was found

Step 1 (2026-10-15):

- **The frame is most of the code, as expected.** `each_input`,
  `pieces` and `options` are 30 lines, and `fold` is 3. With them, cat is
  2 lines, walk 8, rm 6, du 9. wc and xd are the longest filters (20
  lines each), because of their output formats, not their reading.
- **Two of the twins' behaviours did not fit the frame.** Plan 9's cat
  stops at the first file it cannot open, while `each_input` reports it
  and goes on, as every other filter does. The tiny one is kept, and
  the test leaves that case out. du -a lists in the directory's order
  in the twin and in name order here, because `fold` sorts; the test
  compares that case sorted.
- **One behaviour of the twins was worth taking: rc's quoting.** ls and
  du write a name with a space or a quote between quotes, with a quote
  doubled, so that their output can be given back to rc (and to
  tiny-shell, which reads the same quotes). It is 3 lines.
- **tiny-ml already compiles the file**, with the kernel's
  `TinyLibSystem.ml` and stubs for the five new functions (a check by
  hand, not yet in a test). Nothing in it is outside tiny-ml's subset.
  The output is 360 KB of tiny-cpu assembly, about what rc's is.
- **tail reads all its input first**, the one filter that does: it
  cannot know which lines are the last until the end.

Step 2 (2026-10-15):

- **cp reads the whole file before it opens the copy.** Then `cp f f`
  rewrites the same bytes instead of emptying the file, and cp needs no
  idea of a file's identity (the twin compares 9P's qids). The cost is
  memory for a large file, which tiny-kernel holds in memory anyway.
- **cp and mv share their argument rule** ("into the directory named
  last, when it is one"): `into_last`, 9 lines.
- **test is a recursive descent over its arguments**, 50 lines with its
  grammar in a comment. It keeps the questions tiny-kernel can answer:
  file kinds and sizes, strings, numbers, `! -a -o ( )`. Permissions
  and times are dropped. `[` is a row of the table that removes the
  `]` and calls test.
- **Three more deliberate differences from the twins**, each left out
  of the test and said in its header: `cp f f` succeeds; the host's mv
  moves a directory into another directory, which 9P's refuses; and
  `sleep x` is a usage error, where the twin reads it as 0.
