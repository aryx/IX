(* AArch64's MMU for the EL1&0 regime, as the Pi4's kernels use it
 * (plan_pi.md, phase G2): the 4 KB granule, TTBR0 for the addresses
 * whose top bits are all zeros and TTBR1 for those all ones (TCR's
 * T0SZ and T1SZ give the sizes), tables of 512 descriptors from the
 * level the size starts at down to level 3, blocks (1 GB at level 1,
 * 2 MB at level 2) and pages, AP[2:1], UXN and PXN, the access flag.
 *
 *   xv6 arm64-pi4: T1SZ = 25, a 39-bit kernel half at
 *   0xffffff80_00000000: levels 1, 2 (2 MB blocks); its processes
 *   under TTBR0, down to 4 KB pages at level 3.
 *
 * The same walk as Mmu32's, which says what a page table and a TLB
 * are for, made regular: every table is 512 descriptors of 8 bytes,
 * so every table is a page, and each level takes 9 bits of the
 * address:
 *
 *     63      48 47   39 38   30 29   21 20   12 11      0
 *     | all 0s  | lvl 0 | lvl 1 | lvl 2 | lvl 3 | offset |
 *     | or 1s   |  9    |  9    |  9    |  9    |  12    |
 *         |
 *         '- zeros: TTBR0, a process's half
 *            ones:  TTBR1, the kernel's half
 *
 * A descriptor's two low bits: bit 0 clear, a fault; 3 at levels 0
 * to 2, the next table; 1 at level 1 or 2, a block, the walk ending
 * early on 1 GB or 2 MB mapped at once (ARM32's sections); 3 at
 * level 3, a page. With a 39-bit half (T0SZ or T1SZ = 25) level 0
 * is not there and the walk starts at level 1, three loads for a
 * page; with 48 bits it is four.
 *
 * The 64 bits are not all translated: the top ones must be all
 * zeros or all ones, anything else being a fault, which leaves a
 * hole in the middle of the address space and gives each half a
 * register of its own. A kernel so sits at the top (its addresses
 * start with ffff) and each process at the bottom, and a switch of
 * process writes TTBR0 and leaves TTBR1 alone.
 *
 * The rights are fewer and plainer than ARM32's: two bits say
 * whether EL0 may touch the page and whether it is read-only
 * (AP[2:1]), two that it is not executable, by EL0 and by EL1 (UXN,
 * PXN), and the access flag, which must be set or the first access
 * faults (a kernel uses it to learn which pages are used). No
 * domains.
 *
 * others:
 * Four levels of 9 bits over 4 KB pages is also x86-64's shape (its
 * PML4, 48 bits), and RISC-V's Sv39 and Sv48 are the three- and
 * four-level versions of the same: the 64-bit machines converged,
 * where the 32-bit ones each had their own cut. What differs is the
 * two table registers; x86-64 has one, CR3, and a kernel there
 * copies its half's entries into every process's top table.
 *
 * Not modelled: the 16 KB and 64 KB granules, the table descriptors'
 * APTable/XNTable, the hardware access flag, ASIDs (the TLB is emptied
 * by any TLBI and by writes to TTBR0/1, TCR, SCTLR), stage 2.
 *
 * References: ARM Architecture Reference Manual, ARMv8-A (ARM DDI
 * 0487), the chapter on the AArch64 virtual memory system
 * architecture, VMSAv8-64 (D4 in issue C.a; the number changes with
 * the issue); QEMU's
 * target/arm/ptw.c (read 2026-09-25) for the permissions: an address
 * EL0 may write is never executable at EL1, and one EL0 may not read
 * is not executable at EL0. *)

type t = {
  mutable sctlr : int64;
  mutable tcr : int64;
  mutable ttbr0 : int64;
  mutable ttbr1 : int64;
  mem : Memory.t;
  tags : int array;
  pages : int array;
  rights : int array;
}

val create : Memory.t -> t

val flush : t -> unit

val enabled : t -> bool

(* the physical address of [va] for an access (bit 0 a write, bit 1 as
 * user, bit 2 an instruction fetch), or Arm64.Abort with the virtual
 * address and the fault status code (translation, access flag or
 * permission, and the level; bit 6 when a write) *)
val translate : t -> int64 -> int -> int
