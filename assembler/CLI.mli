(* mini-asm is Plan 9's assembler: 5a for arm and 7a for arm64. It reads
 * a .s file and writes what it says to an object file as it is: a list
 * of instructions with their operands, none of them turned into a
 * machine word.
 *
 *     hello.s                           the modules a file goes through
 *        | Lexer_asm   #include and #define, then the tokens
 *     tokens
 *        | Parser_asm  a line to an item; a label to the item it names
 *     Asm.obj          TEXT, GLOBL, DATA and instructions, each with
 *        |             its line (Show_asm prints an item as text again)
 *        | Asm.save    marshalled
 *     hello.5          (hello.7 on arm64), for mini-ld and mini-ar
 *
 * goken's hello for Linux (tests/s/hello_arch there) shows the whole
 * language in ten lines. A function is a TEXT, a variable is a GLOBL
 * with its size, and its bytes are DATAs. What is left are the
 * machine's instructions, with the operands from left to right and the
 * destination last:
 *
 *     TEXT _start(SB), $0          a function, with a frame of 0 bytes
 *         MOVW $1, R0              a constant into a register
 *         MOVW $msg(SB), R1        an address: SB is where the data is
 *         MOVW $13, R2
 *         MOVW $4, R7              Linux's write
 *         SWI  $0                  the system call
 *     GLOBL msg(SB), $13
 *     DATA  msg+0(SB)/8, $"Hello, w"
 *     DATA  msg+8(SB)/5, $"orld\n"
 *
 * Nothing here knows what MOVW is. To the parser an opcode is a string,
 * and one that does not exist is found at link time (mini-ld:
 * file.s:3: unknown opcode FOO), as is a MOVW whose operands no ARM
 * instruction has. The assembler's part is the syntax. Choosing and
 * encoding the instruction is the linker's part (Asm says why, and Arm
 * and Arm64 do it). So the same program serves both machines, which are
 * told apart by -m and by the names of their registers.
 *
 * Where it stands: mini-cc and mini-ml write the same objects (Asm's
 * items) without going through a text, so this program is for what is
 * written by hand: a kernel's entry and its context switch, a libc's
 * system calls, and memmove. Highlight_asm colors the same language for
 * the editor.
 *
 * terminology:
 * 5a, 5c, 5l. Plan 9 names a tool by its machine and its job. A digit
 * or a letter stands for the machine (5 is arm, 7 is arm64 in 9front, 8
 * is the 386, 6 amd64, v mips, k sparc, q powerpc). Then comes a for the
 * assembler, c for the C compiler, or l for the loader, which is the
 * linker. An object has the machine's character as its extension
 * (hello.5), and what the loader writes is 5.out. Compiling for another
 * machine means running another program built from the same sources:
 * there is no cross compiler because every compiler is one. Here each
 * tool is one program for both machines (mini-asm, mini-ld), and the
 * character is given by -m.
 *
 * others:
 * A Unix assembler (as, GNU's gas) does the whole translation. It
 * writes machine code, and where an address is not known yet it leaves
 * a hole and a relocation record that tells the linker how to fill it.
 * Its object is a real ELF file of sections, which objdump can
 * disassemble. The price is paid in the linker, which must know each
 * kind of relocation of each machine, and in the assembler, which must
 * choose an instruction's form before knowing how far its target is.
 *
 * design:
 * An assembler that does almost nothing was a choice made for the
 * compiler's sake, not the assembler's. In Plan 9 the compiler does not
 * write assembly text for an assembler to read back; it writes the
 * object itself, and the assembler is a second, small front end to the
 * same object. What is done in one place after both of them, in the
 * loader, is done only once.
 *
 * The usage and examples of the command line are in [help] in CLI.ml,
 * which is what mini-asm -h prints.
 *
 * References: Rob Pike, "A Manual for the Plan 9 assembler" (in the
 * second volume of the Plan 9 manual), which is short and the one to
 * read first; Ken Thompson, "Plan 9 C Compilers" (1990), for the split
 * between the assembler and the loader; principia's assemblers/5a and
 * xix's assembler, which are the same program in C and in OCaml. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
