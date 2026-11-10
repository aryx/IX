# Plan: TinyLibMachine.ml, tiny-machine's libmach, and tiny-c and tiny-ml writing their objects

Status: **done (2026-11-10): stage 1, TinyLibMachine.ml, parse in TinyAssembler.ml; stages 2 to 4, the compilers write objects (their text by -S), the docs with them.**
Written 2026-11-10, after the author's questions: "I think TinyAssembler
and TinyLinker are relying on modules under TinyMachine/ and this seems
to be inconsistent with the other TinyXxx/ which are used just by the
TinyXxx.ml. Should we move those files out of TinyMachine/ in a
TinyLibMachine.ml or something? ... actually plan 9 has a libmach/ I
think for that purpose"; then: "I wonder if it would make sense to have
a single TinyLibMachine.ml. Also do tiny-ml and tiny-c really need to
depend on TinyMachineAsm? do they need to parse assembly? I feel like
some of this code should go to TinyAssembler instead. Maybe Tiny-ml and
tiny-c could directly generate the object? (like mini-cc does)"; and:
"yes, write the plan".

Companions: [`done/plan_tiny_one_system.md`](done/plan_tiny_one_system.md), whose
stage 0 (the move to `tiny/TinyLibSystem.mli` and `TinyLibSystem/`)
comes first, so that `self.expected` is recorded once for both moves;
`languages/c/Emit.mli`, mini-cc's object, which this plan follows.

## Context

`tiny/TinyMachine/` is the parts of TinyMachine.ml (tiny-machine) and
TinyCPU.ml (tiny-cpu), as `TinyC/` is TinyC.ml's. But two of its
modules are not the machine's: the whole toolchain stands on them.

| module | what it is | used outside TinyMachine/ by |
|---|---|---|
| `TinyMachineISA` (224 lines) | the instructions, their words (encode, decode, the one printer), the object's items, marshalled | TinyAssembler, TinyLinker, tiny-c (`TinyCMachine`), tiny-ml (`TinyMLTree`, `TinyMLMachine`), TinyDebugger (its disassembly), TinyCPU, TinyMachine |
| `TinyMachineAsm` (325 lines) | the typed lines of assembly: the type, `print` (lines 1-86), `parse` (lines 87-325) | `parse`: TinyAssembler alone; the type and `print`: tiny-c and tiny-ml (about 100 constructors), TinyAssembler |

