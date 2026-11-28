# Plan: simpler builds of ix by ix, as principia's

The author (2026-11-25): "make ix shows a very long output; it looks
very complicated; we should aim to simplify the Makefile and script and
what's not to perform what make ix is supposed to do", "note that we
recently went to simplify mini-analyzer and removed the need for many
scripts", then, of why mklib needs mkfiles/libs.rc: "Why we don't have
this complexity in ~/principia/? What we do in principia that helps
remove the needs for the complexity here?", "let's make it a plan
document recording your analysis and proposing a plan to simplify
things for m-ix (and t-ix) when possible, cheapest first".

**Status: proposed (2026-11-25). Done: steps 1 (233faef6) and 2
(7a7da7c5); step 4's first groups. Step 3 done, t-IX's session's (t-IX built
beside its sources: f0601cfb, e10520b9; its printing). Done in step 4: lib_code,
languages/dotnet/assembly, lib_playground/random, lib_terminal,
languages/pascal, languages/scheme; the linker's units for mini-dotnet;
languages/dotnet/runtime; languages/prolog; mini-ml's parser for
mini-emacs; lib_terminal/hosts; the assembler and the linker as
libraries; the kernels' runtime, a file of each kernel including
runtime.c with its heap. Step 4 done. Step 6 done for m-ix (the start's units read from the link's files,
mini-ml -o linking), done before the rethink: they are independent.
Next: the rethink (objects beside their sources), decided before step
5. Proposed too (2026-11-26): t-IX's tests and checks, T1 to T6.**
The author keeps the objects' dependency on mini-ml's date (MLEXE) for
now, though a relinked mini-ml with the same bytes remakes all of ix:
"I think it's fine to depend on mini-ml date for now".

## What make ix printed

A full build (mini-ml relinked, so every unit made again), counted with
`make ix > out 2>&1; awk '{print $1}' out | sort | uniq -c | sort -rn`:

| lines | what |
|---|---|
| 5,431 | in all, 5 min 22 s; 2,070 lines over 80 columns |
| 1,695 | comments printed as recipes (below) |
| 1,342 | mini-ml, the real work, each line ~350 characters |
| 1,096 | mklib's search of a unit's source: `f=()`, `for(d in ...)`, `if(~ ...)` |
| 739 | `mkdir -p $D` at the start of a recipe |
| 400 | the rest: mini-ld, mini-cc, mini-ar, cd, rm, touch... |

The comments were a bug of the mkfiles, not of mini-mk: as in Plan 9's
mk, a line starting with `#` right after a recipe is a line of that
recipe, so mklib's comment on `lib.a.units` was printed with each of
312 units. After step 1 the same build printed 2,636 lines (4 min 12 s).

## Why principia's mkfiles are simpler

principia's shared mkfiles are 349 lines (mkfiles/: mkone, mkmany,
mksyslib, mklib...), xix's 206; ix's build part is 693 (the top mkfile,
mkconfig, mklib, mkprog, mklibs, mkdepend and six rc scripts:
config.rc, libs.rc, top.rc, units.rc, depend.rc, install.rc). A
program's or a library's rule in principia is one line:

    %.$O:	%.c
    	$CC $CFLAGS $stem.c

Three habits make it enough:

1. **What is made goes beside its source**: port/abs.c makes port/abs.5;
   no rule looks for a source, no directory is made.
2. **A mkfile per directory**: libc spans port/, 9sys/, fmt/..., and each
   has its own mkfile adding its objects to the one libc.a (mksyslib's
   `$AR $ARFLAGS $LIB $prereq`). No mkfile deals with several
   directories.
3. **Headers in one place**, /sys/include: a program is compiled with
   that one `-I`, never told where another library's sources are.

xix, in OCaml, did the same: objects beside the sources, SRC and
INCLUDES by hand in each mkfile, .depend by ocamldep.

ix's mkfiles have what principia avoids, each for a reason:

