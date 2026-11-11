# Plan: tiny/Buildfile, t-IX built by tiny-build under t-IX

The author (2026-11-11): "Ideally we could also have a tiny/Buildfile
... after all we copy tiny/ under /src/ so we could then go to /src/
and build t-ix from under t-ix", then: "I think we want a tiny/Buildfile
that works when running under t-ix itself, that can also build each
program individually. We can write it from scratch and state the
coupling with the Makefile, and later on factorize and generate the
Makefile from this Buildfile (note that we still want the toplevel
tiny/Makefile; that's another thing)"; and of the outputs: "they could
be in the same directory, like we do in tiny/examples/ no? and build
build would produce a /src/build binary one could run".

## Today

tiny-kernel builds itself already (plan_tiny_self_hosting.md, step 8;
make self): TinyKernel/Makefile writes its own lists as a Buildfile,
put in the image as /src/TinyKernel/Buildfile, and the self-build runs
`build -f /src/TinyKernel/Buildfile` in a directory of the disk. That
file is generated (about 200 lines, from the Makefile's `define
BUILDFILE`), lives only in a build directory on the host, and is read
by nobody: a program cannot be built from it by its name, and its
outputs go to another tree (bin/, ml/, main/, lib/, user/, libc/).

## What it becomes

**tiny/Buildfile**, written by hand, in the tree, read on the host as
on the image, where it is /src/Buildfile. It is also meant to be read:
"well organized and readable and hopefully it can also be a useful
teaching resource for students to understand how things fit together
(the progs, the libs, the runtimes, the kernel, etc.)" (the author).
So its sections follow t-IX's layers, from the bottom up, each with a
few lines on what the layer is and what uses it:

    the runtimes      runtime/'s C and ML parts, tiny-kernel's calls
                      (TinyKernel/libc/, mlsys.c)
    the library       TinyLibCore/, in its order
    the libraries     TinyLibSystem, TinyLibMachine, TinyLibGUI...:
                      what several programs share
    the programs      each by its name: its units, its main, its link
                      (the shell and the utilities, the editors, the
                      toolchain, the window's programs...)
    the kernel        its units, its assembly, kernel.img
    the image         boot.img: the kernel, then /bin, /src, /lib,
                      /examples

A reader follows a program down to what it stands on (rc: TinyShell,
TinyLibSystem, the library, mlsys.o, start.o), and the file is the
one place where all of t-IX's pieces are named together.

    cd /src
    build build          tiny-build, as /src/build, which can be run
    build rc             the shell
    build                every program, the kernel, the image

- **The outputs beside the sources**, as tiny/examples/'s: a unit's
  object and interface next to its .ml (/src/TinyShell.o and .tmi
  beside /src/TinyShell.ml; /src/TinyC/TinyCParser.o in TinyC/), a C
  file's object next to its .c, a program at the top of /src by its
  name in /bin (rc, utils, build, ml...). On the host the same: .o,
  .tmi and the programs in tiny/ (the .gitignore then says so). No
  build directory to choose, and what a recipe made is where its
  source is.
- **A target per program**, named as in /bin. Its rule: its main, its
  units' objects, the library's, the runtime around them, linked; each
  unit's rule: its .ml and the .tmi of the units it reads.
- **The library built here too**, TinyLibCore/'s units in their order,
  ml -nostdlib with their own .tmi (not /lib/ml's: a change to List.ml
  is seen by the programs built after it); the runtimes from runtime/
  and TinyKernel/libc/ (not /lib/c's, for the same reason).
- **The kernel and the image** last: `build kernel.img`, `build
  boot.img`, which is what make self builds today.

## The coupling, stated

The Buildfile says what TinyKernel/Makefile says: the units of each
program (UNITS_x), the interfaces each unit reads (I_x), the library's
order (CORE), the C programs and the kernel's units. Until one is made
from the other, each says so at the top, and a check makes them agree:
make check (or a test of its own) builds a few targets by the
Buildfile, on the host's tools, and compares them with the Makefile's,
byte for byte, as self-quick does for the self-build. Later, the lists
move to one place, the Buildfile, and the Makefile reads or generates
them from it. tiny/Makefile, the top one (make, make test, make run,
make self...), stays as it is.

## The tools it needs

ocaml-light's stdlib (~/ocaml-light/stdlib/Makefile) lists its units
in an order (OBJS, for the archive) and leaves the rest to two tools:
the compiler finds a module's .cmi by itself, in its search path, and
ocamldep writes the dependencies make needs (.depend). tiny-ml has
neither: each .tmi a unit reads is an argument, in order, and the
dependencies are written by hand (TinyKernel/Makefile's I_x lists). So
the author (2026-11-11): "a search path and small ocamldep do make
sense". Both before the programs' rules, since they change what each
rule says:

- **A search path, `ml -I dir`**: a module the source names (M.x, M.t)
  whose interface is not loaded is read from dir/M.tmi, after the ones
  it needs itself; the current directory searched first, as OCaml's.
  A unit's rule then gives no interfaces as arguments: `ml -c -I
  TinyLibCore -o TinyShell.o TinyShell.ml`.
- **Its dependencies, `ml -M file.ml...`** (ocamldep's job, in tiny-ml:
  the same scan of the names a source uses): the lines `TinyShell.o:
  TinyLibSystem.tmi TinyShell.mli` a Buildfile includes (`<.depend`),
  made again by a rule of their own, as ocaml-light's `make depend`.
- To decide while doing it: whether the interfaces read in another
  order (by need, not CORE's) give other bytes. They did for the type
  variables' numbers in a .tmi (2026-11-11: List.tmi with Stdlib and
  Seq alone, its objects the same bytes, its .tmi not); then the
  Makefile reads them the same way, and its .tmi change once.

**ar** (the author: "I wonder if it would make sense to have an ar
command to make libraries under t-ix"): an archive is objects
marshalled as one, which tiny-linker would read in its members' order:
/lib/ml/libml.a and /lib/c/libc.a for the lists and the glob a link
names today (/lib/ml/[A-Z]*.o). The linker already leaves out what
nothing reaches, so this is about packaging and order, not size. As
OCaml's .cma (the author: "we're planning to add ar, so maybe we can also
make ocaml libs"): an archive of ML objects as well as C's, the
interfaces staying .tmi files that ml -I finds; the shared units
(TinyLibSystem, TinyLibGUI...) a library of their own, which programs
link by its name. Made by ml itself, as ocamlc -a and ocamlmklib (the
author: "like ocamlmklib does (but maybe here ml can play all roles,
with a single tool)"): ml -I, ml -M and ml -a -o lib.a units.o, the
archive's format TinyLibMachine's beside the objects', read by
tiny-linker in its members' order. To decide: C's libraries
(/lib/c/libc.a) by ml -a too (the same objects), or by a small ar.
Later, after the library is built by the Buildfile.

## Gaps found on the way

Writing t-IX's build as a t-IX user would showed what its tools lack
(the author: "maybe now that we're exposing more the Buildfile and how
to build t-ix under t-ix, we more clearly see gaps in the current
t-ix"). Fixed already (2026-11-11): rm -f (a clean target was a loop of
test -f), rc's ^ joining a word and a `{...} (the self-build's own
recipe needed it; make self found it). First, what makes a Buildfile
simpler to write and to read, "which are good for the student to add"
(the author), in this order, each asked before it is done:

1. **build's substitution**, mk's ${CORE:%=TinyLibCore/%.ml}: a list
   made from another (lib/ml/Buildfile spells out 48 paths today, and
   the image rule checks them against the Makefile's CORE);
2. **ml -I**, 3. **ml -M**, 4. **ml -a** (above).

Later, not the Buildfile's: no true (a recipe ends with status=''); the
image near its 10 MB (TinyKernelFS.ml's buffers: about 300 KB left, and
outputs beside the sources will want more); a .tmi's bytes depending on
the order its interfaces were read (the type variables' numbers); parts
no check builds, broken unseen (the steps, since 7ea94bae, until
2026-11-11).

## Steps

0. **tiny-ml -I and -M** (above), each with its tests: a unit compiled
   by -I the same as by its interfaces given; -M's lines checked
   against the Makefile's I_x lists.
1. **The library and one program**: CORE's units, then `build build`
   (TinyLibSystem, TinyBuildSystem, its main), the runtimes it links;
   tried on tiny-kernel (`cd /src; build build; ./build -h`) and on the
   host with the host's tiny-build (ml, cc, as, ld as tiny-ml...: a
   directory of links on the PATH, or variables the recipes use).
2. **Every ML program**, by its rules; then the C programs (sh, ping,
   get, put, httpd, paint, mltests).
3. **The kernel and the image**: kernel.img, boot.img; then make self
   runs `cd /src; build boot.img` (old: build -f
   /src/TinyKernel/Buildfile elsewhere) and compares as today.
4. **The check of the coupling**: the Buildfile's objects against the
   Makefile's on the host.
5. **ml -a, the libraries** (ar's job), and /lib's links by them.
6. **Later**: the Makefile's lists from the Buildfile (generated, or
   read), the generated /src/TinyKernel/Buildfile gone.

## Open questions

- The host's tools are named tiny-ml, tiny-c, tiny-assembler and
  tiny-linker, tiny-kernel's ml, cc, as and ld: the recipes say the
  short names, and the host gives them by a directory of links (bin/
  has the long ones), or by variables (ML = ml) set on the host.
- Outputs next to the sources in tiny/ on the host: dune ignores .o
  and .tmi, but they are many; `build clean` removes them, and
  .gitignore lists them.
- A program's main: an object of its own (rc.main.o?) or one with the
  program's last unit, as helloml.ml's (ml -o prog.o units...).

## Status

Proposed (2026-11-11). Nothing built yet.
