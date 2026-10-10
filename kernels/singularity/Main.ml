(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-singularity's boot (plan_system_singularity.md, stage 2: the
 * processes). The kernel starts one process, init, and runs what can
 * run until nothing can: init starts the others.
 *
 * mini-singularity as a whole: Microsoft Research's Singularity as
 * its papers tell it, on the bare Pi, in OCaml. An operating system
 * whose processes are kept apart by the language they are written
 * in and not by the processor. The board's memory, physical, which
 * is also every process's:
 *
 *     0 ........ the kernel: its code, its heap (Process, Channel,
 *                Abi, Exchange, Main; Machine under them), and the
 *                programs' pristine copies, as data
 *     96 MB .... the exchange heap: blocks, each with one owner
 *     128 MB ... init      a program each 16 MB, linked for that
 *     144 MB ... console   address: its code, its own heap and its
 *     160 MB ... shell     own collector, its stack at the slot's
 *     ...                  end
 *
 * No table of pages is made for a process, none is switched, and a
 * process runs at the kernel's privilege. What keeps the shell out
 * of the console's memory is that the shell is an OCaml program
 * with nothing unsafe in it: no address can be made in it, only
 * values be given to it. Its three ideas, a module each here:
 *
 *     Process    software-isolated processes: a program copied to
 *                its address and called; what it holds of the
 *                kernel, handles
 *     Channel,   the only way two processes talk: messages on a
 *     Contract   channel, in the order a contract allows
 *     Exchange   what a message carries: a block that changes
 *                owner, never copied, never shared
 *     Abi, Sip   the kernel's functions, for the kernel and for a
 *                program: a call, not a trap
 *     singml/    mini-singml: a program's source looked at (Safe),
 *                a contract's declaration made a module, a
 *                manifest read (what of the machine a driver gets)
 *
 * A session, at its shell (tutorial.md has the rest):
 *
 *     sing> ps
 *      0 init       waiting
 *      1 console    waiting
 *      2 shell      running
 *
 * the console's driver being a process as the others, given the
 * UART's registers by its manifest and reached by a channel.
 *
 * What is ours, and lost: Sing# checks at compile time that a
 * contract is kept and that a block given away is not used again;
 * OCaml cannot, and here both are checked when the program runs (a
 * message out of turn ends its sender, a block used after it was
 * sent raises). And Singularity verified a program's compiled code;
 * here its source is looked at when the image is built. Cooperative,
 * one process a program, programs known when the image is made.
 * Nothing of Singularity's sources is here.
 *
 * cs-history:
 * Singularity was begun at Microsoft Research in 2003 by Galen Hunt
 * and James Larus, with a question: what would a system look like
 * if built for dependability, on the languages and tools of that
 * year and not of 1970? A kernel, drivers and applications in
 * Sing#, a C# extended with contracts and ownership, compiled to
 * machine code ahead of time (the Bartok compiler), with all of it
 * in ring 0 by default. Its research kit was published in 2008; a
 * larger system built on its ideas inside Microsoft, Midori, was
 * never released.
 *
 * evolution:
 * Protection by the language is older than protection by the
 * processor is common. The Burroughs B5000 (1961) had no assembler
 * for its users: every program came out of a trusted compiler. The
 * Lisp machines, Smalltalk and Oberon (mini-squeak and mini-oberon,
 * beside this directory) are single address spaces of safe code,
 * for one user. SPIN (University of Washington, 1995) loaded
 * extensions written in Modula-3 into its kernel; Inferno (Bell
 * Labs, 1996) ran Limbo programs on a virtual machine with typed
 * channels between them, on processors without an MMU. Singularity
 * added what those lacked: processes that share nothing, each with
 * its own collector, so that one can be stopped and its memory
 * taken back whole.
 *
 * comeback:
 * Code let into a privileged address space because a tool checked
 * it is everywhere since: Linux's eBPF verifier, WebAssembly's
 * sandboxes in one process, kernels and their extensions in Rust,
 * whose ownership is the exchange heap's rule made a language's.
 *
 * why-study:
 * It is the measured answer to a question every course takes for
 * granted: what does the MMU cost? The paper's table 1 has a
 * process's creation, a call of the kernel, a yield and a message
 * there and back, against Linux, FreeBSD and Windows; programs/bench
 * measures the same four here, and mini-xv6 and mini-9pi, on the
 * same boards with the same compiler, are the other column (not
 * measured yet: the plan's "What is left").
 *
 * References: Galen Hunt and James Larus, "Singularity: Rethinking
 * the Software Stack" (ACM SIGOPS Operating Systems Review, April
 * 2007): the paper this was written from, to read first. Aiken,
 * Fahndrich, Hawblitzel, Hunt and Larus, "Deconstructing Process
 * Isolation" (2006): what hardware isolation costs. Fahndrich and
 * others, "Language Support for Fast and Reliable Message-based
 * Communication in Singularity OS" (EuroSys 2006): contracts and the
 * exchange heap. Bershad and others, "Extensibility, Safety and
 * Performance in the SPIN Operating System" (SOSP 1995). Joe Duffy,
 * "Blogging about Midori" (2015). plan_system_singularity.md, with
 * what was decided and what is not verified. *)

let () =
  Machine.print "mini-singularity\n";
  ignore (Process.start false (Process.create false "init"));
  Process.schedule ();
  Machine.print "mini-singularity: no process left.\n";
  Machine.halt ()
