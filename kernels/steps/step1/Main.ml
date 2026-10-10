(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-xv6, step 1 (plan_kernel.md): OCaml running bare-metal on the
 * Pi1, its output on the PL011. What it checks of the runtime: the
 * channels (buffered, flushed at exit), the allocation of the minor
 * heap and the major one (a list long enough to be promoted), a
 * collection, exceptions, Printf.
 *
 * The ladder mini-xv6 was climbed by, a directory a rung, each a
 * whole small kernel in one Main.ml that shows one mechanism and
 * checks what could have made the next impossible:
 *
 *     step0   C on the bare board (no OCaml): the boot, the UART
 *     step1   OCaml's runtime with no system under it      <- here
 *     step2   a trap: user mode, a system call, and back
 *     step3   processes, each on its own kernel stack; the
 *             collector told where the stacks are
 *     step4   the MMU: an address space a process
 *     step5   the timer: preemption, sleep, kill
 *     then    kernels/xv6: the same grown into modules, with files
 *
 * Here the question is the first one: can a garbage-collected
 * language run where there is no malloc, no file, no exit? What
 * the runtime asks of a system is short (memory to carve its heaps
 * from, a place to write, something to do at exit), and libc.c
 * beside this file is that list, each function a few lines or a
 * panic. With it, print_string below is the standard library's own,
 * over a channel whose write ends in the UART's register.
 *
 * why-study:
 * To write a kernel in steps that each run is the method, more than
 * any of the steps. The risk was put first (the runtime, then the
 * collector against the kernel's stacks) and the long part (files,
 * xv6's semantics) last; the author's earlier OCaml kernel had done
 * the reverse, and never ran a user program (plan_kernel.md tells
 * it). The steps are kept as they were, not updated to the final
 * kernel: read them in order, then diff each with the next.
 *
 * others:
 * MirageOS (Cambridge, 2013) is OCaml with no operating system
 * under it for another purpose: one application linked with the
 * drivers it needs, to run as a virtual machine. xv6 itself is
 * taught the same way round: a course's labs add one mechanism at
 * a time to a kernel that boots.
 *
 * References: plan_kernel.md, "The steps" and, for each, what it
 * found; notes_kernel.md, the tutorial written from them. Madhavapeddy
 * and others, "Unikernels: Library Operating Systems for the Cloud"
 * (ASPLOS 2013). *)

(* the list built by a loop: ocaml-light's List.init is not tail
 * recursive, and 100,000 frames overflow the 64KB stack (start.s's; no
 * guard page yet: the overflow ran down through the bss and below 0
 * before a data abort stopped it) *)
let rec upto i acc = if i < 0 then acc else upto (i - 1) (i :: acc)

let () =
  print_string "mini-xv6: OCaml on the Pi1\n";
  let l = upto 99999 [] in
  Gc.full_major ();
  Printf.printf "a list of %d, its sum %d\n" (List.length l) (List.fold_left ( + ) 0 l);
  (try print_string (List.assoc 7 [ (1, "one") ]) with Not_found -> print_string "Not_found caught\n");
  print_string "halting\n"
