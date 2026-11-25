# Plan: build manifests, what a build linked, for mini-analyze

The author (2026-11-24), after a look at how far tiny_check.sh and
mini-analyze's flags could shrink: "I like this linker idea that generate
metadata for mini-analyzer to use. Actually I remember LLVM and the
clang-analyzer also rely on some .json generated next to the Makefile to
describe the files and -I -D etc. Seems like a good idea given when one
can build a program, the info is there to build it!", "we can probably
find a way to tag some files as a library, as a program component, as
the entry point, as a test, as test infra, etc. Ideally we want to
specify a format/type for mini-analyzer to share with the different
tools so one can simply marshall this complex metadata build type", "we
probably need a plan document for it, with a design for the type of
metadata we need", "and we can probably remove lots of the -I, -L, -own,
and other flags from mini-analyzer?", "and maybe also the make generated
target, we can remove, and use instead again the metadata to specify the
path to the generated file".

**Status: proposed (2026-11-24). Done: tiny/TinyLibExecutable.ml made
from TinyLibMachine; tiny-ld -map writes out.manifest (step 2, its
tiny-ld-only version); mini-analyze reads it, tiny_check.sh's tiny-kernel
runs by manifests, K gone; dune's manifests (step 3), 17 of tiny_check.sh's
27 host runs by them. Next: step 4, m-ix's toolchain.**

## The problem

mini-analyze reads a whole program, so it must know the program's files
and how each one is compiled. Today that knowledge is written a second
time, beside the build files:

| where | what it says again | lines |
|---|---|---:|
| tiny_check.sh's table | each t-IX program's main, platform (k/h/b), -I's | 35 of 166 |
| mk_units.sh | a mkfile's SRC, its -I's, where a unit's file is, start order | 124 |
| generated.sh, `make generated` | the lexers and parsers the build makes | 37 + 3 |
| kernel.sh, sweep.sh | -L, -I, -D, -start of the kernel and the 44 programs | |
| Module_finder, Caller_finder | guesses of the same, from names and directories | 240 + 139 |

and as flags: -L (the standard library), -I (an ML library's directory or
a C include), -own (whose units are reported on, and the platform's
implementation of TinyLibSystem), -D, -start (the order the units start
in), -library (every function an entry), -summary and -program (the
merge of several programs).