| ix has | because | principia's way |
|---|---|---|
| $D, its mkdir, units made under `_mk/$O` | what is made is under `_mk/$O` (plan_mkfiles.md): dune reads the source directories and would take a generated Parser.ml for a source; Linux's and Plan 9's builds for one machine side by side | 1 |
| mklib's search of a unit's source, LOCAL, "the last directory found taken" | one mkfile for a library of several directories (lib_graphics 9, lib_audio 10, troff 6) | 2 |
| libs.rc's NEEDI, LIBI, LIBSRC; a `dirs` file beside each archive; mklibs | mini-ml reads the interfaces of the libraries a unit names from their source directories | 3 |
| units.rc, lib.a.units, the `$PROG.start.$O` rule, mkconfig's STD and COMMONS lists | OCaml's units start in an order, which -start writes out | none: C has no such order |
| depend.rc, .depend | a unit is compiled after the units whose summaries it reads | none needed in C; xix used ocamldep |
| config.rc, libs.rc, top.rc as rc read by `<\|.` | a process is a tenth of a second on mini-9pi: one rc where backquotes were many | none: a speed fix |

The last three are OCaml's or mini-9pi's. The first three are choices,
and they are where the plan goes. The first was taken for a reason that
holds, dune and generated sources, but its cost is everywhere: $D in
every mkfile, the MADE lines step 1 brought, `../_mk/7/...` in every
line printed, mini-ld's -build. The author (2026-11-25): "we recently
had to factorize those mkdir -p with MADE, but maybe this should go
away; maybe we should rethink things and have the objects stored next
to the source, which can simplify lots of things", "maybe it would be
too big of a change, so maybe there are simpler things to do first
maybe (but rethinking the whole thing is also a good idea if it's
good)" (the rethink, below the steps).

