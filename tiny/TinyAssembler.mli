(* A tiny assembler for arm64 that writes the executable, in one file.
 * mini-asm and mini-ld (assembler/, linker/) are Plan 9's split,
 * faithfully: an assembler that only parses into objects, and a linker
 * that loads them and their libraries, lays out and encodes, choosing
 * for each instruction the form 7l would, byte for byte. This is what
 * is left without separate compilation (its usage, by examples: [help]
 * below, what tiny-assembler -h prints): all the assembly of a program, its own and its libc's (7c -S output,
 * and libc's .s), read at once, and the ELF executable written.
 *
 *     file.s ...                the passes, one after the other
 *        | lex, parse    lines to items: a TEXT, an instruction and its
 *        |               operands, a DATA, a GLOBL
 *        | gather        a function is its TEXT's instructions; a data
 *        |               symbol its size and its DATAs
 *        | reach         the names the entry reaches, through code and
 *        |               data: the rest is not in the executable
 *        | expand        an instruction to its words, each a function
 *        |               of its own pc: every size is known here
 *        | lay out       the text, the data, the bss: every address
 *        | encode        each word's function called with its address
 *     a.out
 *
 * and what is written, which is also the memory when it runs (the
 * file is loaded whole at 0x400000; with -raw the first line is not
 * there and the second is at the address given):
 *
 *     0x400000   ELF's header (64 bytes), its one program header (56)
 *     0x400078   the text: the reached functions, in their files' order
 *     setSB      the data, 16-aligned after the text, a symbol every 8
 *     edata      the bss: counted in the memory's size, not in the file
 *     end
 *
 * An example of a size known from the operands alone: MOV $0x12345678,
 * R1 is two words whatever is around it, a MOVZ of 0x5678 and a MOVK
 * of 0x1234 at bit 16 (movconst: a word for each 16 bits that are
 * not zero, or not all ones when most are, after a MOVN); where
 * 7l has a pool of constants after the function and a load from it,
 * whose form depends on how far the pool ends up.
 *
 * What makes it small, and still a real toolchain:
 *
 * - {b Every size is known before any address.} An instruction's
 *   expansion depends on its operands only, never on where things end
 *   up: a constant is built by MOVZ, MOVK or MOVN (up to four), an
 *   address by ADRP and ADD, pc-relative (a global's load by ADRP, ADD
 *   and the load), a logical immediate in a register. So there is no
 *   literal pool, no bitmask encoder, no relaxation, and no second
 *   guess: expand, then lay out, then encode, one pass each. The
 *   executable is about 7l's size: where 7l loads from a pool, this
 *   builds, and it has no pool words (hello with libc: 27,328 bytes,
 *   against 7l's 27,606).
 * - {b The encoding is a word per closure}: each instruction becomes a
 *   list of functions from their own pc to 32 bits, run once every
 *   address is known. That is Plan 9's point (encode in the linker,
 *   when addresses are known) with the linker and the assembler made
 *   one: the objects in between are gone.
 * - {b A library is its reachable functions.} What an archive's index
 *   does (take the objects that define what is undefined), a walk from
 *   the entry does at the granularity of functions and data: the
 *   executable has what the program uses, and a name defined twice is
 *   its first definition (fmt's strtod before port's, as ar has it).
 *   A name<> is its file's.
 * - {b 7l's frames}, because 7c's code counts on them: the frame
 *   16-aligned with R30 at its bottom, pushed by a pre-indexed store; a
 *   leaf without locals makes none; RETURN undoes it. n+8(FP) is the
 *   caller's frame, x-8(SP) this one's.
 * - {b The file is ELF with one segment}: the header, the text and the
 *   data in one read-write-execute PT_LOAD, then the bss; no sections.
 *   With -raw, not even the header: the text at the address given, as
 *   a kernel's image is loaded (TinyMachinePi's).
 *
 * The instructions are what 7c emits and libc's .s use: MOV and its
 * widths (MOVW MOVWU MOVH MOVHU MOVB MOVBU) between registers,
 * constants, addresses and memory (o(R), o(SP), o(FP), sym(SB)); ADD
 * SUB AND ORR EOR BIC CMP CMN and their W and S forms; NEG MVN LSL LSR
 * ASR MUL UMULL SMULL SDIV UDIV REM UREM, SXTW and the extensions; B BL
 * (to a name, a label, n(PC) or a register), the conditional branches,
 * CBZ CBNZ, RETURN RET SVC, CASE and BCASE; floating point: FMOVD
 * FMOVS, FADD FSUB FMUL FDIV FCMP (D and S), the conversions; and for
 * a kernel's first page MRS and MSR (a system register by its name or
 * SPR(n), as 7a), ERET, WFI, and WORD, a word as it is. TEXT DATA
 * GLOBL, labels, // and /* comments.
 *
 * Left out, against mini-ld: arm (5, and its conditional execution,
 * pools and division calls); Mach-O (its code would be the same, being
 * pc-relative; the rebase of the data's pointers is the missing part:
 * an exercise) and a.out; libraries and objects, which is the point;
 * 7l's follow (dead code after a RET stays); the byte identity with
 * 7l, and so 7l's choices (pools, bitmask immediates, extended
 * registers); shifted operands, pre- and post-indexed addressing, CSEL
 * and the others 7c doesn't emit.
 *
 * The test: TinyAssembler_test.sh builds goken's exit and hello, and
 * goken's 17 hello_libc programs with all of libc, runs them, and
 * compares what they print with goken's expected outputs (two of them,
 * dirread and mem, pass here and fail with goken's own 7l).
 *
 * Exercises, each cheap because every size is known before any
 * address, and every word a closure of its pc:
 * - a map and a listing: each function's address and each word with
 *   its pc and its source, a walk over what the layout already holds;
 * - Szymanski's problem taken on, as an option: a branch in its short
 *   form when its target is near, sizes and addresses iterated until
 *   they agree; measure what it saves against what it costs;
 * - arm32 (5l's): the same three passes, arm's encodings as closures,
 *   and the literal pools back, placed after each function;
 * - dead code after a RET dropped (7l's follow): a walk of the
 *   branches from each function's entry, the words never reached left
 *   out of the layout;
 * - Mach-O (above): the rebase of the data's pointers, the list of the
 *   closures that write an address.
 *
 * Where it stands: tiny-c and tiny-ml write the assembly this reads
 * (TinyC, TinyML), and goken's libc comes as assembly too (7c -S);
 * what it writes is run by Linux on arm64, by mini-5i, by tiny-arm
 * (TinyCPUArm, which loads the one segment) and, with -raw, by tiny-pi
 * (TinyMachinePi), mini-qemu and a Pi 4. Its twins in m-ix are two
 * programs with a file format between them: mini-asm (Parser_asm, to
 * an object) and mini-ld (the layout and the encoding, by machine).
 *
 * cs-history:
 * The first assemblers were this program: the EDSAC's initial orders
 * (David Wheeler, 1949) read orders punched as a letter and a decimal
 * address from paper tape and put them into memory as binary,
 * assembling and loading in one step. The linker came with libraries
 * and with programs too big to translate at each change: translate
 * each part once into an object with its addresses left open, and
 * bind them later. What was a matter of minutes of machine time then
 * is a fraction of a second now for a libc's worth of assembly, which
 * is what lets this file read everything each time.
 *
 * terminology:
 * An assembler translates mnemonics into words but leaves open the
 * addresses it cannot know (a name of another file); a linker puts
 * the objects one after the other and fills those addresses in; a
 * loader puts the result in memory and jumps to it. Plan 9 calls its
 * linker the loader (5l, 7l: l for load) and gives it most of the
 * assembler's work; here the three words name one pass each of one
 * program, and the loader is the kernel reading the PT_LOAD.
 *
 * plan9-is-cleaner:
 * In the Unix toolchains the assembler encodes, and the linker patches
 * the holes by relocations, a table per machine of the ways an address
 * can sit in an instruction. Plan 9's assemblers do not encode: an
 * object is the instructions as parsed, and the linker, which knows
 * every address, chooses each one's form. No relocation exists, and a
 * branch is short or long by where its target really is. This file
 * keeps that order (the addresses first, the bits last) and drops
 * the object in between.
 *
 * others:
 * fasm (the flat assembler) and nasm with its bin format also write a
 * runnable file from assembly alone, with no linker; they are x86's.
 * Go's assembler and linker descend from Plan 9's, the same syntax
 * (TEXT, SB, FP) twenty years on; Go moved the encoding out of its
 * linker in 2014 (from memory), for the speed of its builds.
 *
 * References: M. V. Wilkes, D. J. Wheeler and S. Gill, The Preparation
 * of Programs for an Electronic Digital Computer (1951), the EDSAC
 * book, for the initial orders; Ken Thompson,
 * "Plan 9 C Compilers" (Summer 1990 UKUUG Conference), for the
 * encoding done where every address is known; T. G. Szymanski,
 * "Assembling Code for Machines with Span-dependent Instructions"
 * (CACM, 1978), the problem avoided by choosing each expansion from
 * its operands alone: no size waits for an address, so no pass is
 * redone; the Tool Interface Standard's ELF specification (1995). *)

(* the files' assembly to an executable [out], entered at [entry]: read,
 * what is not reached left out, laid out, each instruction encoded.
 * [raw]: no header, the text at that address (a kernel's image) *)
val link : < Cap.open_in; Cap.open_out; .. > -> string list -> string -> int option -> string -> unit

(* the program: its arguments (-h: how) to its exit status *)
val main : < Cap.argv; Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; .. > -> int
