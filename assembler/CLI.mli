(* mini-asm: Plan 9's assembler, 5a for arm and 7a for arm64. A .s
 * file is read, and what it says is written to an object file as it
 * is: a list of instructions with their operands, not one of them
 * turned into a machine word.
 *
 *     hello.s                           the modules, a file's way
 *        | Lexer_asm   #include and #define, then the tokens
 *     tokens
 *        | Parser_asm  a line to an item; a label to the item it names
 *     Asm.obj          TEXT, GLOBL, DATA and instructions, each with
 *        |             its line (Show_asm: an item as text again)
 *        | Asm.save    marshalled
 *     hello.5          (hello.7 on arm64), for mini-ld and mini-ar
 *
 * With goken's hello for Linux (tests/s/hello_arch there), all the
 * language in ten lines: a function is a TEXT, a variable a GLOBL
 * with its size, its bytes are DATAs, and what is left are the
 * machine's instructions, operands from left to right, the
 * destination last:
 *
 *     TEXT _start(SB), $0          a function, a frame of 0 bytes
 *         MOVW $1, R0              a constant into a register
 *         MOVW $msg(SB), R1        an address: SB is where the data is
 *         MOVW $13, R2
 *         MOVW $4, R7              Linux's write
 *         SWI  $0                  the system call
 *     GLOBL msg(SB), $13
 *     DATA  msg+0(SB)/8, $"Hello, w"
 *     DATA  msg+8(SB)/5, $"orld\n"
 *
 * Nothing here knows what MOVW is. An opcode is a string to the
 * parser, and one that does not exist is found at the link (mini-ld:
 * file.s:3: unknown opcode FOO), as is a MOVW whose operands no ARM
 * instruction has. The assembler's part is the syntax; choosing and
 * encoding the instruction is the linker's (Asm says why, Arm and
 * Arm64 do it). So the same program serves both machines, told apart
 * by -m and by the names of their registers.
 *
 * Where it stands: mini-cc and mini-ml write the same objects (Asm's
 * items) without going through a text, so this program is for what
 * is written by hand: a kernel's entry and its switch of contexts, a
 * libc's system calls, memmove. Highlight_asm colors the same
 * language for the editor.
 *
 * terminology:
 * 5a, 5c, 5l. Plan 9 names a tool by its machine and its job: a digit
 * or a letter for the machine (5 arm, 7 arm64 in 9front, 8 the 386,
 * 6 amd64, v mips, k sparc, q powerpc), then a for the assembler, c
 * for the C compiler, l for the loader, which is the linker. An
 * object has the
 * machine's character for its extension (hello.5), and what the
 * loader writes is 5.out. Compiling for another machine is running
 * another program of the same sources: there is no cross compiler
 * because every one of them is. Here the two machines are one
 * program each (mini-asm, mini-ld) and the character is -m's.
 *
 * others:
 * A Unix assembler (as, GNU's gas) does the whole translation: it
 * writes machine code, and where an address is not known yet it
 * leaves a hole and a relocation record that tells the linker how to
 * fill it. Its object is a real ELF file of sections, that objdump
 * disassembles. The price is in the linker, which must know each
 * kind of relocation of each machine, and in the assembler, which
 * must choose an instruction's form before knowing how far its
 * target is.
 *
 * design:
 * An assembler that does almost nothing was a choice for the
 * compiler's sake, not the assembler's: in Plan 9 the compiler does
 * not write assembly text for an assembler to read back, it writes
 * the object itself, and the assembler is a second, small front end
 * to the same object. What is done in one place after both, the
 * loader, is done once.
 *
 * The command line: its usage and examples are [help] in CLI.ml, what
 * mini-asm -h prints.
 *
 * References: Rob Pike, "A Manual for the Plan 9 assembler" (in the
 * Plan 9 manual's second volume), short, to read first; Ken
 * Thompson, "Plan 9 C Compilers" (1990), for the split between the
 * assembler and the loader; principia's assemblers/5a and xix's
 * assembler, the same program in C and in OCaml. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
