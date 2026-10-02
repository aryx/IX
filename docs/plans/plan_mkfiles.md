# Plan: ix built by ix, with mkfiles

Companion of [`plan_ml_bootstrap.md`](plan_ml_bootstrap.md) (goal 2:
mini-ml compiles ix) and [`plan_lex_yacc.md`](plan_lex_yacc.md) (step
4: the programs linked and run). Every file of ix compiles alone by
mini-ml; here the programs are made, by ix's own tools, and run. The
author (2026-10-02): "I was planning actually to make install so the
mini-xxx binaries are in the PATH, and then write assembler/mkfile
that calls mini-ml, mini-lex, etc.", "so we also dogfood mini-mk".

## What a program's build is

1. the C library: goken's libc, each file by mini-cc or mini-asm, the
   archive by mini-ld;
2. mini-ml's runtime, `runtime.c`, by mini-cc;
3. the stdlib and ix's library (`lib_core/`), each unit by mini-ml;
4. the program's units: mini-lex and mini-yacc on its `.mll` and
   `.mly`, then mini-ml on each `.ml`;
5. the start object, `mini-ml -start` with the units in the order they
   are initialized;
6. the link, by mini-ld.

Everything is ix's but the machine under it: the C library's sources
are in `lib_core/libc/` (goken's, copied: step 1b), and nothing of
`~/goken` is run or read by the build. The tests still compare ix's
tools with goken's, their reference.

## Decisions

1. **mini-mk runs it**, with the installed programs: `make install`
   (dune's, into opam's bin), or `PATH=$PWD/bin:$PATH`.
2. **`mkfiles/`**, as xix's: `mkconfig` (the machine, the tools, the
   stdlib's units in their order) and `mkprog` (a program's rules). A
   directory's `mkfile` says its units, in order, by hand: it is what a
   mkfile is for, and it says what the program is made of.
3. **What is made is under `_mk/$O/`**, a directory a program, not
   beside the sources as Plan 9 does: dune reads the source directories
   too, and would take a generated `Parser.ml` for a source. dune skips
   `_mk` (a name with `_`); it is in `.gitignore`.
4. **The whole stdlib is linked**, each of its units initialized: a
   program's mkfile doesn't say which it needs (mini-asm is 816 KB so).
   mini-ld leaving out the units nothing names is for later.
5. **A unit is remade when any source of its directory changes**:
   mini-ml reads the other units' interfaces from their sources, and a
   directory is a second to compile. Exact dependencies (`mini-ml -M`)
   later, if it is felt.
6. **The contract: the program dune builds.** A program made by ix's
   tools gives the same bytes as dune's on the same inputs
   (`mkfiles/check.sh`).

## Steps

1. `lib_core/mkfile` and `assembler/mkfile`: mini-asm. **Done**
   (2026-10-02): `mini-mk` from nothing makes the C library, the
   runtime, 53 units of the stdlib and of ix's library, and mini-asm,
   in 12 s; that mini-asm writes the same objects as dune's on goken's
   31 arm and arm64 `.s` files, and the hello it assembles runs.
