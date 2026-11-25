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

**Status: proposed (2026-11-25). Done: step 1 (233faef6). Next: step 2.**
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
sources), has a rule for each directory (`user/&.o: user/&.ml`, mk's &,
a stem with no /), and compiles every unit against the standard
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

3. **t-IX's printing.** TinyKernel/Makefile's build prints 30 lines
   when nothing changed, most of them its setup's (the tools' sums, the
   tar of tiny/, the links ml, cc... to the tools) with absolute paths
   of 200 characters; a no-op could print tiny-build's lines alone. To
   do with the session reshaping tiny/Makefile (make host, make
   building t-IX with its own tools).

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

6. **mini-ml writes the start (OCaml's order, as ocamlopt does).**
   ocamlopt reads a .cmxa's units in order and writes the program's
   startup itself. If mini-ml (or mini-ld) read the archives' order,
   each program's `$PROG.start.$O` rule, units.rc, the lib.a.units
   files and mkconfig's STD and COMMONS lists would go, and t-IX's
   twice-written CORE with tiny-ml doing the same. Cost: the largest, a
   toolchain change in both systems; the order of a link is then the
   only list of units.

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
  TinyKernel/Makefile builds t-IX in a copy of tiny/; the card builds
  in its own /src already.
- **make test in a copy.** tests/lite.sh builds ix in its own B so
  that two runs, or a session's build, do not meet (memory: private
  builds); beside the sources it builds in a copy, as above.
- **The tree's users of `_mk/`**: 162 lines of scripts and Makefiles
  (ix_check.sh's MK, caps_types.sh, kernels/9pi's card, install.rc,
  examples/), .gitignore (`*.[57]`, `*.a`), make clean, TinyKernel/
  Makefile's copy (it must leave out `*.[57]`).

Order, if taken: the generated sources' place, then mkprog and mklib
with a few directories of each, then the rest, then the scripts.

## Checks for each step

make ix's output and time on a full build (the counts above, by the
same awk), and mini-mk at the top when nothing changed (2 s); make
test; for steps 2 and 5, mini-mk -n of a library for O=5 OS=plan9 (its
lines, Plan 9's Unix, Tcp, Udp); for 4, 5, 6 and the rethink, make
self-quick-mix, the card's objects against the host's. Not run during
the work: the full make self (hours).
