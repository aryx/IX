(* A tiny assembler for arm64 that also writes the executable, all in
 * one file.
 *
 * mini-asm and mini-ld (in assembler/ and linker/) follow Plan 9's
 * split faithfully: an assembler that only parses the source into
 * objects, and a linker that loads those objects and their libraries,
 * lays them out and encodes them, choosing for each instruction the
 * same form 7l would, byte for byte. This file is what remains when
 * there is no separate compilation: it reads all the assembly of a
 * program at once, both the program's own and its libc's (7c -S
 * output and libc's .s files), and writes the ELF executable. Its
 * usage, by examples, is in [help] below (what tiny-assembler -h
 * prints).
 *
 * Note that, despite its name, this is not the assembler for
 * tiny-machine. The .tm files that tiny-cpu and tiny-machine run are
 * assembled by TinyMachine/TinyMachineCPU.ml (see its [assemble]),
 * next to the definition of that machine's instruction set.
 *
 * There are two assemblers because there are two unrelated machines.
 * This one targets arm64, a real CPU: its input comes from real
 * compilers (7c -S, and the arm64 back ends of tiny-c and tiny-ml),
 * and its output runs on Linux, mini-5i, and tiny-arm (TinyCPUArm).
 * It is the tiny version of mini-asm and mini-ld. tiny-cpu, on the
 * other hand, is a machine we designed ourselves, so its assembler
 * lives with its definition; it is also much simpler (one instruction
 * format, no executable header), so it needs only two passes. The
 * "Tiny" in TinyAssembler means a tiny version of a real toolchain,
 * not a toolchain for the tiny machine.
 *
 *     file.s ...                the passes, one after the other
 *        | lex, parse    turn lines into items: a TEXT, an instruction
 *        |               with its operands, a DATA, a GLOBL
 *        | gather        group items: a function is the instructions
 *        |               of its TEXT; a data symbol is its size and
 *        |               its DATAs
 *        | reach         find the names reachable from the entry,
 *        |               through code and data; everything else is
 *        |               left out of the executable
 *        | expand        turn each instruction into its words, each a
 *        |               function of its own pc: all sizes are known
 *        |               after this pass
 *        | lay out       place the text, the data and the bss: all
 *        |               addresses are known after this pass
 *        | encode        call each word's function with its address
 *     a.out
 *
 * The file that is written is also the memory image of the running
 * program, since the file is loaded whole at 0x400000:
 *
 *     0x400000   the ELF header (64 bytes) and its one program
 *                header (56 bytes)
 *     0x400078   the text: the reachable functions, in the order of
 *                their files
 *     setSB      the data, 16-aligned after the text, with one symbol
 *                every 8 bytes
 *     edata      the bss: counted in the memory size, not in the file
 *     end
 *
 * An example of a size known from the operands alone:
 *   MOV $0x12345678, R1
 * is always two words, whatever surrounds it: a MOVZ of 0x5678 and a
 * MOVK of 0x1234 at bit 16. (movconst emits one word for each 16-bit
 * chunk that is not zero, or, when most chunks are all ones, for each
 * chunk that is not all ones, after a MOVN.) 7l instead puts the
 * constant in a pool after the function and loads it from there, and
 * the form of that load depends on how far away the pool ends up.
 *
 * What makes it small, while still being a real toolchain:
 *
 * - {b Every size is known before any address.} The expansion of an
 *   instruction depends only on its operands, never on where things
 *   end up: a constant is built by MOVZ, MOVK or MOVN (up to four
 *   instructions), an address by a pc-relative ADRP and ADD (and a
 *   load of a global by ADRP, ADD and the load), and a logical
 *   immediate is first put in a register. So there is no literal pool,
 *   no bitmask encoder, no relaxation, and no second guess: expand,
 *   then lay out, then encode, one pass each. The executable is about
 *   the size of 7l's: where 7l loads from a pool, we build the value
 *   inline, but we have no pool words (hello with libc is 27,328 bytes
 *   here, against 27,606 with 7l).
 * - {b Each word of the encoding is a closure}: each instruction
 *   becomes a list of functions from their own pc to 32 bits, which
 *   are called once every address is known. This is Plan 9's idea
 *   (encode in the linker, when addresses are known), with the linker
 *   and the assembler merged into one program, so the object files in
 *   between disappear.
 * - {b A library contributes only its reachable functions.} What an
 *   archive's index does (pull in the objects that define the
 *   undefined names), a walk from the entry does here, at the
 *   granularity of single functions and data. The executable contains
 *   exactly what the program uses. When a name is defined twice, the
 *   first definition wins (fmt's strtod before port's, as with ar). A
 *   name<> is private to its file.
 * - {b The stack frames follow 7l's conventions}, because the code of
 *   7c relies on them: the frame is 16-aligned, with R30 at its
 *   bottom, and pushed by a pre-indexed store; a leaf function without
 *   locals makes no frame; RETURN undoes it. n+8(FP) refers to the
 *   caller's frame, x-8(SP) to the current one.
 * - {b The file is an ELF with a single segment}: the header, the text
 *   and the data in one read-write-execute PT_LOAD, followed by the
 *   bss. There are no sections.
 *
 * The supported instructions are those that 7c emits and that libc's
 * .s files use: MOV and its widths (MOVW MOVWU MOVH MOVHU MOVB MOVBU)
 * between registers, constants, addresses and memory (o(R), o(SP),
 * o(FP), sym(SB)); ADD SUB AND ORR EOR BIC CMP CMN and their W and S
 * forms; NEG MVN LSL LSR ASR MUL UMULL SMULL SDIV UDIV REM UREM, SXTW
 * and the other extensions; B BL (to a name, a label, n(PC) or a
 * register), the conditional branches, CBZ CBNZ, RETURN RET SVC, CASE
 * and BCASE; and in floating point: FMOVD FMOVS, FADD FSUB FMUL FDIV
 * FCMP (D and S), and the conversions. Also TEXT DATA GLOBL, labels,
 * and // and /* comments.
 *
 * What is left out, compared to mini-ld: arm (5l, with its conditional
 * execution, pools and division calls); Mach-O (its code would be the
 * same, since it is pc-relative; what is missing is the rebase of the
 * pointers in the data, left as an exercise) and a.out; libraries and
 * object files, which is the whole point; 7l's follow pass (dead code
 * after a RET stays); byte-identical output with 7l, and therefore
 * 7l's choices (pools, bitmask immediates, extended registers);
 * shifted operands, pre- and post-indexed addressing, CSEL and the
 * other instructions 7c doesn't emit.
 *
 * The test: TinyAssembler_test.sh builds goken's exit and hello, and
 * goken's 17 hello_libc programs with all of libc, runs them, and
 * compares what they print with goken's expected outputs (two of them,
 * dirread and mem, pass here but fail with goken's own 7l).
 *
 * Exercises, each one cheap because every size is known before any
 * address, and every word is a closure over its pc:
 * - a map and a listing: print the address of each function, and each
 *   word with its pc and its source line, by walking what the layout
 *   already holds;
 * - take on Szymanski's problem, as an option: use the short form of a
 *   branch when its target is near, iterating sizes and addresses
 *   until they agree; measure what it saves against what it costs;
 * - arm32 (as in 5l): the same three passes, with arm's encodings as
 *   closures, and literal pools brought back, placed after each
 *   function;
 * - drop dead code after a RET (7l's follow): walk the branches from
 *   the entry of each function, and leave the words never reached out
 *   of the layout;
 * - Mach-O (see above): the rebase of the pointers in the data, which
 *   is the list of the closures that write an address.
 *
 * Where it fits: tiny-c and tiny-ml (TinyC, TinyML) write the assembly
 * this program reads, and goken's libc comes as assembly too (7c -S).
 * What it writes is run by Linux on arm64, by mini-5i, and by tiny-arm
 * (TinyCPUArm, which loads the single segment). Its counterparts in
 * m-ix are two programs with a file format between them: mini-asm
 * (Parser_asm, which writes an object) and mini-ld (which does the
 * layout and the encoding, per machine).
 *
 * cs-history:
 * The first assemblers were exactly this kind of program: the EDSAC's
 * initial orders (David Wheeler, 1949) read orders punched on paper
 * tape as a letter and a decimal address, and stored them in memory as
 * binary, assembling and loading in a single step. The linker came
 * later, with libraries and with programs too big to translate again
 * after each change: each part was translated once into an object,
 * with its addresses left open, and the parts were bound together
 * later. What took minutes of machine time then takes a fraction of a
 * second now for a whole libc's worth of assembly, which is what lets
 * this program read everything every time.
 *
 * terminology:
 * An assembler translates mnemonics into words but leaves open the
 * addresses it cannot know (for example, a name defined in another
 * file); a linker puts the objects one after the other and fills in
 * those addresses; a loader puts the result in memory and jumps to it.
 * Plan 9 calls its linker the loader (5l, 7l: l for load) and gives it
 * most of the assembler's work. Here the three words each name one
 * pass of a single program, and the loader is the kernel reading the
 * PT_LOAD.
 *
 * plan9-is-cleaner:
 * In the Unix toolchains the assembler does the encoding, and the
 * linker patches the holes using relocations, with a table per machine
 * of all the ways an address can sit inside an instruction. Plan 9's
 * assemblers do not encode: an object holds the instructions as
 * parsed, and the linker, which knows every address, chooses the form
 * of each one. There are no relocations, and a branch is short or long
 * depending on where its target really is. This file keeps that order
 * (addresses first, bits last) and drops the object file in between.
 *
 * others:
 * fasm (the flat assembler), and nasm with its bin format, also write
 * a runnable file directly from assembly, with no linker; both are for
 * x86. Go's assembler and linker descend from Plan 9's, with the same
 * syntax (TEXT, SB, FP) twenty years later; in 2014 Go moved the
 * encoding out of its linker, to make builds faster.
 *
 * References: M. V. Wilkes, D. J. Wheeler and S. Gill, The Preparation
 * of Programs for an Electronic Digital Computer (1951), the EDSAC
 * book, for the initial orders; Ken Thompson, "Plan 9 C Compilers"
 * (Summer 1990 UKUUG Conference), for doing the encoding where every
 * address is known; T. G. Szymanski, "Assembling Code for Machines
 * with Span-dependent Instructions" (CACM, 1978), the problem we avoid
 * by choosing each expansion from its operands alone: no size waits
 * for an address, so no pass has to be redone; the Tool Interface
 * Standard's ELF specification (1995). *)

(* the files' assembly to an executable [out], entered at [entry]: read,
 * what is not reached left out, laid out, each instruction encoded *)
val link : < Cap.open_in; Cap.open_out; .. > -> string list -> string -> string -> unit

(* the program: its arguments (-h: how) to its exit status *)
val main : < Cap.argv; Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; .. > -> int