1b. **No `~/goken` in the build. Done** (2026-10-02). The author:
   "Next step is removing the dependency to ~/goken", "let's copy (and
   trim later)", and, of the header first put on each file, "maybe a
   README.md would be enough? which would remove the need for those
   boilerplate header comments, and also allow to use diff tool to see
   the diff between the ocaml stdlib and ours, same for goken libc and
   ours".
   - `lib_core/libc/`: the 75 sources and 45 headers of goken's libc
     that a program of mini-ml's links (of its 139 objects, mini-ld
     takes 67 on arm64 and 70 on arm), as they are, to the byte; their
     origin and license in `lib_core/libc/README.md` and `LICENSE`.
     `lib_core/README.md` says the same of the stdlib (ocaml-light's).
     `lib_core/diff_goken_libc.sh` and `diff_ocaml_stdlib.sh` (the
     author's names) say, shorter than a diff, each file changed, each
     new one and what of the origin is not taken: libc's 120 are
     goken's, 233 of its sources not taken; of the stdlib's, 29 are
     ocaml-light's, 45 changed, 24 new, 5 not taken.
   - `lib_core/mkfile` lists the files and makes `libc.a` with mini-cc,
     mini-asm and mini-ar; `mini-mk` from nothing is 8 s, with only
     ix's programs in the PATH; `mini-mk O=5` makes arm's, which runs
     under qemu-arm.
   - **mini-ar** (`linker/tools/`, as xix's and principia's; the
     author: "we might want a separate mini-ar? just to be more
     familiar with traditional tooling"): ar's command line (`mini-ar
     u lib.a objects`, `t`, `v`), not its file ("mini-ar does not have
     to follow the plan9 format I think; mini-ld does not"): a library
     stays ix's, a marshalled value. `mini-ld -a` is gone.
2. mini-ld (`linker/`, with `assembler/`'s units), then mini-cc
   (`languages/c/`: its grammar by mini-yacc), mini-chidb (`database/`:
   mini-lex and mini-yacc), mini-mk, mini-rc, mini-ed.
   **mini-ld, mini-ar and mini-cc done** (2026-10-02), each against
   dune's (`mkfiles/check.sh`): mini-ld links mini-asm itself (816 KB)
   to the same bytes, in 8 s where dune's takes 4 (300 MB against 127);
   mini-cc, its parser by mini-yacc, gives the same listings and trees
   on the C library's 134 files and the same objects on arm64. What it
   took:
   - mkprog: a parser and a lexer made under `_mk/`; a unit of a
     subdirectory (`compat/Follow`) and a generated one have a rule by
     their name, for mk refuses a second rule with `%` for every unit.
   - `-nofollow` at the link: mini-cc is 1 MB of code, and laid along
     its flow (5l's way, `linker/compat/`) a conditional branch is
     farther than it reaches ("branch too far").
   - The runtime's heap: 512 MB a half on 64 bits (it was 64, and the
     link of mini-asm died at it).
   - Three differences between OCaml's stdlib and ix's, each found by a
     wrong output and now a test (`bugs/ocaml_light.md`, 8): a
     function given to `List.concat_map` and `List.init` was called on
     the elements backward (mini-ld took a function's frame from the
     next one); `Printf.sprintf "R%d"` used twice lost its `R`
     (mini-cc's `[R4,5]`).
   - A table's order is its hash function's: mini-cc's `-O` gave
     registers in `Hashtbl.fold`'s order, not the same by the two
     stdlibs; sorted now.
   - Not the same bytes, and left so: an object is a marshalled value,
     and OCaml makes one block of a constant written in the code
     (`[R4; R5]`, `Reg 0`) where mini-ml builds it each time, so some
     of mini-cc's arm objects say fewer blocks shared. The value is
     the same (the listings are). Left so (the author: "I would leave
     it"); constants as static blocks in mini-ml would be an
     optimization, for later.
   **mini-chidb, mini-mk, mini-rc and mini-ed done** (2026-10-02):
   each program's own differential test, with dune's build in the
   reference's place: mini-chidb's 6 SQL sessions (output, errors, the
   database's bytes), mini-mk's 35 mkfiles, mini-ed's 45 scripts,
   mini-rc's 44. So `Unix` (fork, exec, pipes, wait, dup) holds
   under real programs, and mini-lex's lexer with mini-yacc's parser
   in one. The runtime gained a channel's size and seeks
   (`in_channel_length`, `seek_in`, `input_binary_int`).
   **Signal handlers done** (2026-10-02; mini-rc's `sigint` case
   wanted them, mini-ed too for an interrupt and a hangup). The C
   handler only notes the signal (`ml_signal`, set without SA_RESTART
   so that a call interrupted says so); the handlers are OCaml's, kept
   in the stdlib under the system's number (`Sys.signal`, which gives
   back the behavior before, as OCaml's) and run by
   `Pervasives.run_signals` where a program waits: a read of a channel
   (`input_char`, `input`, `input_line`, asked again after the handler
   unless it raised, so `Sys.Break` comes out of a read), a system
   call of `Unix` interrupted (the handler, then `EINTR`), and
   `Unix.kill` to oneself. Not anywhere in a computation, as OCaml
   does at an allocation: a loop that asks nothing of the system is
   not interrupted; so a second interrupt, the first one's handler not
   run yet, ends the program (exit 130). `tests/modern/signals.ml`, the same as OCaml's on
   arm64 (goken's libc) and on arm with gcc's.
3. mini-lex, mini-yacc and mini-ml themselves; then the fixed point:
   ix's tools built by themselves build the same tools again.
   **Done** (2026-10-02). Three mkfiles more (`generators/lex`,
   `generators/yacc`, `languages/ml`: the front end, `pp/`, and the
   four back ends), so mini-ml compiles mini-ml. `mkfiles/fixpoint.sh`
   builds ix twice from nothing: by dune's programs, then by the eleven
   programs of that first build alone (mini-asm, mini-ar, mini-ld,
   mini-cc, mini-lex, mini-yacc, mini-ml, mini-mk, mini-rc, mini-ed,
   mini-chidb). The two builds are the same 262 files, to the byte:
   objects, the C library, the lexers and parsers written, programs.
   About 5 minutes (1 for the first build, 3 for the second: mini-ml's
   code is slower than ocamlopt's; mini-ld by mini-ml links mini-cc in
   18 s). What it took:
   - the stack: mini-ml's code takes 32 bytes of it for a call,
     ocamlopt's 16, and Linux gives 8 MB; a function that calls itself
     for each element of a list stops near 260,000 elements, with a
     segmentation fault. The linker's instructions are that many for
     mini-cc: `List.concat_map` is now OCaml 4.14's (no call for each
     element), and `Link.load` no longer does `t.progs @ ...`;
   - `String.escaped` and `Char.escaped` write `\r` and `\b` as OCaml
     4.14's (ocaml-light's wrote `\013`, `\008`): mini-lex writes its
     character sets with `%S`, and the lexer written differed (the
     object made from it did not);
   - `ssa/Alloc` gave the slots in a table's order, so by the stdlib's
     hash function: in the values' order now (`-ssa` is not what the
     mkfiles use; found by reading, as mini-cc's `-O` before).
   **The other programs** (2026-10-02, after the fixed point):
   - mini-5i (`machine/mkfile`): on random blocks of instructions, as
     the real CPU for arm and arm64's integers (300 blocks each); the
     floats differ by `sqrt` (bugs/ix.md).
   - mini-git, mini-diff, mini-merge3 (`version_control/mkfile`: one
     set of units, three mains; SHA-1 and zlib compiled there): the
     query, session, git9 and net tests pass, and the diff fuzzer. The
     runtime gained `Sys.chdir` and `Sys.time`.
   - the 13 tiny programs (`tiny/mkfile`): all build; the tests of
     tiny-assembler, tiny-build, tiny-shell, tiny-editor, tiny-db,
     tiny-arm and tiny-pi pass, those of tiny-vcs, tiny-cpu, tiny-c,
     tiny-ml and tiny-machine do not yet (bugs/ix.md: to look at).
   - each test takes the program to test from its environment (`T`,
     `TD`, `MINI5I`...), dune's by default.
   Left: mini-qemu (its `Main` needs SDL), the kernels (bare metal).
4. On arm (`O=5`), under mini-5i.
   **The floats** (2026-10-02): what stopped a program of mini-ml's on
   arm with ix's own toolchain. mini-ld encoded 5c's floating point for
   FPA, as 5l does by default: instructions no arm processor has, and
   that Linux no longer emulates (Plan 9's kernel does: that is how
   its programs run without `-f`). Now VFP's, as `5l -f`, and only
   that (the author: "let's support only VFP here"): `linker/Arm`'s
   FPA encoder replaced (its lines kept in an `old:` comment), a float
   constant always in the data, a comparison and a conversion two
   instructions. The same bytes as `5l -f` on the linker's 39 arm
   fixtures (`golden.sh`, recorded again; the one of FPA's immediates
   removed) and on goken's 17 libc programs. `tests/modern/` on arm
   (`run.sh 5`, under qemu-arm): all pass but `marshalled`, whose
   expected integers have 63 bits; `floats`, `unix_calls`, `files`,
   `signals` did not before. The square root is VFP's too (the start
   object's `ml_fsqrt`, the instruction by its word).
   **`mini-mk O=5`** (2026-10-02): the 15 mini programs and the 13
   tiny ones built for arm, by ix's tools. Four functions of ix had 8
   or 9 parameters, and mini-ml on arm has registers for 7: two of
   each grouped in a pair (`Mkfile.add_rules`, `Arm64.bitfield`,
   mini-cc's `compile`), a flag for the fourth (mini-ld's `-v`); the
   error now says what to do. Under qemu-arm:
   - mini-rc 44, mini-ed 45, mini-mk 35, mini-chidb 6: their
     differential tests as dune's, all of them;
   - mini-cc and mini-ml on arm write the same assembly as on arm64
     (the runtime's 8,025 lines of listing, `List`'s 9,844);
   - mini-asm and mini-ld did not: an image's first word was
     `553800a0` for `d53800a0`. An int has 31 bits for a 32-bit
     program, and the linker made its instruction words in ints.
   **The linker's words are int32** (the author: "use Int32 and
   rewrite"). In `linker/Arm` and `linker/Arm64`, from the encoders to
   the file's end, `lsl` puts a field (an int) at its bit and gives an
   int32, `lor` joins words: the two operators redefined there, so the
   390 shifts of the encoders read as before; a bare field is `word
   r`, a whole word an int32 literal, an int's shift `shl`. An arm
   constant's 32 bits are read from the operand as an int32 (`immrot`
   takes one); a single float's bits are made in an int64. Then, with
   mini-asm and mini-ld built for arm, under qemu-arm:
   - the linker's recorded executables: 59 of 62 the same; the three
     others are Mach-O's, whose text is at 4 GB;
   - mini-asm for arm (800 KB), linked from the same objects: the same
     executable as the 64-bit linker's.
   The first try of ix for arm built again by its arm-built tools
   stopped at mini-ld linking itself, out of memory: a 32-bit
   program's heap was 32 MB a half; now 256. That second build is to
   run again (to do).
   **What a 32-bit linker still cannot**: an address and a size are
   ints, so under 1 GB there. Mach-O's addresses are above; and a
   program of mini-ml's for arm64 has a bss of 1.1 GB (its heap's two
   halves), so linked on arm its sizes come out wrong. Programs for
   arm (a heap of 64 MB) link right.
   Left: under mini-5i.
5. An optimization phase: now
   [`plan_mini_toolchain_optimization.md`](plan_mini_toolchain_optimization.md),
   its target mini-xv6's numbers. What was noted here: mini-ml's code is
   slower than ocamlopt's (the fixed point's second build takes 3
   minutes, the first 1; mini-ld by mini-ml links mini-cc in 18 s), a
   call takes twice the stack, the parsers' tables are not compacted.
   Then ix built by ix on its own kernels.

## Found on the way

- mk gives the name `X` for `${X:%=-I %}` when X is empty or not set
  (goken's mk too): a mkfile says `LIBI=` whole.
- An object is a marshalled value, and OCaml shares the blocks of a
  unit's equal literals (two `0L` are one block): mini-ml had a block
  for each, so two of 31 objects had 6 bytes more. mini-ml now shares a
  unit's float, int32 and int64 literals of one value, as it did
  strings.
