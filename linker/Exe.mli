(* The executable's file, written from the bytes of the text and of the
 * data, in one of these formats: ELF (Linux), Plan 9's a.out, or Mach-O
 * (arm64 macOS). It is 5l's asmb, goken's liblk/elf.c, and xix's
 * Executable.
 *
 * For the kernel's exec, an executable is three things: bytes to put in
 * memory to run (the text), bytes to put in memory to change (the
 * data), and a number of bytes to zero after them (the bss, which has
 * no bytes in the file). A header says how many there are of each, and
 * where to start. Here is Plan 9's a.out for arm, the simplest of the
 * three formats, in full (-H2; every field is 4 bytes, big-endian
 * whatever the machine):
 *
 *     the file                         in memory, by exec
 *     0   magic   0x647 (arm)          0x1000  the header and the
 *     4   text    its size                     text: read, execute
 *     8   data    its size                     ..........
 *     12  bss     its size             the next page
 *     16  syms    the symbols' bytes           the data: read, write
 *     20  entry   where to start               the bss: zeros
 *     24  spsz    0                            (the heap grows here)
 *     28  pcsz    the pc/line table's bytes    ..........
 *     32  the text                     at the top, the stack
 *         the data, right after
 *         the symbols, the pc/line table (Symtab; not loaded by exec)
 *
 * For the linker the text is at INITTEXT + 32 = 0x1020, because exec
 * maps the file from its first byte, header included, at 0x1000. No
 * byte of the file is skipped or moved: the page of the file is the
 * page of the memory. The data starts on a page of its own (INITRND)
 * because its protection differs from the text's. arm64's header has 8
 * more bytes, for the entry in 64 bits, and its magic says so.
 *
 * ELF says the same with more words. For a static program, what exec
 * reads is the ELF header (52 bytes in 32 bits, 64 in 64 bits), then
 * the program headers, one for each segment. A program header gives an
 * offset in the file, an address, a size in the file and a larger one
 * in memory (the difference is the bss), and the rights. Three are
 * written: the text's, the data's and an empty one. Here is hello for
 * arm (Elf.mli reads it back):
 *
 *     0x0000  the ELF header and three program headers: 148 bytes,
 *             rounded to 160 (HEADR)
 *     0x00a0  the text, at 0x80a0     (0x8000 + HEADR: the same trick)
 *     0x7000  the data, at 0xf000     (the next page in the file and
 *                                      in memory)
 *     then    three section headers and their names, for the tools
 *
 * Mach-O (-H6) is for running under macOS on arm64, which refuses a
 * static executable. So the file names dyld and libSystem though it
 * calls neither, it is position independent, and it lists the pointers
 * in its data for the loader to slide (Link.pointers).
 *
 * Raw (-H0) is the two byte strings one after the other and nothing
 * else. It is a kernel's image, for a firmware that loads a file at a
 * fixed address and jumps to its first byte (mini-qemu's Board).
 *
 * cs-history:
 * a.out is the oldest name here. It was the file the first Unix
 * assembler wrote when given no other name, "assembler output", and
 * then it became the name of the format (1971). Its header on the
 * PDP-11 began with the magic number 407 (octal), which is a PDP-11
 * branch over the header, so the file could be loaded whole and started
 * at its first word. System V replaced it by COFF (1983), which added
 * sections, and then by ELF (System V Release 4), which Linux took in
 * the 1990s. Plan 9 kept a.out and made it portable, with the
 * big-endian header above and a magic number per machine, the 4*b*b+7
 * of a.out.h (0x647 is b = 20).
 *
 * plan9-is-cleaner:
 * There are no sections, no dynamic segment, no interpreter and no
 * notes: a program has 32 bytes of header, where an ELF needs its two
 * tables and a tool to read them (readelf). It is enough because Plan 9
 * links statically: what a program needs from its system at run time,
 * it gets by opening files, not by binding more code.
 *
 * References: the Tool Interface Standard's "Executable and Linking
 * Format (ELF) Specification", version 1.2 (1995), from System V
 * Release 4. In it a file has two views: program headers for exec,
 * which are all a static executable needs, and section headers for the
 * tools, of which this module writes only a token three, as 5l does.
 * Also Plan 9's a.out(6). *)

(* Raw has no header (5l's and 7l's -H0); it is for a kernel's image. *)
type format = Elf | Plan9 | Macho | Raw

type image = { text : Bytes.t; data : Bytes.t; bss : int; text_start : int; data_start : int; entry : int;
               pointers : int list;   (* the data's pointers, for Mach-O's rebase *)
               round : int;           (* INITRND *)
               (* Plan 9's symbol table and pc/line table (Symtab), after
                * the data; "" for none (-s) *)
               syms : string; lines : string;
               (* ELF's symbols (-g): each has a name, its value, its
                * size, whether it is a function or an object, and
                * whether it is global or local (Symtab) *)
               elf_syms : (string * int * int * bool * bool) list }

(* the header's size, before the text (5l's HEADR) *)
val headr : format * Asm.arch -> int

val write : < Cap.open_out; .. > -> format -> Asm.arch -> Fpath.t -> image -> unit
