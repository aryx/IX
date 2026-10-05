(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* A tiny Raspberry Pi 4, in one file: the smallest machine a kernel
 * can run on, and one a bare-metal program for the real board runs on
 * too. mini-qemu (raspberry/) is QEMU's raspi4b, faithfully: every
 * device xv6 touches, the MMU, four cores, USB, the framebuffer. This
 * is what is left when the kernel is one we write: TinyCPUArm's CPU
 * (TinyLibArm) with what a kernel sees below the system call. Its
 * usage and examples: [help], what tiny-pi -h prints.
 *
 * What a machine adds to a CPU, and nothing else:
 *
 * - {b Exception levels.} EL0 (the programs), EL1 (the kernel), EL2
 *   (where the firmware leaves the kernel's image: it goes down to EL1
 *   itself). Each has its own stack pointer, swapped in when the level
 *   is entered. The state beside the registers: the flags (the CPU's),
 *   the four masks (DAIF; I is the interrupts'), the level.
 * - {b Exceptions.} An svc, an undefined word, an interrupt, all taken
 *   to EL1: the state saved in SPSR_EL1, the return address in ELR_EL1,
 *   the cause in ESR_EL1 (its top six bits: 0x15 an svc, 0 an unknown
 *   word), the masks set, the pc at a vector, VBAR_EL1 plus 0x400
 *   (from EL0) or 0x200 (from EL1), plus 0x80 for an interrupt. Back
 *   with eret: the state from SPSR, the pc from ELR, at once.
 * - {b The system instructions}, which the CPU's subset leaves out:
 *   mrs and msr (a system register read or written), eret, wfi (wait
 *   for an interrupt). The CPU hands TinyMachinePi the words it does not
 *   know; from EL0 they are undefined.
 * - {b An interrupt between two instructions}: when a device's line is
 *   up, the controller lets it through, and I is clear.
 * - {b Three devices at the Pi 4's addresses}, each a few registers,
 *   behind the CPU's load and store, or behind mrs and msr: the PL011
 *   UART (0xfe201000: DR written, a character out, read, a character
 *   in; FR, never full, empty when nothing came; IMSC, the receive
 *   interrupt); the CPU's own virtual timer (the system registers
 *   CNTFRQ_EL0, the counter's frequency, CNTVCT_EL0, the counter,
 *   CNTV_TVAL_EL0, the ticks to the next interrupt, CNTV_CTL_EL0, its
 *   enable and mask); the interrupt controller, a GIC-400 (its
 *   distributor at 0xff841000: on, and each line's enable; this CPU's
 *   interface at 0xff842000: on, the priority mask, IAR which
 *   acknowledges the line that interrupts, EOIR which ends it). The
 *   timer's line is 27, the UART's 153.
 * - {b Time from instructions}: [ips] instructions a simulated
 *   microsecond (default 30, mini-qemu's), the counter at QEMU's 62.5
 *   MHz; a WFI with nothing pending jumps to the timer's next
 *   interrupt (and waits for a terminal's key, up to 10ms of the
 *   host's). With interrupts masked and none pending, a WFI never
 *   wakes: the machine has halted, and tiny-pi exits.
 *
 * The program is a raw image (TinyAssembler's -raw 0x80000), loaded at
 * 0x80000 and entered there at EL2 with the four masks set, as the Pi
 * 4's firmware starts kernel8.img and QEMU a raw -kernel; its vectors
 * are its own to write. The memory is 16MB from 0.
 *
 * Left out, against mini-qemu's Pi 4: the MMU (the CPU fetches from
 * physical memory), EL3, the other three cores, the stack pointer
 * SP_EL0 used above EL0, FIQ and the aborts (a bad address stops
 * tiny-pi), the physical timer, the controller's priorities, groups
 * and targets (one priority: an interrupt is not interrupted), the
 * UART's transmit interrupt and its FIFOs' levels, the mailbox, the
 * framebuffer, USB, the SD card. Exercises: a shell on the UART
 * (echo.s's interrupt, a line kept until Enter); the physical timer
 * (CNTP, line 30); a second core, parked until the kernel writes its
 * entry at 0xe0; an MMU (a fetch hook in TinyLibArm first).
 *
 * The tests: TinyMachinePi_test.sh assembles TinyMachinePi_tests/*.s
 * with TinyAssembler; runs each here, under mini-qemu and under QEMU
 * (raspi4b), the console the same; and checks its laws: the interrupts
 * counted, the simulated time when it halts.
 *
 * References: Arm Architecture Reference Manual for A-profile (ARM DDI
 * 0487; from memory): the levels, the exceptions' entry and return,
 * the system registers, the generic timer; ARM Generic Interrupt
 * Controller Architecture Specification v2 (IHI 0048; from memory);
 * mini-qemu's raspberry/ (Pi4, Gic, Pl011), itself checked against
 * QEMU and xv6, and QEMU's raspi4b, run on the three test programs:
 * the behavior; mini-qemu's Main for a terminal as a serial line. *)

open Common

let usage = "usage: tiny-pi [-ips N] [-s] kernel8.img"

(* -h: how, by examples, each one as it runs *)
let help = usage ^ {|
A Raspberry Pi 4 for a bare-metal program: its image loaded at 0x80000 and
entered at EL2, as the firmware starts kernel8.img. ./tiny-pi assembles and
runs the tests' programs by name, or under mini-qemu (-m) and QEMU (-q). In
tiny/TinyMachinePi_tests/, for example:
  tiny-assembler -e _start -raw 0x80000 -o tick.img tick.s
  tiny-pi tick.img          TinyMachinePi: a kernel, at EL1 ... tick 5
  tiny-pi -s tick.img       at the halt: the instructions, the interrupts, the time
  tiny-pi -ips 10 tick.img  10 instructions a simulated microsecond (30)
  tiny-pi echo.img          the UART is this terminal, raw: what is typed, in
                            upper case; ^D ends it, ^C quits tiny-pi
|}

module A = TinyLibArm

(*****************************************************************************)
(* The machine *)
(*****************************************************************************)

(* The UART's input, as tiny-machine's console (TinyMachine.ml): nothing
 * read before a program asks (reads FR or DR, or enables the receive
 * interrupt); then standard input polled, every 1024 instructions and
 * at a WFI, a terminal in raw mode as mini-qemu puts it: the keys one
 * at a time, not echoed, Enter a \r, as a serial line gives them (^C
 * still quits tiny-pi). A PL011 has no end of input: at its end, the
 * receive FIFO stays empty. *)
(* old: as tiny-machine, a file or a pipe read whole when opened, so
 * that a run is the same every time; but every program that writes
 * reads FR, and a pipe left open (a test's) then blocked it. A file is
 * still read at the same instructions each run *)
type console = { mutable queue : string; mutable next : int; mutable eof : bool; mutable opened : bool }

let tty = Unix.isatty Unix.stdin

let console_open k =
  if not k.opened then begin
    k.opened <- true;
    if tty then begin
      let a = Unix.tcgetattr Unix.stdin in
      at_exit (fun () -> Unix.tcsetattr Unix.stdin TCSANOW a);
      Sys.set_signal Sys.sigint (Sys.Signal_handle (fun _ -> exit 130));
      Unix.tcsetattr Unix.stdin TCSANOW { a with c_icanon = false; c_echo = false; c_icrnl = false; c_vmin = 1 }
    end
  end

(* a terminal's bytes, when some are there, waited for up to [wait]
 * seconds *)
let console_poll ~wait k =
  if k.opened && not k.eof && k.next >= String.length k.queue then
    match Unix.select [ Unix.stdin ] [] [] wait with
    | [], _, _ -> ()
    | _ ->
        let b = Bytes.create 256 in
        let n = Unix.read Unix.stdin b 0 256 in
        if n = 0 then k.eof <- true else (k.queue <- Bytes.sub_string b 0 n; k.next <- 0)

let received k = k.next < String.length k.queue

type t = {
  m : A.machine;
  mutable el : int;                    (* the level: 0, 1 or 2 *)
  mutable daif : int;                  (* the masks, at their bits of the state: 9 to 6; I is 7 *)
  sps : int64 array;                   (* the stack pointers of the levels not current *)
  regs : (int, int64) Hashtbl.t;       (* the system registers that only hold what was written *)
  (* the devices *)
  out : char -> unit;
  cons : console;
  mutable imsc : int;                  (* the UART's interrupt mask *)
  mutable ctl : int;                   (* the timer's enable (1) and mask (2) *)
  mutable cval : int;                  (* its next interrupt, a value of the counter *)
  mutable distributor : bool;          (* the controller's two switches *)
  mutable interface : bool;
  mutable pmr : int;                   (* the priorities let through: none at 0 *)
  enabled : int array;                 (* the lines' enables, 32 a word *)
  mutable active : int;                (* the line acknowledged and not ended, or -1 *)
  (* the time *)
  ips : int;
  mutable instructions : int;
  mutable skipped : int;               (* microseconds jumped by WFIs *)
  mutable waiting : bool;
  mutable interrupts : int;
}

let size = 1 lsl 24                      (* memory: 16MB from address 0 *)
let origin = 0x80000

let create ~out ~ips =
  { m = A.create size; el = 2; daif = 0x3c0; sps = Array.make 3 0L; regs = Hashtbl.create 16;
    out; cons = { queue = ""; next = 0; eof = false; opened = false }; imsc = 0;
    ctl = 0; cval = 0; distributor = false; interface = false; pmr = 0; enabled = Array.make 8 0; active = -1;
    ips; instructions = 0; skipped = 0; waiting = false; interrupts = 0 }

(* the time in microseconds, and the counter: 62.5 ticks each *)
let now t = (t.instructions / t.ips) + t.skipped
let frequency = 62_500_000
let count t = now t * 125 / 2

(* a system register's name in an instruction: op0, op1, CRn, CRm, op2,
 * the word's bits 20 to 5 *)
let sys op0 op1 cn cm op2 = (op0 lsl 14) lor (op1 lsl 11) lor (cn lsl 7) lor (cm lsl 3) lor op2
let spsr_el1 = sys 3 0 4 0 0 and elr_el1 = sys 3 0 4 0 1 and sp_el0 = sys 3 0 4 1 0 and current_el = sys 3 0 4 2 2
let daif = sys 3 3 4 2 1 and spsr_el2 = sys 3 4 4 0 0 and elr_el2 = sys 3 4 4 0 1
let esr_el1 = sys 3 0 5 2 0 and vbar_el1 = sys 3 0 12 0 0
let cntfrq = sys 3 3 14 0 0 and cntvct = sys 3 3 14 0 2 and cntv_tval = sys 3 3 14 3 0 and cntv_ctl = sys 3 3 14 3 1

let held t r = Hashtbl.find_opt t.regs r ||| 0L

(* the state an exception saves and eret restores: the flags, the
 * masks, the level (and, above EL0, its own stack pointer) *)
let state t =
  let b f k = if f then 1 lsl k else 0 in
  b t.m.n 31 lor b t.m.z 30 lor b t.m.c 29 lor b t.m.v 28 lor t.daif lor (t.el lsl 2) lor (if t.el > 0 then 1 else 0)

(* a level entered: the stack pointer swapped with its own *)
let set_el t el =
  t.sps.(t.el) <- A.sp t.m 31;
  A.set_sp t.m 31 t.sps.(el);
  t.el <- el

(* an exception, to EL1: the state in SPSR_EL1, the return address in
 * ELR_EL1, the masks set, the pc at the vector ([kind]: 0, or 0x80 for
 * an interrupt) *)
let take t ~ret ~kind =
  if t.el = 2 then A.error "an exception at EL2, at 0x%x" t.m.pc;
  Hashtbl.replace t.regs spsr_el1 (Int64.of_int (state t));
  Hashtbl.replace t.regs elr_el1 (Int64.of_int ret);
  let from = if t.el = 0 then 0x400 else 0x200 in
  set_el t 1;
  t.daif <- 0x3c0;
  t.m.pc <- Int64.to_int (held t vbar_el1) + from + kind

(*****************************************************************************)
(* The devices *)
(*****************************************************************************)

let io = 0xfe000000
let uart = io + 0x201000 and gicd = 0xff841000 and gicc = 0xff842000

(* the lines that are up: the timer's, 27, when its counter has passed
 * its value; the UART's, 153, on a character received (RXIM or RTIM,
 * 0x50) *)
let rx t = if received t.cons then 0x50 else 0
let lines t = (if t.ctl = 1 && count t >= t.cval then [ 27 ] else []) @ (if rx t land t.imsc <> 0 then [ 153 ] else [])

(* the one the controller presents: up, enabled, not already taken *)
let pending t =
  if t.distributor && t.interface && t.pmr > 0 && t.active < 0
  then List.find_opt (fun id -> t.enabled.(id / 32) land (1 lsl (id mod 32)) <> 0) (lines t) else None
let interrupting t = pending t <> None

let read t a =
  let b f = if f then 1 else 0 in
  if a = uart then (console_open t.cons; if received t.cons then (t.cons.next <- t.cons.next + 1; Char.code t.cons.queue.[t.cons.next - 1]) else 0)
  else if a = uart + 0x18 then (console_open t.cons; if received t.cons then 0x80 else 0x90)   (* FR: TXFE, and RXFE *)
  else if a = uart + 0x38 then t.imsc
  else if a = uart + 0x3c then rx t
  else if a = uart + 0x40 then rx t land t.imsc
  else if a = gicd then b t.distributor
  else if a >= gicd + 0x100 && a < gicd + 0x120 then t.enabled.((a - gicd - 0x100) / 4)
  else if a = gicc then b t.interface
  else if a = gicc + 4 then t.pmr
  (* IAR: the line that interrupts, now taken; 1023 when none *)
  else if a = gicc + 0xc then (match pending t with Some id -> t.active <- id; id | None -> 1023)
  else 0

let write t a v =
  if a = uart then t.out (Char.chr (v land 0xff))
  else if a = uart + 0x38 then (t.imsc <- v land 0x7ff; if v land 0x50 <> 0 then console_open t.cons)
  else if a = gicd then t.distributor <- v land 1 = 1
  else if a >= gicd + 0x100 && a < gicd + 0x120 then (let k = (a - gicd - 0x100) / 4 in t.enabled.(k) <- t.enabled.(k) lor v)
  else if a >= gicd + 0x180 && a < gicd + 0x1a0 then (let k = (a - gicd - 0x180) / 4 in t.enabled.(k) <- t.enabled.(k) land lnot v)
  else if a = gicc then t.interface <- v land 1 = 1
  else if a = gicc + 4 then t.pmr <- v land 0xff
  else if a = gicc + 0x10 then t.active <- -1                  (* EOIR: ended *)

(* the system registers: the state's, the timer's, and the ones that
 * hold a value (the vectors' address, an exception's three) *)
let read_sys t r =
  if r = current_el then Int64.of_int (t.el lsl 2)
  else if r = daif then Int64.of_int t.daif
  else if r = sp_el0 then t.sps.(0)
  else if r = cntfrq then Int64.of_int frequency
  else if r = cntvct then Int64.of_int (count t)
  else if r = cntv_tval then Int64.of_int (t.cval - count t)
  else if r = cntv_ctl then Int64.of_int (t.ctl lor (if count t >= t.cval then 4 else 0))
  else held t r

let write_sys t r v =
  if r = daif then t.daif <- Int64.to_int v land 0x3c0
  else if r = sp_el0 then t.sps.(0) <- v
  else if r = cntv_tval then t.cval <- count t + Int64.to_int (A.sext 32 v)
  else if r = cntv_ctl then t.ctl <- Int64.to_int v land 3
  else Hashtbl.replace t.regs r v

(* the microseconds to the timer's next interrupt *)
let until_timer t = if t.ctl = 1 then max 1 ((((t.cval - count t) * 2) + 124) / 125) else max_int

(*****************************************************************************)
(* Running *)
(*****************************************************************************)

exception Halted

(* the system instructions, TinyMachinePi's own, above EL0: true when
 * the word was one *)
let system t w =
  let m = t.m in
  if t.el = 0 then false
  else if w = 0xd69f03e0 then begin                             (* eret *)
    let v = Int64.to_int (held t (if t.el = 2 then spsr_el2 else spsr_el1)) and ret = held t (if t.el = 2 then elr_el2 else elr_el1) in
    let el = (v lsr 2) land 3 in
    if el > t.el || (el > 0 && v land 1 = 0) then A.error "eret to a state not modelled: %#x, at 0x%x" v m.pc;
    set_el t el;
    m.n <- v land (1 lsl 31) <> 0; m.z <- v land (1 lsl 30) <> 0; m.c <- v land (1 lsl 29) <> 0; m.v <- v land (1 lsl 28) <> 0;
    t.daif <- v land 0x3c0;
    m.pc <- Int64.to_int ret;
    true
  end
  else if w = 0xd503207f then (t.waiting <- true; m.pc <- m.pc + 4; true)                (* wfi *)
  else if w land 0xffd00000 = 0xd5100000 then begin                                      (* msr, mrs: bit 21 *)
    let r = (w lsr 5) land 0xffff and rt = w land 31 in
    if w land (1 lsl 21) <> 0 then A.set m rt (read_sys t r) else write_sys t r (A.reg m rt);
    m.pc <- m.pc + 4;
    true
  end
  else false

let env t = {
  A.load = (fun m size a -> if a >= io then Int64.of_int (read t a) else A.load m size a);
  store = (fun m size a v -> if a >= io then write t a (Int64.to_int v land 0xffffffff) else A.store m size a v);
  (* an svc: the pc is past it. ESR_EL1: its kind (0x15), a 32-bit
   * instruction, its number *)
  svc = (fun m n -> Hashtbl.replace t.regs esr_el1 (Int64.of_int ((0x15 lsl 26) lor (1 lsl 25) lor n)); take t ~ret:m.pc ~kind:0);
  (* a word the CPU does not know: a system instruction, or undefined,
   * the pc on it *)
  undefined = (fun m w -> if not (system t w) then (Hashtbl.replace t.regs esr_el1 (Int64.of_int (1 lsl 25)); take t ~ret:m.pc ~kind:0));
}

(* one instruction, or an interrupt taken, or the time to the next
 * event when waiting *)
let step t =
  let masked = t.daif land 0x80 <> 0 in
  if interrupting t && not masked then begin
    t.waiting <- false;
    t.interrupts <- t.interrupts + 1;
    take t ~ret:t.m.pc ~kind:0x80
  end
  else if t.waiting then begin
    if masked && not (interrupting t) then raise Halted;
    (* a terminal waited for, not spun on, while nothing else comes *)
    if not (interrupting t) then (console_poll ~wait:0.01 t.cons; t.skipped <- t.skipped + min (until_timer t) 1_000_000);
    if masked then t.waiting <- false
  end
  else begin
    A.step (env t) t.m;
    t.instructions <- t.instructions + 1
  end

(*****************************************************************************)
(* The command line *)
(*****************************************************************************)

let main (caps : < Cap.argv; Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr; .. >) =
  let args = List.tl (Array.to_list (CapSys.argv caps)) in
  let rec opts ips stats = function
    | "-ips" :: n :: rest -> opts (int_of_string n) stats rest
    | "-s" :: rest -> opts ips true rest
    | rest -> ips, stats, rest in
  try
    match opts 30 false args with
    | _, _, ("-h" | "--help") :: _ -> Console.print caps help; 0
    | ips, stats, [ file ] when file.[0] <> '-' ->
        let (_ : < Cap.stdin; .. >) = caps in
        let t = create ~out:(fun c -> Console.print caps (String.make 1 c); flush stdout) ~ips in
        let img = Files.read caps (Fpath.v file) in
        Bytes.blit_string img 0 t.m.mem origin (String.length img);
        t.m.pc <- origin;
        let n = ref 0 in
        (try while true do step t; incr n; if !n land 1023 = 0 then console_poll ~wait:0.0 t.cons done with Halted -> ());
        if stats then
          Console.eprint caps (Printf.sprintf "tiny-pi: halted after %d instructions, %d interrupts, at %d us\n" t.instructions t.interrupts (now t));
        0
    | _ -> Console.eprint caps (usage ^ "   (-h: how)\n"); 2
  with A.Error e | Sys_error e | Failure e -> Console.eprint caps ("tiny-pi: " ^ e ^ "\n"); 1

let () = Cap.main (fun caps -> CapStdlib.exit caps (main caps))
