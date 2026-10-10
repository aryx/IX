(* The executable's file: ELF (Linux), Plan 9's a.out or Mach-O (arm64 macOS), from the
 * text's and the data's bytes (5l's asmb; goken's liblk/elf.c; xix's
 * Executable)
 *
 * An executable is three things for the kernel's exec: bytes to put
 * in memory to run (the text), bytes to put in memory to change (the
 * data), and a number of bytes to zero after them (the bss, which
 * has no bytes in the file). A header says how many of each, and
 * where to start. Plan 9's a.out for arm, the simplest of the three
 * formats, whole (-H2; every field 4 bytes, big-endian whatever the
 * machine):
 *
 *     the file                         in memory, by exec
 *     0   magic   0x647 (arm)          0x1000  the header and the
 *     4   text    its size                     text: read, execute
 *     8   data    its size                     ..........
 *     12  bss     its size             the next page
 *     16  syms    0: no symbol table           the data: read, write
 *     20  entry   where to start               the bss: zeros
 *     24  spsz    0                            (the heap grows here)
 *     28  pcsz    0                            ..........
 *     32  the text                     at the top, the stack
 *         the data, right after
 *
 * The text is INITTEXT + 32 = 0x1020 for the linker, because exec
 * maps the file from its first byte, header included, at 0x1000: no
 * byte of the file is skipped or moved, the page of the file is the
 * page of the memory. The data starts on a page of its own (INITRND)
 * since its protection differs from the text's. arm64's header has
 * 8 bytes more, the entry in 64 bits, and its magic says so.
 *
 * ELF says the same with more words. For a static program, what
 * exec reads is the ELF header (52 bytes in 32 bits, 64 in 64), then
 * program headers, each a segment: an offset in the file, an address,
 * a size in the file and a larger one in memory (the difference is
 * the bss), and rights. Three are written, the text's, the data's
 * and an empty one. hello for arm (Elf.mli has it read back):
 *
 *     0x0000  the ELF header, three program headers: 148 bytes,
 *             rounded to 160 (HEADR)
 *     0x00a0  the text, at 0x80a0     (0x8000 + HEADR: the same trick)
 *     0x7000  the data, at 0xf000     (the file's next page, memory's)
 *     then    three section headers and their names, for the tools
 *
 * Mach-O (-H6) is for running under macOS on arm64, which refuses a
 * static executable: the file names dyld and libSystem though it
 * calls neither, is position independent, and lists the pointers in
 * its data for the loader to slide (Link.pointers).
 *
 * Raw (-H0) is the two byte strings one after the other and nothing
 * else: a kernel's image, for a firmware that loads a file at a
 * fixed address and jumps to its first byte (mini-qemu's Board).
 *
 * cs-history:
 * a.out is the oldest name here: the file the first Unix assembler
 * wrote when given no other name, "assembler output", and then the
 * name of the format (1971). Its header on the PDP-11 began with the
 * magic number 407 (octal), which is a PDP-11 branch over the
 * header: the file could be loaded whole and started at its first
 * word. System V replaced it by COFF (1983), which
 * added sections, then by ELF (System V Release 4), which Linux
 * took in the 1990s. Plan 9 kept a.out and made it portable: the
 * big-endian header above, a magic number per machine, the 4*b*b+7
 * of a.out.h (0x647 is b = 20).
 *
 * plan9-is-cleaner:
 * No sections, no dynamic segment, no interpreter, no notes: 32
 * bytes of header for a program, where an ELF needs its two tables
 * and a tool to read them (readelf). It is enough because Plan 9
 * links statically: what a program needs of its system at run time
 * it gets by opening files, not by binding more code.
 *
 * References: the Tool Interface Standard's "Executable and Linking
 * Format (ELF) Specification", version 1.2 (1995), from System V
 * Release 4: a file has two views, program headers for exec, which is
 * all a static executable needs, and section headers for the tools,
 * of which this writes only a token three, as 5l does; Plan 9's
 * a.out(6). *)

(* Raw: no header (5l's and 7l's -H0), a kernel's image *)
type format = Elf | Plan9 | Macho | Raw

type image = { text : Bytes.t; data : Bytes.t; bss : int; text_start : int; data_start : int; entry : int;
               pointers : int list;   (* the data's pointers, for Mach-O's rebase *)
               round : int }          (* INITRND *)

(* the header's size, before the text (5l's HEADR) *)
val headr : format * Asm.arch -> int

val write : < Cap.open_out; .. > -> format -> Asm.arch -> Fpath.t -> image -> unit
