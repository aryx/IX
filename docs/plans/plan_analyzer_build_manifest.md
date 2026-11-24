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
tiny-ld-only version). Next: mini-analyze reading it.**

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
| Unit_finder, Caller_finder | guesses of the same, from names and directories | 240 + 139 |

and as flags: -L (the standard library), -I (an ML library's directory or
a C include), -own (whose units are reported on, and the platform's
implementation of TinyLibSystem), -D, -start (the order the units start
in), -library (every function an entry), -summary and -program (the
merge of several programs).

Every one of these facts is known exactly, at one moment, by one tool of
the build: the compiler knows the source it read and its flags, the
linker knows which objects it took (archive members included) and in
which order. Unit_finder had to guess the rest, and on a tie it warns
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
- **Unit_finder's guessing and its tie warnings**, Caller_finder's
  search for mains, when manifests are given: the manifests list the
  programs. Both stay for a checkout with nothing built (the author:
  "maybe the mini-analyzer could keep those Caller_finder.ml,
  Unit_finder.ml so one can also call mini-analyzer on a fresh repo
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
- **generated.sh, `make generated`, Unit_finder.generated**: a generated
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
3. **dune**: the describe reader writes the host's manifests;
   tiny_check.sh's host runs (h and b) read them; the table goes.
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