Every one of these facts is known exactly, at one moment, by one tool of
the build: the compiler knows the source it read and its flags, the
linker knows which objects it took (archive members included) and in
which order. Module_finder had to guess the rest, and on a tie it warns
(mkfont's Fill: lib_graphics/software or typesetting/troff/roff). Measured
on 2026-11-24: five of tiny_check.sh's six -I uses give the same -dead
report without them, the guess being right; the sixth (tiny-mkfs's
TinyKernel) only moves 21 lines from library to own. The flags that
remain are those where the analyzer cannot guess: the platform.

## Others' ways

- **clang's compilation database**, compile_commands.json: one record per
  compile (directory, file, arguments), which clangd, clang-tidy and the
  clang static analyzer read. CMake writes it
  (CMAKE_EXPORT_COMPILE_COMMANDS); clang -MJ writes each compile's record
  itself, the compiler being the one that knows; Bear makes one for any
  build by intercepting the exec's. What it lacks for us: the link.
  Which files make one program is not in it, and a whole-program analysis
  needs exactly that.
- **Coverity's cov-build**: first a wrapper in front of gcc (xgcc) that
  wrote down each call's flags, later the interception of the build's
  processes, so that any build system works unchanged. It records the
  link too.
- **Infer, CodeQL**: the same idea, a capture of the build ("infer
  capture -- make", CodeQL's tracer).
- **dune describe workspace**: dune's own answer, one s-expression for
  the workspace: each executables stanza's modules with their source
  (generated ones in _build), each library with its directory and
  modules, which library implements a virtual one (tiny_lib_system_unix).
  Tried on 2026-11-24 with a private --build-dir: tiny/ in a few seconds.

ix owns its toolchains, so it does what clang -MJ does, in each tool,
and what Coverity does at the link: no wrapper, no interception. Only
OCaml's compiler, which ix does not own, needs another way: dune
describe.

## The design: record what is known, derive the rest

Each tool records only what it knows when it runs; what is known only
across programs (a library, test infrastructure) is derived by the
analyzer from all the manifests, as Datalog derives from facts.

- **The compiler** (mini-ml, mini-cc, tiny-ml -c, tiny-cc; mini-asm and
  tiny-as for a .s) puts a *compile record* in the object it writes: the
  source compiled, the file it was generated from if it says so (a
  `# line` of mini-lex's or mini-yacc's), the .mli read, the flags, a
  digest of the source. mini-ml's objects already carry the source's
  history and acid's types as marshalled sections after the object
  (Asm.ml); this is one more.
- **The archiver** (mini-ar, tiny-ar) keeps its members' records, as it
  keeps the members.
- **The linker** (mini-ld, tiny-ld) writes `out.manifest` beside `out`
  (as tiny-ld -map writes out.map): the program, its system and
  architecture, then the records of the objects it took, in link order,
  each said to be the start object, an archive's member (which archive),
  or given on the command line. For ML the link order is the start
  order: -start's input comes with it.
- **dune's programs**: a small OCaml program reads `dune describe
  workspace` and writes the same manifests (the ones ix's tools would
  write had they built them), in the build directory. An executables
  stanza lists the modules of all its programs together, so a program's
  units are its stanza's that its main reaches, plus its libraries'.

### The type

One type, marshalled, as the toolchain's objects are (toolchain
decisions of 2026-09-23). OCaml's Marshal format is what lib_core's and
TinyLibCore's Marshal both write, so a manifest written by tiny-ld built
by tiny-ml is read by mini-analyze built by OCaml or mini-ml. Marshal
knows no type: both sides must declare the same one, constructors in the
same order, and the file starts with a magic string and a version, as
Asm's objects do (version, o).

```ocaml
(* Manifest: what a build linked into one program, for the tools that
 * read programs whole (mini-analyze). Written by the linker, from the
 * compile records the compilers put in the objects. *)

type lang = ML | C | Asm

(* a compile's flags, as the compiler understood them *)
type flag =
  | Include of string          (* -I dir: an ML library's units, C's #include's *)
  | Define of string * string  (* -D name=value *)
  | Stdlib of string           (* -L dir: the standard library compiled against *)
  | Pp of string               (* a preprocessor run on the source (mlpp) *)
  | Other of string            (* a flag that changes nothing a reader needs *)

(* what the compiler knows: put in the object *)
type compile = {
  source : string;          (* the file compiled, a generated one too:
                               _mk/7/languages/ml/Lexer.ml *)
  generated_from : string option;  (* its .mll or .mly *)
  interface : string option;       (* the .mli read for it *)
  lang : lang;
  unit_name : string;       (* List; a C file's base name *)
  flags : flag list;
  digest : string;          (* of the source, when compiled: a stale
                               manifest is said, not read silently *)
}

(* how the linker took an object *)
type taken =
  | Given                   (* named on its command line *)
  | Member of string        (* pulled from this archive: libc.a, stdlib.a *)
  | Start                   (* the start object, which calls each unit's init *)

type linked = { compile : compile option;  (* None: an object of another
                                              compiler, no record *)
                object_ : string; taken : taken }

type kind = Program | Test | Kernel

(* what the linker knows: out.manifest *)
type t = {
  program : string;         (* rc, mini-ml, tiny-kernel *)
  output : string;          (* the executable, relative to root *)
  root : string;            (* the directory the paths are relative to,
                               as the build saw it: /src on tiny-kernel,
                               which is tiny/ in the tree *)
  system : string;          (* t-ix, m-ix, host *)
  arch : string;            (* tiny, arm, arm64, the host's *)
  kind : kind;
  units : linked list;      (* in link order: ML's start order *)
}
```

What is not in it, being derived by mini-analyze from all the manifests
it is given:

| tag | derived as |
|---|---|
| the entry point | the start object's order: each ML unit's toplevel, the last unit's being the main; C's main |
| a program's own unit | linked by this program alone |
| a library's | linked by several programs (or from an archive) |
| the standard library | a unit of the -L directory its compile names |
| the runtime | C units of an ML program |
| a test | kind = Test |
| test infrastructure | linked only by tests (Testutil_xxx) |
| generated | generated_from is set |
| the platform | the files linked: the build already chose TinyLibSystem's |

kind is the one tag that is said rather than derived: the linker cannot
know a test from a program. dune says it (a `test` stanza); tiny-ld and
mini-ld would take `-kind test` from a build file's test rule, else
Program. (Or a path under tests/, as Caller_finder now does: a fallback
to decide on.)

## What goes away

In mini-analyze, given manifests:

- **-L, -I, -own, -D, -start**: in each unit's compile record.
- **-library**: an archive given instead of a program (mini-ar's libc.a
  with its members' records) is a library: every function an entry.
- **-summary, -program** and the scripts' run of dead_all.dl:
  mini-analyze given several manifests runs each program and merges
  itself, as dead_of_callers already does for the programs that reach
  one file.
- **Module_finder's guessing and its tie warnings**, Caller_finder's
  search for mains, when manifests are given: the manifests list the
  programs. Both stay for a checkout with nothing built (the author:
  "maybe the mini-analyzer could keep those Caller_finder.ml,
  Module_finder.ml so one can also call mini-analyzer on a fresh repo
  without anything built; but we should probably focus now more on
  using those manifest for precise set of files to analyze").

A library's callers are not in its own manifest (an archive's, or none
for a dune library or a TinyLib*.ml) but in the programs' (the author:
"in any case, for the library, we still need to find the callers which
are probably not in the library manifest; they are in the programs
manifest instead"). So -dead on a library's file reads every program
manifest of the build and keeps those that link the file: Caller_finder's
question, answered by the build instead of by the names in the text.
Each such program is run and the reports merged, as dead_of_callers does
today; a library no program links is said so.

In the scripts:

- **tiny_check.sh's table** (35 lines, the k/h/b column, O, K, NET):
  every manifest of the t-IX self-build (tiny-kernel's programs) and of
  dune's build of tiny/ (the host's). From 166 lines to perhaps 60.
- **mk_units.sh** (124 lines): mini-ld's manifests in _mk/7.
- **generated.sh, `make generated`, Module_finder.generated**: a generated
  unit's source in its record is the file the build made (in _mk/7 or
  _build), and generated_from names the .mll/.mly it comes from.
- **tiny_check.sh and ix_check.sh as one script**, the two differing
  only in which manifests they read and which recording they compare.

The cost: an analysis needs the build first, which it already mostly
does ("dune build first", MK=_mk/7). The difference: generated.sh made
only the lexers and parsers, in seconds, where _mk/7 is the whole
mini-mk build. For make test, dune's manifests of the m-ix programs are
there at once (dune builds them with OCaml); _mk/7's would be for
test-long, unless make test already has an m-ix build. To check: whether
dune's ocamllex and ocamlyacc output, against mini-lex's and
mini-yacc's, changes a recorded report.

## Steps

1. **The type**, in lib_executable/Manifest.ml (where the type goes,
   below) and a copy in tiny/ (t-IX's tools use no file outside tiny/),
   with a printer
   (`mini-analyze -manifest x.manifest`: the marshalled bytes are not
   readable) and a test that the two declarations are the same text and
   that OCaml, mini-ml and tiny-ml write the same bytes of one value.
2. **t-IX**: tiny-ld writing out.manifest. tiny_check.sh's tiny-kernel
   runs (k and b) read the self-build's manifests; dead_tiny.txt and the
   other recordings unchanged.

   Done 2026-11-24 in the cheaper version, tiny-ld alone, no compile
   record in tiny-ml's objects (the author: "note that in theory we build
   most of the tiny programs also on the host, and with dune and mini-ml
   too, so we don't have to have the manifest in tiny-ml and tiny-ld in
   theory, but if it's not too many LOC to add to tiny/, it might be
   nice", "yes go ahead with the tiny-ld only version"). Only tiny-ld
   says the tiny-kernel reading: the host's builds link
   TinyLibSystem/unix and lib_core, and the windows' programs that only
   tiny-kernel runs (windows, bigmem, temp, trace, debug) and the kernel
   are linked by no host build. t-IX needs no record: it generates no
   source and compiles each unit the same way, so the files linked are
   all a reader needs; a source is found beside its object (the
   Buildfile's way), an archive member's beside the archive. The
   manifest is written with -map, which every Buildfile link gives, so
   no link line changed: TinyLibExecutable's types and to_manifest,
   tiny-ld's read saying where each object came from, and source: 46
   lines of .ml, 48 of .mli (the types, their comment). Checked: rc's
   manifest from a self-build's objects lists the runtime's .c and .s,
   the 23 TinyLibCore members of stdlib.a,
   TinyLibSystem/tinykernel/TinyLibSystem.ml and TinyShell.ml, rc.start.o
   with no source; TinyML_test.sh's units link.

   Read by mini-analyze, the same day: a file.manifest argument
   (Tiny_manifest, its types the same text as TinyLibExecutable's,
   analyzers/tests/run.sh checks it) gives the files tiny-ld was given,
   in the link's order, as the program's own; the archive's directory as
   -L; and every linked unit's file to Ml_front.linked, where a unit's
   code is the file linked, or none, nothing searched or guessed.
   -sources dir: the paths read there, the build having run in a copy of
   it (TinyKernel's _make/src). tiny_check.sh builds t-IX in its own O=
   (4 s) and reads each tiny-kernel run from its manifest: K (-L
   TinyLibCore -own TinyLibSystem/tinykernel) gone, the four recordings
   unchanged. Run by run, against the old way, -dead the same for 25 of
   the 27 programs, the kernel among them; troff and play differ, the manifest
   right: troff links all of OFFICE_PARTS, Paint.o which it never names,
   so Paint's functions are linked and dead in troff; play links GUI
   without naming it, which the old reading did not read. The merge
   (dead_all.dl) leaves both out, office using Paint and other programs
   TinyLibDraw's d_*.
3. **dune**: the describe reader writes the host's manifests;
   tiny_check.sh's host runs (h and b) read them; the table goes.

   Done 2026-11-24 (the author: "ok let's commit and move forward with
   dune's manifests"). dune describe workspace alone is not enough: it
   gives each library's and stanza's modules with their sources, but a
   program's requirement on a virtual library (tiny_lib_system) without
   the implementation it links, the platform, which -own said. dune
   rules X.exe gives the link itself, ocamlopt's command line, the
   .cmxa (tiny_lib_system_unix.cmxa among them) and the program's .cmx,
   in order. analyzers/manifest/ (Dune_manifest) reads both answers and
   writes tiny-ld's format: a local library's modules members of its
   archive, the stanza's module of each .cmx given, opam's libraries
   (no source) and dune__exe left out; a path the project's file, else
   the one the build made, _build/default's (lib_core's Parallel, a
   lexer). Both dune queries in a build directory of tiny_check.sh's
   own (2.5 s, 31 MB), _build being another dune's.

   The reader learned two things from dune's links. OCaml links an
   archive's modules the program names, tiny-ld all of them (tiny-shell's
   link has tiny_lib_regex.cmxa, which it does not name): so a member is
   not read up front; the members in the program's part of the project,
   not the standard library's, give their directories as -own's
   (Tiny_manifest.own_dirs: TinyLibSystem/unix, tiny/'s TinyLib*). And
   the standard library is the first directory up from a member with a
   units.txt (lib_core) or a Stdlib.mli (TinyLibCore); a unit the build
   took from outside the project (OCaml's List, Hashtbl) is read from
   it, as before.

   Against the old way, run by run (-dead): 17 of 19 host programs the
   same, of 27 host runs 17 by manifests. Ten keep their main file and
   flags, the old way: the 8 SDL windows' programs (tsdl, unread, and
   dune's copy_files#); tiny-machine,
   whose dune link (OCaml 5) has lib_core's Parallel on Domain, which
   the analyzer cannot read (the old way read its .mli alone);
   tiny-mkfs, whose host/KRaw.ml is also the SDL windows' memory: by its
   manifest, KRaw is the program's part and 13 of its functions said
   dead, used by the windows, which are not read (its KFS's 21 lines
   the kernel's run merges away). Gone from tiny_check.sh: NET, the
   graphics' and lib_crypto's -I's. The four recordings unchanged.

   Then mini-analyze takes dune's executable itself (the author: "yes,
   let mini-analyze take the .exe and run dune itself"):
   mini-analyze -dead _build/default/tiny/TinyBuildSystem.exe (or
   tiny/TinyBuildSystem.exe) runs dune describe and dune rules
   (Dune_manifest.run, now in analyzers/ml/, the standalone
   analyzers/manifest/ kept for tiny_check.sh's batch of 17), in a build
   directory of the temporary directory's, one per project and kept: 2
   s a run, 2.5 more the first. Its paths are read from describe's root.
   From the project's root only: -r's default, analyzers/datalog, is
   relative.

   Then -dead on one program reports its own files alone (the author: "I
   ran ./bin/mini-analyze -dead tiny/TinyKernel/_make/src/build.manifest
   and got lots of dead function reported in TinyLibSystem which is not
   what we want; ideally we can detect from the manifest the files that
   are pure "external" libraries vs the component of the program
   analyzed, here just TinyBuildSystem.ml really"). The manifests say
   it, no flag: a program's components are the files given to its link
   that no other program of the build links (tiny-ld's: the manifests
   beside it, TinyLibSystem/tinykernel in all 33; dune's: the stanza's
   modules, a .cmxa's a library's). Ml_front.components, Dead_report
   keeping those; a line under the report names them and where a
   library's dead code is found (-dead its file, over its programs).
   -dead alone: a bug or a capability in a library the program reaches
   is one wherever it is (-bugs, -exn, -caps unchanged), and a run of a
   merge (-summary: tiny_check.sh, -dead lib.ml) reports all, the merge
   deciding. build: 47 dead reported before, all TinyLibSystem's, 0 of
   TinyBuildSystem.ml now; ml's 9 components, 0.

   And -dead on a library's file finds its programs in the manifests
   given (the author: "yes, build the manifest-based version"):
   mini-analyze -dead tiny/TinyLibGUI.ml tiny/TinyKernel/_make/src/
   *.manifest keeps the manifests that link the file
   (Tiny_manifest.linking), runs each as linked with -summary, merges
   (dead_of_callers, as for Caller_finder's). -sources is found from the
   file: the manifest's TinyLibGUI.ml is the tree's tiny/TinyLibGUI.ml,
   so the build ran in a copy of tiny/ (tiny/TinyKernel for the
   kernel's). TinyLibGUI.ml: 1.4 s, the 2 lines of the merge, over calc,
   debug, emacs, office, play, temp, troff, www: play links GUI without
   naming it, which Caller_finder's name search missed, and gui
   (examples/gui.ml) is no program of the build. TinyOffice/Model.ml:
   office and troff; KFS.ml: the kernel. tiny_check.sh -dead checks
   TinyLibGUI.ml's lines against the merge's. Without manifests,
   Caller_finder as before. With it, lib_core's Procs says each program
   it runs (Logs.info, -v), as FS says a file read (the author: "btw,
   Logs.info should also print something when a program execute another
   program (just like we do print something when we open a file
   internally)"); mini-analyze's own two lines for it gone.
4. **mini-ml, mini-cc, mini-asm, mini-ar, mini-ld**: the record as a
   section of Asm's objects, the manifest beside each executable and the
   kernel. ix_check.sh, sweep.sh, kernel.sh on manifests; mk_units.sh
   and generated.sh go, and `make generated`.
5. **mini-analyze's flags** removed once no script uses them: -L, -own,
   -start, -summary, -program, -library; -I and -D if C without a
   manifest is not wanted.
6. **The derived tags as facts** (a program links a file; a file's
   role), for dead_all.dl and the other rules, instead of the scripts'
   greps.

Each step is checked by the recordings: the reports must not change,
except where a guess was wrong.

## Where the type goes

The author (2026-11-24): "not sure where the type of this manifest should
be declared. maybe in lib_code/ ? it would be shared by the different
tools. or under lib_executable ? not sure."

Proposed: **lib_executable/**. A manifest is what the linker writes
about one executable, beside it, as the symbol table and the pc/line
table it writes into it; lib_executable/ is where those are read back
(Symbols, Elf_file, Dwarf_line, Dwarf_info), by the debuggers today.
DWARF itself has the same thing: each compile unit's
DW_TAG_compile_unit says its source (DW_AT_name), the directory it was
compiled in (DW_AT_comp_dir) and the compiler (DW_AT_producer, where
gcc -grecord-gcc-switches puts the flags), what our compile record says.
So the writers (the compilers, mini-ar, mini-ld) and the readers
(mini-analyze, later the debuggers) depend on lib_executable/, which the
linker's tools and the debuggers already do.

lib_code/ is the other candidate: what is shared by the programs that
read code (Dominators, Liveness, Coloring, Highlight_code), algorithms
over a program, mini-analyze's side only. The manifest's writers are the
toolchain, which reads no code that way, and would depend on lib_code/
for one type.

The t-IX side is tiny/'s own copy, in **tiny/TinyLibExecutable.ml**
(the author: "yes let's to TinyLibManifest.ml or TinyLibExecutable.ml
maybe, and move stuff from TinyLibMachine.ml into it if needed"). Done
first, 2026-11-24, without the manifest: TinyLibMachine's objects,
archives and symbols moved there (to_object, of_object, plain, the
archives; labels, find, address), TinyLibMachine keeping the
instructions, the lines and their encoding. The two are lib_executable/
and the machine's code, as in m-ix; the manifest's type and its
to_manifest/of_manifest go beside to_object, which will carry the compile
records.

## To decide

- lib_executable/ (proposed above) or lib_code/ for the type.
- The type in tiny/ as a copy checked equal, or one file both trees read.
- The manifest always written, or only with a flag (-manifest, as
  -map): always is nothing to forget; its cost is one small file.
- The compile record inside the object, or beside it (x.o.json in
  clang -MJ's way): inside, an object copied keeps it.
- A test's kind: said by the build file (-kind test) or by its path.

## The scripts, smaller: one mini-analyze call over the builds

The author (2026-11-24): "anything we can do to further simplify
tiny_check.sh and make it easier to run the different analysis with not
too many flags while being precise? (moving stuff to the manifest
generation, or to datalog, or more)", then "ok I like this plan; let's
start and track the evolution of the size of tiny_check.sh (and maybe
ix_check.sh too)".

The aim: tiny_check.sh as three lines, t-IX's manifests made, one
mini-analyze call over both builds, the answer against the recording;
ix_check.sh the same after step 4. Each step below moves a part of the
scripts into mini-analyze, Datalog or the manifest generation.

- **A. The merge in mini-analyze and Datalog.** Every analysis's run
  writes its reports as -summary facts, not -dead's alone; a rule file
  per analysis says how programs combine (-dead: dead_all.dl, dead in
  every program that has the file; -bugs, -caps: the union; -exn: by
  program); a unit not read a fact, mini-analyze's failure. Several
  programs on the command line (manifests, .exe) are each run and
  merged, as dead_of_callers does for a library's file. Gone from the
  script: the said patterns, the "not read" grep, the second Datalog
  call, dead_lines.
- **B. Directories as arguments.** A directory of manifests (every one
  under it, the kernel's too), and a source directory, dune's
  executables under it (dune describe lists them). Gone: the program
  table, its k/h/b column, the Buildfile names.
- **C. Stand-ins for the externals mini-ml cannot parse.** tsdl.mli has
  polymorphic variants (67 backquotes), OCaml 5's domain.mli type !'a t:
  small interfaces of what ix uses (lib_core's Parallel uses
  Domain.spawn and Domain.t), as Models stands for List and Hashtbl.
  Gone: the 10 host runs of the old way, O for them.
- **D. tiny-kernel's capabilities.** Its system calls' externals mapped
  to capabilities, so -caps reads tiny-kernel's programs from their
  manifests. Gone: O.
- **E.** mini-analyze finding its rules from its own path, from any
  directory. Done (2026-11-25): its tree the first directory above its
  executable with analyzers/datalog (Sys.executable_name, bin/'s link
  followed), its rules and its lib_core (the library of none found)
  that tree's; no -r nor -L in the examples.

4a, mini-ld's manifests (2026-11-25): mini-ld -map writes out.manifest
too, tiny-ld's format (linker/Manifest, the same text as
TinyLibExecutable's, run.sh's check; Tiny_manifest's types equations to
it), each source a project path (type ppath = Ppath of string, osemgrep's
Ppath without its module: from the project's top, the same wherever the
tree and the build are; format 2). The author: "ideally we can have more
precise path that string", "not sure we want the full PPath.ml way". Its
-project (the top, else the first directory up with a dune-project, as
git finds its root) and -build (mkconfig's B, the tree mirrored: an
object or an archive in B/x was compiled in x/), mkconfig's LD passing
both. Not in the objects: make self compares the card's objects with the
host's byte for byte, and install.rc reads an archive's members' names
as sources from the library's directory (a first try, mini-ml naming its
objects' sources by their path in ix, broke both; a second, mini-ar
recording its directory in the archive, did not cover mkprog's LIBOBJS,
objects compiled elsewhere: both dropped). A source not there has none
(an installed library's). mini-analyze -sources renamed -project, by
default the project above the manifest; a unit the link did not take,
named for its types alone (troff's Rgba_image), its interface found in
the project; a command-line unit of the standard library's members'
directories is the library's (mkprog's std_exit). On a scratch build of
the 44 programs (41 built by mini-mk alone; oberon's and squeak's kernels
need make's kernel_stamp, singml's mkfile misses Annotations, as
mini-emacs's did in ad93e2ae): mini-analyze -caps on it reads 47
programs in 17 s, every report of caps_ix.txt and 42 more, the code the
mkfiles' -I made a library's (version_control's, lib_graphics' Cursor
and Display), and the linker's tools sweep.sh skipped. A full ix build
for the host: 283 s, 140 programs.

### The ledger

Lines (wc -l), at each step; the analyzer's: analyzers/Analyze.ml,
ml/, report/, manifest/'s .ml.

| step | commit | tiny_check.sh | ix_check.sh | compare.sh | mk_units.sh | generated.sh | analyzer |
|---|---|---:|---:|---:|---:|---:|---:|
| before the manifests | de9a26e5 | 166 | 95 | 89 | 124 | 37 | 3,968 |
| manifests, library mode | 8baebe50 | 212 | 95 | 89 | 124 | 37 | 4,494 |
| A, mini-analyze's part | 4ec6246f | 212 | 95 | 89 | 124 | 37 | 4,581 |
| A, tiny_check.sh's merge | bab77cc3 | 196 | 95 | 100 | 124 | 37 | 4,581 |
| C, interface alone; tiny-machine | 456676db | 197 | 95 | 100 | 124 | 37 | 4,632 |
| C, the SDL programs; tiny-mkfs | 5ea071c0 | 190 | 95 | 100 | 124 | 37 | 4,642 |
| B, directories; one call | a00edaaf | 76 | 95 | 92 | 124 | 37 | 4,786 |
| D, tiny-kernel's capabilities | 3152ebc6 | 69 | 95 | 92 | 124 | 37 | 4,786 |
| the library mode's test, toy programs | 52eb5894 | 56 | 95 | 92 | 124 | 37 | 4,804 |
| Analyze.ml split, 80 columns | c5c0ae77 | 56 | 95 | 92 | 124 | 37 | 4,940 |
| dune's executables by dune rules @dir/all | 9e216fac | 56 | 95 | 92 | 124 | 37 | 4,933 |
| a toplevel's global read (dead.dl) | e01478d6 | 56 | 95 | 92 | 124 | 37 | 4,940 |
| E, rules and lib_core from mini-analyze's tree | 7f84bdc0 | 56 | 95 | 92 | 124 | 37 | 4,974 |
| 4a, mini-ld's manifests, project paths | the next | 56 | 95 | 92 | 124 | 37 | 5,004 |

(D's lines are Datalog's, not the analyzer's OCaml: capabilities.dl,
420 to 488.)

A, mini-analyze's part (2026-11-24): the reports return their lines
(Caps_report, Exn_report, Bugs_report), every analysis's -summary has
them, said(Program, Line), and the units not read, unread(Program,
Message); merged_runs (dead_of_callers before) merges any analysis,
-dead by dead_all.dl, the others by datalog/said_all.dl (-bugs, -caps:
any program's; -exn: by program), an unread unit the merge's failure;
several programs on the command line (manifests, .exe, dune asked once)
each run and merged: mini-analyze -dead -sources tiny
tiny/TinyKernel/_make/src/*.manifest tiny/TinyKernel/_make/src/
TinyKernel/*.manifest, the 34 programs in 3 s. -sources, for several
manifests, is the shallowest one's directory's, a deeper one's below it
(tiny/TinyKernel for the kernel's). A .sources file the copy would have
held, naming tiny/, was tried and taken out (the author: "I'd rather not
add too many special files like .source which add some requirements on
mini-anlyzer and what external script or mkaefile must produce"). The
programs' list under a merge wrapped within 80 columns (callers/'s
expected.out). The scripts not yet changed: tiny_check.sh's
post-processing is the next part.

A, tiny_check.sh's merge: each run -summary for every analysis, a run
that fails said by its status (old: a grep of its output for "unbound
module|not read|syntax error|Fatal error"); one mini-datalog call,
dead_all.dl or said_all.dl (its queries added), for the four; the said
patterns gone, the recordings' names from the flag. compare.sh grew by
11: said_lines reads said_all.dl's answers, and exn_lines keys by
program when its lines are of several (by). So 16 lines less in
tiny_check.sh, 5 in all; the program table (B) is the big part. One
report new to caps_tiny.txt, recorded: Procs.spawn takes a capability
of no written type. It was there before, a kind of -caps line the old
pattern dropped; the merge keeps every line the report prints. (Its
caps annotated, it says what spawn reaches without one: Sys.getenv_opt,
the standard descriptors; left as written, analyses recorded, not
fixed.) The author on where such logic goes: "in general we should aim
to not abuse the use of scripts and shell wrappers over programs but
instead improve the ergonomy of those programs; the same is true for
the Buildfile/Makefile/... which should also remain simple and small".

C, first part (2026-11-24): no stand-in interface needed. A manifest's
library unit whose code mini-ml's dialect cannot read is read by its
interface alone, an external, decided when its callers ask (has_body),
before they are read, so the functions given to it count as called:
its file does not parse, or it names a unit that has no file, code or
interface (Module_finder.names, moved from Caller_finder for the .NET
road, a submodule's name, Fpath_.Operators's, no longer counted). lib_core's
Parallel on OCaml 5's Domain is one: tiny-machine by dune's manifest,
its report the old way's. Dune_manifest follows a copy's # 1 "file"
line (copy_files#: tiny/user/sdl/emacs.ml is tiny/user/emacs.ml). Left:
TinyLibSystem/sdl's lazy (mini-ml has none) made the SDL TinyLibSystem
its interface alone, every program's main escaping into it, nothing
dead: the 8 SDL programs and tiny-mkfs (KRaw, the SDL windows' memory)
kept the old way; the author: "let's commit and use a ref None for sdl
so we can also process those sdl progs".

C, done (2026-11-24): every host run of tiny_check.sh by dune's manifest.
TinyLibSystem/sdl kept to mini-ml's dialect, host-only as it is (the
author: "there is no support for include in mini-ml (or tiny-ml) so we
should try to avoid its use, even in parts that are host only like the
sdl, so it can be analyzed by the mini-analyer"): its two lazy values a
ref None and a function; include TinyLibSystemUnix replaced by its 56
values and 6 types said one by one (module U = TinyLibSystemUnix, type
stat = U.stat = {...}), a comment saying why; Unix.open_process_args_in
by pipe, create_process and waitpid, which lib_core's Unix has;
Option.value ~default a match. Smoke-run with SDL_VIDEODRIVER=dummy:
calc and www draw their screens. TinyMachineSDL (tsdl's polymorphic
variants) read by its interface. In the analyzer: a unit whose code
cannot be read, of the program's part too, by its interface; and a unit
a manifest links resolves to the file linked before the naming file's
own directory (the author: "we should use a manifest based approach so
we don't need those filename heuristic that sometimes fail"):
KGraphics.ml's KRaw was tiny/TinyKernel/KRaw.ml beside it, not the
host/KRaw.ml dune links, and 11 of host KRaw's functions looked dead.
caps_tiny.txt: 21 reports of TinyLibSystem/sdl recorded, read now for
the first time (getenv, the clock, exit, files without capabilities),
unix's dial's gone (said through the SDL programs read on unix's). O
left for -caps of tiny-kernel's 7 programs dune does not build (D).

B, done (2026-11-24): tiny_check.sh is t-IX's manifests made, one call,
mini-analyze FLAG -sources tiny $W/tix/src tiny, and the comparison;
the program table, its runs, the dune manifests' step, O, the Datalog
merge and the standalone Dune_manifest program gone (the author: "let's
commit and do 1 and 2, and let's wait for step D to restore the
programs. and 3."). mini-analyze takes directories: one of manifests,
each under it named by its path from it (build, TinyKernel/kernel.img);
another, dune's executables under it (dune describe workspace, describe
targets for an .exe, not tiny-machine-web's .bc.js; tests' directories
left out), named by their path (tiny/TinyShell). 55 programs: t-IX's 27
ML programs, the kernel's among them (tiny-cc's 7 not read, said), and
dune's 28, tiny-machine-window new. Needed on the way: dune describe
targets answers on its standard error (Procs.create_process_stderr); a
link with no standard library of the project's is on lib_core
(tiny-machine-window had TinyLibCore, the nearest); built_outside, the
constructors of a unit read by its interface alone (TinyMachineSDL's
events); TinyMachineWindow's Scanf by split_on_char; the walk skips .
and _ directories; the runs not given the directories; another dune
holding the kept build directory (make test's four analyses at once),
one of the run's, cleaned by dune clean. Recordings: -dead and -bugs
the same; -exn's programs renamed (tiny-build, tiny-build-host to build,
tiny/TinyBuildSystem), TinyMachineWindow's Failure new; -caps: unix's
seed, box, raw_console gone until D (tiny-kernel's 7 programs dune does
not build, read on unix's TinyLibSystem before), TinyMachineWindow's 4
new. -dead 6 s, -bugs 8, -exn 13, -caps 6, both builds.

D, done (2026-11-25): tiny-kernel's 30 calls (mlsys.c's, TinyLibSystem/
tinykernel's externals) in capabilities.dl's groups, as Unix's are
(u_open Cap.open_in, open_out or readdir; u_spawn exec and fork; u_trace
kill; u_flush stdout, print_string's buffer; u_write, u_read, u_seek...
on a descriptor held), TinyLibCore's ml_print_string stdout; a program's
first descriptors, numbers (TinyLibSystem.fd_stderr), authority where a
function gives one to the kernel (u_write, %identity's channel), not
where a program passes fd_mouse to TinyLibSystem.read; an external's
declaration not a use by its unit's init. So -caps reads t-IX's
manifests too, and tiny_check.sh has no -caps case left (O gone): its 7
programs back. caps_tiny.txt: 15 new, tinykernel's helpers of no
capability (names, entry, waits, said, main), the tracer's and
debugger's own u_trace, tiny-kernel's stubs (no signal, no environment,
an unbuffered stderr); unix's seed, box, raw_console stubs not said, no
program reading them on unix's TinyLibSystem. -caps 10 s.

The library mode's test out of tiny_check.sh (2026-11-25): it compared
mini-analyze -dead tiny/TinyLibGUI.ml over t-IX's manifests with the
merge's lines of the file, TinyLibGUI.ml the one tiny library with dead
code, which the author is to remove (the author: "I'm gonna fix soon all
those dead function, so we probably need an external test for this
instead"). analyzers/tests/callers/ has it instead, its toy library and
programs built by dune (callers/dune): -dead CallersLib.ml CallersA.exe
CallersB.exe, the answer of CallersLib.ml alone (Caller_finder's). The
library mode takes dune's .exe too, not tiny-ld's manifests alone.

Analyze.ml split by concern (2026-11-25; the author: "Analyze.ml is also
far too long, especially its main function is incomprehensible", "its
help also far too long", the dune code "in a separate module ... or
inside Dune_manifest.ml itself"): Analyze_flags, the command line as one
record; Analyze_one, one program by its files (its rules, facts, report,
-flow); Analyze_merge, -summary's facts and the merged runs;
Analyze_build, programs by their build (directories, manifests, .exe,
the library mode, several programs); Analyze, the flags and the
dispatch, 130 lines (773 before, main 410); Dune_manifest.write, the
runs' manifest files. The help 16 lines and the flags' (95 before), the
man page saying the rest. Unit_finder renamed Module_finder (the author:
"In the past I use Unit_xxx for unit testing modules"). The 136 more
lines are the 80 columns' wrapping and the new modules' headers.

A directory's dune executables by their links, dune rules @dir/all
(2026-11-25): the links of what dune builds there, an .exe's, not a js
stanza's .bc.js; dune describe workspace's stanzas and dune describe
targets, on its standard error, gone (Dune_manifest 355 to 332 lines).
The same 28 programs under tiny/. Procs.create_process_stderr stays:
another dune holding the build directory is said on dune's standard
error alone. The author asked whether @dir/all is t-IX's: no, dune's
alias of every project, dir the one given. Two bugs found trying it from
a subdirectory, older than it: the executables were said from the
project's root, which dune does not read its targets from (now from the
current directory, describe saying the root); and a merge's runs were
given the command line without its words naming a directory, taken for
programs, -r datalog's datalog among them (now the flags alone, Arg's
place of each word read as a program or a file).