The others are the machine's: `TinyMachineCPU` (TinyCPU, TinyMachine),
`TinyMachineDevices`, `TinyMachinePeer`, and the programs beside it
(`SDL`, `Socket`, `Window`, `Web`, `Fetch`). Two small uses from
outside are left as they are: the palette, `TinyMachineDevices.colours`,
in the host's TinyMemory and the SDL window (both show the machine's
screen); `TinyMachinePeer` in the SDL window (which answers port 70 as
the machine's peer does).

And tiny-c and tiny-ml make typed lines of assembly, then print them as
text, which tiny-assembler parses back into the same lines to encode
them: a round trip through text for every unit, and a parser linked
into nothing but the assembler. On tiny-kernel it costs most: its `as`
took 4 minutes on the kernel's 70,000 lines before the kernel was
compiled by unit (cddf43fa), and every unit of every program goes
through it in `make self`.

What the others do:

- **Plan 9**: 5c writes an object of instructions not yet encoded, 5l
  encodes them; 5a is for assembly written by hand. libmach has what
  the machine-dependent tools share: the instructions' decoding (db's
  and acid's disassembly), the executables' format, the symbol tables.
- **m-ix**: mini-cc writes mini-asm's `Asm.obj` (`languages/c/Emit.mli`:
  "the compiler produces what the assembler would, and mini-ld encodes
  both"), with `-S` for the listing.

## Goal

- **`tiny/TinyLibMachine.ml`**, one file, tiny-machine's libmach: the
  instructions and their words (today's ISA), the typed lines of
  assembly and their printer (Asm but `parse`), lines encoded into an
  object (today's `TinyAssembler.encode`), objects marshalled. About
  550 lines, under the 700 where tiny/ splits a module.
- **`parse` in TinyAssembler.ml**, the one program that reads assembly
  text: the hand-written `.tm` files (entry.tm, draw.tm, memory.tm,
  end.tm, the C runtime's start.tm and udivmod.tm, the steps).
- **tiny-c and tiny-ml write objects**: their lines encoded by
  TinyLibMachine and marshalled, no text between; `-S`
  still prints the assembly, for reading and for the tests that compare
  it.
- **`TinyMachine/`** the machine's alone: CPU, devices, peer, and the
  programs beside it.

## Stages

Each builds and passes the checks alone, and is a commit.

1. **One file.** TinyMachineISA.ml and TinyMachineAsm.ml (but `parse`)
   become `tiny/TinyLibMachine.ml` (and its `.mli`, telling the
   pipeline: instructions, lines, object); `parse` and its helpers
   (`halves`, `arg`, `instruction`, `directive`...) go to
   TinyAssembler.ml. The constructors' clash is settled (question 1).
   The callers' aliases change (`module ISA = TinyMachineISA` and
   `module Asm = TinyMachineAsm` become `module M = TinyLibMachine`, or
   both aliases of it); dune's `tiny_machine_cpu` splits (a library
   `tiny_lib_machine` at tiny/, `TinyMachineCPU` left in TinyMachine/);
   tiny/mkfile, TinyKernel/Makefile's `F_` and `I_`, compile_ix.sh, the
   code map's configs, the docs. `TinyMachineAsm_tests` (parse after
   print gives the lines back) follows parse into TinyAssembler's tests.
2. **The encoding shared.** `TinyAssembler.encode` (lines to an
   object, the relocations of what a file cannot know) moves into
   TinyLibMachine as `assemble : line list -> obj`; TinyAssembler is
   then read, parse, assemble, write.
3. **The compilers write objects.** tiny-c and tiny-ml: `-o x.o`
   writes the object (`assemble`, then marshalled), `-S`
   the text (question 3); TinyKernel/Makefile's and the Buildfile's
   units go from source to object in one step (`ml -c -o ml/X.o`, its
   `.tmi` beside), the `as` step left for the hand-written files; the
   tests' scripts (`link_tm` and its kin) where they assemble a
   compiler's output.
4. **The docs**: tiny/README.md (the toolchain's entry, the file
   rules), docs/manuals/t-ix.md (how a program is built), the
   compilers' `-h` (their examples assemble each `.tm`).

## Questions to decide

Decided by the author, 2026-11-10: 1, one type; 2, TinyLibSymbols in
TinyLibMachine.ml; 3, by `-S` alone, as mini-cc and 5c (objects by
default, `-o` only naming the file); 4, "tiny-object 3".

1. **The constructors' clash.** tiny-ml has one constructor name space
   per program, and the two types share `Label`, `Align`, `Space`,
   `Piece`, `SectionCode`, `SectionData` (and `Word`, with ISA's
   `place`): one module cannot hold both as they are.
   - **One type** (proposed): an object is lines already encoded, the
     `line` type with one more constructor, `Chunk of string * reloc
     list` (a piece of code's bytes and what goes in them); an object
     holds only `Label`, `Align`, `Space`, `Chunk`, `Piece` and the
     sections. One type, as mini-asm's `Asm.obj` serves mini-cc and
     mini-asm; the cost, the type no longer says an object holds no
     instruction not encoded, which tiny-linker then refuses when it
     reads one.
   - Two types, the object's constructors renamed (`Obj_label`...):
     the guarantee kept, a prefix on each.
2. **TinyLibSymbols in it?** libmach has the symbol tables too, and
   TinyLibSymbols.ml (69 lines: a program's labels, for tiny-prof and
   debug) is that; proposed: in TinyLibMachine.ml, about 620 lines then,
   one library fewer.
3. **How a compiler says which output**: by `-o`'s suffix (`.o` the
   object, `.tm` the text: one flag less, as `-o` already names the
   file) or by `-S` (as mini-cc and 5c). Proposed: the suffix, `-S`
   kept as `-o x.tm`'s name for when there is no `-o`.
4. **The object's magic**: the format's content does not change (the
   items marshalled), but with one type it is the lines' type that is
   marshalled: "tiny-object 3", the linker refusing a "tiny-object 2"
   with a message to rebuild.

## Checks, at each stage

`dune build`; `make test-tix` (TinyC_test.sh's programs and
languages/ml/tests/tiny/'s outputs the same); the objects compared
byte for byte with today's, before and after stages 1-3, for the
library, the kernel's units and every program (the image's
`kernel.img` and `bin/*` the same bytes: the encoding does not change,
only where it runs); `tiny_check.sh -bugs -caps -dead`; mini-mk in
tiny/; `make -C tiny/TinyKernel check`; `make self-quick-tix`; `make
self` at the end (its output's lines change: no `as` for a compiled
unit; recorded after a look).

## Size, estimated

TinyLibMachine.ml about 550 lines (620 with the symbols) from ISA's
224, Asm's 86 and TinyAssembler's encode, about 90; TinyAssembler.ml
161 + 240 (parse) − 90; the compilers a few lines each (the object
written); the build rules shorter (one step per unit, not two). About
the same lines, one module and one text round trip fewer.

## Status

Stage 1, 2026-11-10: `tiny/TinyLibMachine.ml` and `.mli` (old:
`TinyMachine/TinyMachineISA`, `TinyMachineAsm` but its parse, and
`TinyLibSymbols`), one type for the lines and the objects (`Chunk`
added), "tiny-object 3"; constructors and values renamed where the
merge made two of a name in one module: the line `Branch` is
`Branch_to`, the place `Word` is `Full`, the listing `print` is
`listing`, the line's `print` is `print_line`, `show_item` is
`show_line`. `parse` in TinyAssembler.ml, with `-S`, the lines read
printed again; `TinyMachineAsm_test.sh` and its `Law.ml` become
`TinyAssembler_test.sh`, the law end to end: a file's `-S` text
assembles to the same object, and prints the same again. For that
law, a `.word a, b` line's words are a chunk each (old: one chunk:
the object then depended on the text's layout; the images are the
same bytes). One alias, `module M = TinyLibMachine`, where the callers
had `ISA` and `Asm`. Checked: the kernel and the programs that do not
link TinyLibMachine the same bytes as before (`as`, `ld`, `cc`, `ml`,
`prof` and `debug` link it: other code, the same checks pass); dune;
`make test-tix`; `tiny_check.sh` (`dead_tiny.txt`: `address`, now
TinyLibMachine's, recorded); mini-mk; the kernel's check (its
toolchain session compiles `TinyLibMachine.ml` on tiny-kernel, the
host's bytes) and self-quick, in `_make2`.

Stages 2 to 4, 2026-11-10, the author's choice after a look at what
the text step gave (the pipeline seen, gcc's way) and what it cost:
`encode_line` and `assemble` in TinyLibMachine (old: TinyAssembler's
`item` and its loop); tiny-assembler for assembly written by hand
(entry.tm, start.tm, the steps, the tests). tiny-c and tiny-ml write
objects, `-S` their text (tiny-ml's `TinyMLMachine` keeps lines, not
two buffers of text; its `start` lines); without `-o`, `x.o` beside
(a whole program of tiny-ml's after its first `.ml`, `main.o` when
it has none; `-S` on stdout). A line the compilers make that cannot be
encoded is said with the file (mini-analyze -exn found it escaping).
li's number read signed before choosing one instruction or two, as
its text was (old: tiny-c's `0xfffffff0` was `-16` in the text, one
`addi`; the direct line saw a big number, `lui` and `ori`). List.map
a loop, as mapi (the compilers map over a unit's lines on tiny-kernel).
TinyKernel/Makefile and its Buildfile: a unit, a main, the library, a
C file go to their `.o` in one step, `as` for the `.tm` written by
hand; the tests' scripts (`link.sh`'s `ml_lib`, each test's objects;
TinyAssembler_test.sh's law on the compilers' `-S` text); lite.sh's
"t-ix built in tiny-kernel". The toolchain session of the kernel's
check: `ml -c` the host's object and interface, `ml -S` then `as`
the same object. Checked: the images the same bytes as before (with
List.map as it was: `kernel.img` and every program but the six
linking TinyLibMachine), each C file and every library module the
same object by both roads; dune; `make test-tix`; `tiny_check.sh`
(-exn's two found, handled); mini-mk; the kernel's check
(`check.expected`'s toolchain lines, `debug.cksum`: two registers of
the debugged program, its layout moved by List.map) and self-quick
(its expected lines: no `as` for a compiled file), in `_make3`.