t-IX shows the way already. tiny/Buildfile builds beside the sources (in
TinyKernel/Makefile's copy of tiny/, so that the tree shows only
sources; in tiny/ itself since e10520b9, below), has a rule for each
directory (`user/&.o: user/&.ml`, mk's &, a stem with no /), and
compiles every unit against the standard
library's interfaces made with it, by one `-L TinyLibCore`: habits 1, 2
and 3. What t-IX keeps of OCaml's needs is small: the start's rule
(`%.start.o`, its units on each program's line) and the library's units
written twice (CORE, here and in TinyLibCore/Buildfile: tiny-build has
no glob).

## The plan, cheapest first

The steps make the current layout simpler, and each one is worth having
whether or not the rethink (next section) happens; step 4 is also its
first requirement.

1. **Done (233faef6): the noise.** A blank line before the 36 comments
   that followed a recipe (17 mkfiles); `mkdir -p $D` dropped from 420
   recipes in 60 mkfiles, $D made once as the mkfile is read
   (`MADE=`{mkdir -p $D}`, mkprog's way); `-I lib_core/system` once
   (config.rc's SYSDIRS). 5,431 lines to 2,636.

2. **A rule for each directory of a library (habit 2, t-IX's way).**
   mklib's one rule, which searches DIRS for a unit's source at each
   compile, becomes one rule per directory, as lib_core/mkfile and
   languages/c/mkfile write by hand:

       $D/%.$O: core/%.ml $LOCAL $MLEXE
       	$ML $INCLUDES -o $target core/$stem.ml

   written for DIRS by libs.rc, which reads DIRS already (an rc loop,
   a few lines). A unit's line then names its file:
   `mini-ml ... -o ../_mk/7/lib_graphics/Png.7 images/Png.ml`. What
   goes: the search (mklib's three lines, 1,096 printed in a build) and
   "the last directory found taken". Two cases to handle: units
   mini-yacc or mini-lex makes in $D (troff's pic grammar: a rule
   `$D/%.$O: $D/%.ml`, or the mkfile's own, as mkprog's mkfiles do),
   and lib_networking's Tcp and Udp, the one library with a unit in two
   of its directories (tcp/ and tcp/plan9/ on Plan 9; mk refuses two
   rules that both apply: an explicit rule each, as lib_core's Unix
   has). No other library has a name twice in its DIRS (checked).
   lib_core/mkfile's eight hand-written rules can then come from the
   same loop. Cost: libs.rc and mklib, about 10 lines changed, a few
   removed. Output: about 1,500 lines for a full build. Beside the
   sources (the rethink) the rules would be t-IX's,
   `core/%.$O: core/%.ml`: the same loop, other words.
   Done: libs.rc's rules, used by mklib and by the four programs that
   had the same search in their mkfiles (doom, quake, virtua, and
   windows/desktop, whose search ran an ls in each directory); a rule's
   prerequisite its source alone, the others every unit's by one line
   (`$OBJS: $LOCAL $MLEXE`, mkprog's way: with them in the rules, every
   directory's rule applied, and mk refused them). A full build: 1,698
   lines before the four programs, down from 2,636. lib_core's rules
   left as written: lib_core is no mklib library. An object names its
   source as compiled, `Helpers.ml`, no longer `./Helpers.ml`.

3. **t-IX's printing.** TinyKernel/Makefile's build prints 30 lines
   when nothing changed, most of them its setup's (the tools' sums, the
   tar of tiny/, the links ml, cc... to the tools) with absolute paths
   of 200 characters; a no-op could print tiny-build's lines alone. To
   do with the session reshaping tiny/Makefile (make host, make
   building t-IX with its own tools). Done: the sums, the tar and the
   links gone (e10520b9, the build in tiny/ itself), the Makefile's own
   commands not printed (@), a line for a file of _make that changed. A
   no-op prints 13 lines, down from 25, tiny-build's: its "up to date"
   and build install's six (_make/system is emptied before each install,
   so that a program removed goes; 1.4 s).

4. **One object per source.** Measured on step 1's full build (703
   compiles; the `cd x && mini-mk` lines give each compile's
   directory), 47 sources are compiled by two directories into two
   objects: lib_code's four (languages/c and languages/ml), languages/
   ml's Ast and Annotations (mini-emacs), prolog's Prolog_read
   (datalog), scheme's eight, pascal's six, dotnet's assembly/ and
   runtime/, the linker's units, lib_terminal, runtime.c (the kernel
   steps, with their own flags). Each group becomes a library
   (plan_mk_libraries.md's way: lib_code, the scheme and pascal
   interpreters, mini-ml's front end...), or the second user links the
   first's object: a build compiles less, a mkfile lists less. 304
   compiles take a source out of their mkfile's directory (mini-emacs's
   62, turbopascal's 24): to read group by group, the same answer where
   a group is a library in all but name. Cost: a commit per group,
   each small.
   The author (2026-11-25): "each lib should have its own mkfile, to
   follow principia's build system simplicity". Done: lib_code, which
   had none (Highlight_code alone at first, 2026-10-09, mini-emacs's,
   before plan_mk_libraries.md's libraries; the SSA algorithms added
   2026-10-29 by a rule in each compiler's mkfile): its mkfile, in the
   top mkfile's LIBS, in LIBDIRS of mini-cc, mini-ml and both
   mini-emacs; 9 compiles fewer in a full build.
   Done: languages/dotnet/assembly (Metadata Image Signature Il Listing
   Writer), which mini-dotnet, mini-cc, mini-ml, mini-csc, mini-tiger
   and mini-datalog each compiled (6 mkfiles' rules); a library of its
   own mkfile in its directory, as browsers/html's. kernels/9pi/tests/
   smoke.sh builds the two libraries for its part of ix, and
   languages/ml/dotnet/tests/run.sh takes mini-cc's libraries' units
   (LIBDIRS's UNITS) before its SRC, as its link does.
   Done: lib_playground/random (Lehmer), split from lib_playground as
   dune's ix_random is, lib_playground needing it, javascript and
   netcode naming it alone; then lib_terminal (Line_discipline Vt Talk
   Curses Tui, and Tty_unix on Linux), linked by mini-pascal, both
   turbopascals and mini-emacs-tty. Left of lib_terminal: hosts/
   (Cells, Picture), over lib_graphics's Font_default, which emacs and
   turbopascal compile themselves.
   Done: languages/pascal (Pcode Pascal_lexer Pascal_compile Pmachine
   Pdebug Pascal_disk), a library and mini-pascal in one mkfile, as
   browsers/javascript and mini-node: both turbopascals link it, their
   six rules gone; it moves from the top mkfile's BOTH to its libraries.
   Done: languages/scheme (Sexpr Sexpr_read Scheme_image Scheme
   Scheme_syntax Scheme_prims Scheme_prelude Scheme_eval Scheme_step),
   a library and mini-scheme (Scheme_secd CLI Main) in one mkfile;
   games/mkgames links it for WITH=scheme (mini-drscheme) instead of
   compiling the nine units in $B/lib_playground/scheme.
   Done: the linker's units in mini-dotnet (Program Debug_link Link Arm
   Arm64), not a library: the linker and the assembler are programs
   whose objects others link (linker/tools, mini-cc, mini-ml), and
   mini-dotnet now links the linker's that way, the top mkfile building
   the linker first. The assembler's and the linker's shared units
   could be libraries too, at no cost in the programs (mini-ld takes of
   a library only the members a program names, below): done since, a
   group of its own (below).
   old: "would link each program's whole archive": wrong, the reason
   given at the time (7f4056a9's message too).
   Done: languages/dotnet/runtime (Value Library Types), a library of
   its own mkfile, over the assembly's; mini-dotnet and mini-csc link
   it, mini-csc's two rules gone. (mini-csc does not link Types, which
   it does not name: of a library mini-ld takes the members that define
   a name left undefined, linker/CLI.ml's help; 4e81e830's message says
   otherwise, wrongly.)
   Done: languages/prolog (Prolog Prolog_read, the terms and their
   reader), a library and mini-prolog in one mkfile, as pascal's;
   mini-datalog links it, its two rules gone. languages/ml/dotnet/
   tests/run.sh's pipeline (-ms only) takes mini-datalog's libraries'
   units, as its front_end does mini-cc's.
   Done: mini-emacs's copy of mini-ml's parser (Ast Annotations Parser
   Lexer), compiled and made by mini-yacc and mini-lex again in emacs's
   two mkfiles: they link mini-ml's objects, as mini-singml does, the
   top mkfile building languages/ml first (and tests/lite.sh's ix).
   Done: lib_terminal/hosts (Cells Picture Window_draw), a
   library of its own mkfile over lib_terminal and lib_graphics: both
   emacs and both turbopascals link it, and with it lib_graphics, whose
   units the draw programs compiled (Point Rectangle Display Draw
   Font_default Font Mouse Keyboard, and emacs draw lib_terminal's own).
   The programs' sizes did not change (mini-emacs-tty 2,054,190 bytes
   to 2,054,766; emacs on the card 2,086,792 to 2,076,568): only the
   members they name are linked.
   Done: assembler (Asm Show_asm Lexer_asm Parser_asm) and linker
   (Program Debug_link Link Arm Arm64 Exe Symtab, dune's ix_ld, over
   the assembler's and lib_executable), each a library and its program
   (mini-asm; mini-ld, with compat/'s Follow) in one mkfile, as
   prolog's, both in the top mkfile's libraries: mini-cc, mini-ml,
   mini-ar, mini-nm and mini-dotnet link them instead of the objects
   named one by one, and the top mkfile's lines for the assembler's
   and the linker's order are gone (assembler.dir, linker/tools.dir and
   languages/dotnet.dir after linker.dir). The objects are the same
   bytes; the programs within 0.3% but mini-ld, 1,166,166 bytes to
   1,202,934 (3.2%), its text 35 KB more: with the library's objects
   named instead of lib.a, the same link is 1,166,150. The members are
   laid out in the order taken, not the command line's, and arm64's
   literal pool, flushed when its 1 MB reach runs out, writes again
   the constants used after a flush: mini-ld's 1.1 MB of code pays for
   where the flushes fall (most of the growth right after a few
   functions, 19 KB after libc's pow). Not changed here.
   Step 4 is done but for runtime.c, which the kernel steps compile.
   Done (2026-11-28): runtime.c, compiled by eight rules of six
   mkfiles (steps 1 to 3, mkkernel's for mini-xv6 and mini-9pi,
   oberon, squeak, singularity's kernel and its processes) with five
   heaps, -DMAXHEAP and -DSTACK (and mkkernel's -DTRACING). The heap is
   the runtime's bss, its size known when compiled, so a kernel cannot
   link lib_core's runtime object: each has instead a file that sets
   its sizes and includes runtime.c, step0's rt.c for the steps,
   lib_machine's rt.c, oberon's, squeak's and singularity's
   machine/rt.c, singularity's lib/prt.c, an object each of its own
   source; the HEAP variables gone. mini-cc finds runtime.c's parts
   (gc.c...) by -I, a quoted include searched first in the directory of
   the file compiled (5c's), the kernel's: none of their names there.
   Checked, the images of a scratch copy built before and after, O=7
   and O=5: the steps' the same bytes; mini-xv6's, mini-9pi's
   (FS=/dev/null), oberon's, squeak's (O=7 only, Pi 4 only) and
   singularity's 6 to 8 bytes apart, the kernel's stamp, the checksum
   of its objects, whose runtime's names another source; the 13
   processes' images the same. Found on the way: singularity's p_init
   not the same from nothing and again (bugs/ix.md, fixed); and
   comments right after a recipe line, which mini-mk takes as the
   recipe's and prints (step 1's noise): the steps' before their start
   rule (9064d613's, step 6) and the runtime's, a blank line before
   each now.

5. **Interfaces from one place (habit 3, t-IX's -L).** Programs are
   compiled against the libraries as installed, `mk install`'s
   `$B/lib/ml/lib_x/`, archive and interfaces, as examples/ is built
   already (and on the card, /lib), not against their source
   directories. What goes: each library's `dirs` file, NEEDI, NEEDD,
   LIBI, LIBSRC (a program remade when an installed interface is newer,
   install.rc copying only what changed), most of libs.rc and mklibs.
   What to check: install's place in the top mkfile's order (a library
   installed before the programs that use it, once, not a second mk);
   mini-9pi's build time (the copies are processes); the analyzer's
   manifests, which name each source by its project path (an installed
   .mli is a copy: mini-ld -map must still name the original).
   Cost: medium, mklib, mklibs, libs.rc, install.rc, the top mkfile.
   Decide the rethink before it: beside the sources, where an installed
   library goes changes.

6. **The start's units read from the archives (OCaml's order, as
   ocamlopt does).** mini-ml -start writes the start already, but of
   the units its command line names, each program's link listing them:
   lib_core's (mkconfig's STD and COMMONS), each library's (units.rc,
   lib.a.units), its own. ocamlopt reads a .cmxa's units in order and
   writes the program's startup itself. Why the list: -start came with
   the first programs (c0ed57c1, 2026-09-26), when a program named
   lib_core's objects one by one; lib_core.a (3e641175) changed the
   link, the start's names made weak, not the list; ix's libraries
   added units.rc, then lib.a.units for the card's speed (2026-11-19),
   each the smallest change of its day, though an archive holds its
   units in the order they start in (mklib's UNITS). If mini-ml (or
   mini-ld) read the archives' order,
   each program's `$PROG.start.$O` rule, units.rc, the lib.a.units
   files and mkconfig's STD and COMMONS lists would go, and t-IX's
   twice-written CORE with tiny-ml doing the same. Cost: the largest, a
   toolchain change in both systems; the order of a link is then the
   only list of units.
   Done for m-ix (2026-11-27), before the rethink, which it does not
   depend on (the archives read where the link line says). The files
   read for their first value alone (Marshal_.first): a library
   (Library_file, version 6, the assembler's library, moved from
   Link) its index first, each member's source and names, then the
   members' bytes; an object (Asm, version 6) its version and source
   first. Versions 5 are still read, whole (an object of C is not made
   again when mini-cc is: a checkout's _mk keeps them). mini-ml -start
   takes those files, a library giving its units in its order, an
   object its own, one of C none, a name itself; mini-ml -o prog,
   given objects and libraries alone, writes prog.start.$O, then
   execs the linker in its place, -ld's words up to -- (mkconfig's
   LINKER), else its own name with ld for ml (mini-ld -m 7, the card's
   ld). 88 links in 52 mkfiles are one line each, mkprog's start rule
   gone; units.rc, lib.a.units and every mkfile's LIBUNITS gone
   (LIBOBJS's objects say them). STD and COMMONS stay: lib_core's
   mkfile builds lib_core.a from them, and oberon, squeak and
   singularity, which start $STD without $COMMONS though they link
   lib_core.a, still name their units (from lib_core.a they would
   start COMMONS too: a change of what they do, left to them).
   A unit twice: given again as an object (mini-node's Js_compile, in
   lib.a too) started once, at its library's place; a program's unit
   of a library's name (quake's Physics, lib_playground/apis's) at the
   object's place alone, mini-ld linking the object, where the old
   start named it at apis's place first (Physics reads no unit when it
   starts: two constants); two libraries' (troff's Fill,
   lib_graphics's) both, as before (started at lib_graphics's place
   alone, troff's Fill read troff's units not yet started: mini-troff
   crashed, make test).
   Measured, a build from nothing in a scratch copy against HEAD's:
   Linux, 138 of 149 programs the same bytes (the toolchain's 7,
   whose code changed; quake's two, Physics; tiny-build and tiny-vcs,
   112 bytes, lib_crypto's units now all named, weakly, where Sha1
   alone was); the card's (O=5 OS=plan9) the same cases, 124 of 137
   then. The kernels' images the same. Time: Linux's build 27.2 s
   against 26.1, its no-op 3.40 s against 3.56 (noise). On the card a
   link ran units.rc's rc and a cat a library; mini-ml reads the
   indices instead, 31 KB of lib_core.a's 4.9 MB (0.1% to 1.5% of a
   library); mini-ml's own link's start under mini-5i 30.45 s against
   30.07 (its three indices), the rc and three cats gone (about 0.4 s
   on mini-9pi), and the linker exec'ed, no fork of mini-ml. mini-nm
   73 KB smaller (Library_file, not Link). Not done: t-IX's tiny-ml
   and CORE (the t-IX session's); make self-quick-mix not run (the
   card's bytes).

Not planned: dropping libs.rc's `<|.` way, which is mini-9pi's speed.

## The rethink: objects beside their sources (habit 1)

`core/List.ml` makes `core/List.7`, a program `mini-ls` in its
directory (or principia's `7.out`), as principia and t-IX do. What
goes: $D and B in every mkfile, the MADE lines of step 1 and the other
mkdirs, `-I $D`, the generated units' lookup in $D, mini-ld's -build
and its mirrored tree, the long `../_mk/7/lib_graphics/` in each line
printed (a line about a third shorter). It is the change that removes
the most, and the one that touches the most: every mkfile, mostly by
removals. To decide once steps 2 to 4 are done (4 is its first
requirement), before step 5. What else it needs:

- **One object per source**: step 4. Beside the sources, two compiles
  of one file write one object: at once, a race; with other flags, a
  wrong one.
- **Generated sources out of dune's sight.** mini-yacc's and
  mini-lex's Parser.ml and Lexer.ml (19 mkfiles) beside the .mly would
  be taken by dune for sources (plan_mkfiles.md's reason for `_mk`).
  They can go in a directory dune skips, `_gen/` beside the grammar
  (dune skips names starting with `_`), or dune's stanzas exclude
  them; objects (.7, .5) dune ignores.
- **One configuration per tree.** Linux's and Plan 9's arm builds
  (make ix-arm, O=5; the card's, O=5 OS=plan9) both make `x.5`, from
  other Unix interfaces; the games again for Plan 9's software platform
  (mkgames's BESIDE). The default build (O=7, Linux) beside the
  sources, the others in a copy of the tree (git ls-files, 69 MB), as
  TinyKernel/Makefile builds t-IX for another O; the card builds
  in its own /src already.
- **make test in a copy.** tests/lite.sh builds ix in its own B so
  that two runs, or a session's build, do not meet (memory: private
  builds); beside the sources it builds in a copy, as above.
- **The tree's users of `_mk/`**: 162 lines of scripts and Makefiles
  (check.sh ix's MK, caps_types.sh, kernels/9pi's card, install.rc,
  examples/), .gitignore (`*.[57]`, `*.a`), make clean, TinyKernel/
  Makefile's copy (git's list of sources since e10520b9: .gitignore
  leaves them out).

Order, if taken: the generated sources' place, then mkprog and mklib
with a few directories of each, then the rest, then the scripts.

### t-IX first (e10520b9)

The author: "what if we start now to avoid those tiny/ copy and
_make/src/ and build the object next to their source?". tiny/'s make
runs `tiny-build TINY=tiny-` in tiny/, as `build` in /src under t-IX
(f0601cfb; any other target is the Buildfile's: make rc), and
TinyKernel/Makefile's default build runs there too: `_make/src`, the
links to the tools under t-IX's names and the tools' sums gone.
Another O (make test's, check.sh tiny's, MEMORY's) builds in a copy of
tiny/'s sources. The images are byte for byte the copy's. What it
taught, which m-IX will meet:

- **The sources are a list, git's.** A directory holding what was built
  beside its sources cannot be copied by excluding patterns:
  TinyKernel's `--exclude` list lacked the programs (rc, ml...), and
  src.img, /src, overflowed its 8 MB with them. `git ls-files -co
  --exclude-standard`, less the deleted files, gives the sources, for
  a copy and for src.img; .gitignore is the one list of what the
  build makes.
- **The tools are not in the digests.** tiny-build's digests are of
  recipes and sources, so a new tiny-ml remakes nothing; the copy used
  to start afresh when a tool's sum changed. Kept simple, as t-IX: make
  clean after a tool's change. Met the same day: tiny-as's new object
  format, the old objects refused by tiny-ld ("rebuild it").
- **A directory holds two builds.** mini-analyze takes a directory's
  manifests, or with none the programs dune builds there; with t-IX's
  manifests in tiny/, check.sh tiny's `tiny` gave those instead of
  dune's programs (their reports "gone"). dune's are now named by
  their build directory, `_build/default/tiny`.

## t-IX's tests and checks, cheapest first

The author (2026-11-26): "Is there other opportunities for such
simplications, especially in tiny/, so we don't improve so much the
OCaml code itself of the programs, but more the build/test/check infra
around it; a clean build with a small set of commands run, with not so
many flags, is usually a good smell for a project, compared to very
very long commands and complexity." The build itself, tiny/Buildfile,
is in good shape after the work above. The test and check harness
around it is where the long commands and the repeated lists are now.
Proposed (2026-11-26), not started. T1 to T3 need no tool change; T4
and T5 each need a change to a tiny tool, to decide first.

T1. **TinyKernel/Makefile's check: one file per session.** The 28
   sessions of `make check` are rules `$(O)/check/01.out` to `28.out`,
   each a `printf '...' | $(TIMEOUT) 300 $(MACHINE) $(D) boot.img`
   with the whole session in the printf, and their outputs are joined
   into one check.expected (the file whose CRLF lines the Edit tool
   rewrites). A failure is a diff in that one file, and recording
   records all 28. Instead, each session would be a file with its own
   expected output, `tests/TinyKernel_tests/rc.keys` and `rc.expected`,
   as db.keys, vcs.keys and build.keys already are, and one pattern
   rule would run them all. Only the sessions with flags of their own
   (-net, -events, a second disk, several runs: about six) keep an
   explicit rule. NCHECK and SCREENS then become wildcards over
   `$(T)/*.keys` and `$(T)/*.events`, so that a test is added by adding
   its files. The sessions get names instead of numbers, a failure
   names its session, and each one is recorded alone. tests/lite.sh's
   tiny_kernel and tiny_self, which run parts of check and self-quick
   again from their own heredocs and grep loops, could then run a few
   of the same .keys files through a target of TinyKernel/Makefile.
   Cost: small, mostly moving text into files.

T2. **The tests link their images from the Buildfile's build.** Ten
   scripts of tiny/tests/ source link.sh, whose ml_lib compiles
   TinyLibCore again in each test, and then call tiny-ml and link_tm
   with their own lists of units (TinyOffice_test.sh's line 51 is the
   Buildfile's OFFICE_UNITS again, with the test stub of
   TinyLibSystem). This is a second build of tiny-machine programs,
   written in shell. The test images could be targets of a Buildfile
   (tests/Buildfile, or a section of tiny/Buildfile), linked from the
   stdlib.a and the objects that make has built, so that the scripts
   only run the images and compare, as a script should only read a
   build (memory: scripts assume a build). It also removes two of the
   copies of CORE (link.sh and TinyLibCore_test.sh, a part of it in
   TinyAssembler_test.sh) and KGraphics_test.sh's copy of the od and
   awk pipeline that turns the font into assembly, which is
   TinyKernel/Makefile's kfont.s rule again. Cost: medium, one test at
   a time.

T3. **One way to compare with a recording.** Seventeen scripts of
   tiny/tests/ repeat the same lines: RECORD=1 to record, KEEP and W
   for the work directory, a failures counter, fail(), the ok and FAIL
   lines, and a diff cut at ten lines. Many of them only run a
   Host.exe and compare its output with a .expected file. For those,
   dune's own way is a rule in the test directory's dune file,
   `(rule (alias runtest) (action (diff calc.expected calc.out)))`,
   with `dune promote` in place of RECORD=1, as OCaml's expect tests
   do. The others, which run tiny-machine or another program, would
   share one helper, as they share link.sh. Cost: small for each
   script; lite.sh's jobs then name dune's aliases.

T4. **The Buildfile's programs, one line each (a tiny-build change).**
   The 26 ML programs each have the same three lines (X_UNITS, then
   `X.start.o: $STDLIB $X_UNITS`, then `X: $CRT $MLRT X.start.o $STDLIB
   $X_UNITS $MLEND` with `$LD -map -s -n -o $target $prereq`), apart
   from the name, the units, and ld's -a for nine of them. A variable
   for ld's common flags needs no tool change. A rule for all of them
   would need tiny-build to read a variable named after the stem
   (`${stem}_UNITS`), and a variable for each program's -a. The
   X_UNITS lines would stay, so the file would still show which
   program stands on which library; about 75 lines would become about
   30. To decide: whether the Buildfile, meant to be read, reads
   better that way.

T5. **.depend made by the build (a tiny-build or tiny-ml change).**
   `build depend` is run by hand after a unit names another one or a
   unit is added; when it is forgotten, make check passes, by the
   order of the units, and make test fails (memory). The build could
   make .depend itself, before it reads it: tiny-build would need to
   include a file it has just made, or make would run `build depend`
   first, if tiny-ml -depend is fast enough over all of tiny/. To
   measure, then decide.

T6. **Smaller ones.**
   - The top Makefile's check-tix loops over -caps, -dead, -bugs and
     -exn in shell, with a case on OCaml's version. check.sh tiny
     -check could run the four and know the OCaml 4 rule itself, so
     that the target is one line (the logic in the analyzer, as the
     manifests did).
   - The Buildfile's CORE exists for build install, which copies the
     library's interfaces to /lib/ml. An rc glob in the recipe,
     `TinyLibCore/*.tmi`, as /examples is copied, would remove that
     copy of CORE; TinyLibCore/Buildfile's stays (step 6 above).
   - TinyKernel/Makefile chooses its machine among three dune build
     directories (_build, _build_release, and _build5 through opam
     when OCaml 5.5.1 is there, for the domains). Whether one release
     build would do now is to be checked.
   - TinyKernel/steps/Makefile could be a Buildfile, so that every
     part of t-IX is built the same way.
   - Not planned: tiny/.gitignore lists the 33 programs again
     (PROGS), since they go at the top of tiny/ under their names; no
     simple pattern replaces the list.

## Checks for each step

make ix's output and time on a full build (the counts above, by the
same awk), and mini-mk at the top when nothing changed (2 s); make
test; for steps 2 and 5, mini-mk -n of a library for O=5 OS=plan9 (its
lines, Plan 9's Unix, Tcp, Udp); for 4, 5, 6 and the rethink, make
self-quick-mix, the card's objects against the host's. Not run during
the work: the full make self (hours).
