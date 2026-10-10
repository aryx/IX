(* mini-xv6's system calls (xv6's syscall.c, sysproc.c, sysfile.c, and
 * proc.c's fork, exit, wait), xv6-riscv's semantics (plan_kernel.md:
 * xv6-multiarch's forks converging): exit's status, wait's, the user's
 * memory reached through its page table only (copyin, copyout,
 * copyinstr: the guard page refused), MAXPATH. The board's ABI (Arch):
 * the number (r0, x7), the arguments (the Pi1's user stack, the Pi4's
 * x0-x5), the result in the first register.
 *
 * The 21 calls, by their numbers (xv6's syscall.h):
 *
 *     1 fork    6 kill     11 getpid   16 write
 *     2 exit    7 exec     12 sbrk     17 mknod
 *     3 wait    8 fstat    13 sleep    18 unlink
 *     4 pipe    9 chdir    14 uptime   19 link
 *     5 read   10 dup      15 open     20 mkdir    21 close
 *
 * A call's way, write(1, buf, 5) from a program on the Pi4:
 *
 *     the user's stub: x7 <- 16, x0 <- 1, x1 <- buf, x2 <- 5; svc
 *     the vectors (start.s): the registers saved, the trap frame
 *     Main.trap -> syscall: tf 7 is 16, Write
 *       argaddr 1:  tf 1, an address: only a number so far
 *       argint 2:   tf 2, as C's int
 *       argfd 0:    tf 0, a descriptor, its open file
 *       File.write: the bytes asked through Mmu.read, the user's
 *                   table walked, a page at a time
 *     tf 0 <- 5; the registers loaded back; the program goes on
 *
 * Nothing the user says is believed. An argument is a number; a
 * number that is to be an address is never used as one: the bytes
 * there are copied in or out through the process's own table, where
 * a page that is not its own (the guard page, the kernel's, none) is
 * a failed copy and a -1, not a fault of the kernel's. A wrong
 * argument is None, and >>= in Syscall.ml makes the call's -1 of it:
 * xv6's chain of  if(argint(0, &n) < 0) return -1; .
 *
 * terminology:
 * A system call is a trap made on purpose: an instruction (svc on
 * ARM, once swi; int and syscall on x86; ecall on RISC-V) that
 * enters the kernel as a fault or an interrupt does, at an address
 * the kernel chose, in the processor's privileged mode. What a C
 * program calls write is a few instructions of a library around
 * that one. The ABI (application binary interface) is the
 * convention the two sides share: which register has the number,
 * where the arguments are. Arch has the two boards'.
 *
 * others:
 * Unix's calls returned -1 and a reason in errno; xv6 has the -1
 * only. Plan 9's return -1 and a string, read by errstr, and are
 * fewer than Unix's had become: no ioctl, no socket calls, the files
 * doing their work (mini-9pi's). mini-singularity's Abi has about as
 * many calls as here, reached by a call instruction and not a trap,
 * the process being in the kernel's address space.
 *
 * References: the xv6 book's "Traps and system calls" (the trap's
 * way, argument fetching, copyin and copyout); xv6's syscall.c,
 * sysproc.c, sysfile.c. Ritchie and Thompson, "The UNIX Time-Sharing
 * System" (1974), for what the calls are for; the first edition's
 * manual (1971), section II, where most of them already are. *)

(* NOFILE *)
val nofile : int

(* the running process's call, from its trap frame, its result there *)
val syscall : Types.proc -> unit

(* the running process's end, with a status: its files closed, its
 * children given to init, its parent woken; a zombie, until its
 * parent's wait frees its memory and its kernel stack. Returns only in
 * the type *)
val exit : Types.proc -> int -> unit
