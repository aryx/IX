(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-xv6, step 2 (plan_kernel.md): a trap and a user program. The
 * kernel enters user mode; the program's system calls come back
 * through start.s's trap entry and machine.c's trap(), which calls
 * [trap] here (registered by name); the kernel reads the call's number
 * and arguments as xv6 arm-pi1 lays them out, does it, and the program
 * resumes with the result in r0.
 *
 * What it checks: an OCaml function running on the kernel's stack under
 * a trap, below the frames that entered user mode, the GC collecting
 * there (a full major collection at each trap) and seeing its roots.
 *
 * The second rung of the ladder (step1's Main.ml draws it). One
 * stack, used twice:
 *
 *     the kernel's stack
 *     +---------------------+
 *     | OCaml: the boot     |  called user_enter, which does not
 *     | C: user_enter       |  return: it drops to user mode
 *     +---------------------+
 *     | the trap frame      |  17 words, saved by start.s at the svc
 *     | C: trap()           |
 *     | OCaml: [trap] below |  runs, collects, returns; the frame is
 *     +---------------------+  loaded back and the program goes on
 *
 * What this kernel does not have yet, and what it costs: no MMU,
 * so the program's addresses are physical and [arg] reads the
 * user's stack with no check at all (step4 is where a user's
 * pointer stops being believed); one program, linked in the
 * kernel's image; no interrupt.
 *
 * terminology:
 * User mode and kernel mode are the processor's: a bit of its
 * status register (the CPSR's mode field on ARM) that says whether
 * the instructions that touch the machine itself are allowed. The
 * only ways from the first to the second are the traps, which all
 * enter at addresses the kernel chose (the vectors); svc is the
 * trap a program makes on purpose. mini-xv6's Syscall.mli follows
 * a call the whole way. *)

(*****************************************************************************)
(* The machine (machine.c) *)
(*****************************************************************************)

(* the memory, by physical address (no MMU yet) *)
module Mem = struct
  external get8 : int -> int = "mem_get8"
  external get32 : int -> int = "mem_get32"
  external set32 : int -> int -> unit = "mem_set32"
end

external uart_putc : int -> unit = "uart_putc"
external halt : unit -> unit = "machine_halt"
external user_enter : int -> int -> unit = "user_enter"
external trapframe_addr : unit -> int = "trapframe_addr"
external user_entry : unit -> int = "user_entry"
external user_stack : unit -> int = "user_stack"

let print s = for i = 0 to String.length s - 1 do uart_putc (Char.code s.[i]) done

(* the trap frame, start.s's 17 words: r0-r12, the user's sp and lr,
 * the pc to go back to, the user's CPSR *)
module Trapframe = struct
  let base = trapframe_addr ()
  let r n = Mem.get32 (base + (4 * n))
  let set_r n v = Mem.set32 (base + (4 * n)) v
  let sp () = r 13
end

(*****************************************************************************)
(* The system calls *)
(*****************************************************************************)

(* xv6 arm-pi1's: the number in r0, the arguments on the user's stack *)
let arg n = Mem.get32 (Trapframe.sp () + (4 * n))

let sys_exit = 2
let sys_write = 16

let calls = ref 0

let syscall () =
  incr calls;
  let n = Trapframe.r 0 in
  if n = sys_write then begin
    let fd = arg 0 and buf = arg 1 and len = arg 2 in
    if fd <> 1 && fd <> 2 then -1
    else begin
      for i = 0 to len - 1 do uart_putc (Mem.get8 (buf + i)) done;
      len
    end
  end
  else if n = sys_exit then begin
    print (Printf.sprintf "mini-xv6: the program exited, status %d, after %d system calls\n" (arg 0) !calls);
    halt ();
    0
  end
  else begin
    print (Printf.sprintf "mini-xv6: unknown system call %d\n" n);
    -1
  end

(* the trap, from machine.c: an exception must not escape into C *)
let trap () =
  try
    Gc.full_major ();
    Trapframe.set_r 0 (syscall ())
  with e ->
    print ("mini-xv6: an exception in a trap: " ^ Printexc.to_string e ^ "\n");
    halt ()

let () =
  Callback.register "trap" trap;
  print "mini-xv6: step 2, a program in user mode\n";
  user_enter (user_entry ()) (user_stack ())
