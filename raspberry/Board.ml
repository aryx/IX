(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Board.mli *)

type config = {
  pi2 : bool;                       (* a Pi 2 (QEMU's raspi2b), not a Pi 1 *)
  ram_size : int; ips : int; log : string -> unit; usb_devices : string list;   (* -device's USB ones, in order: "usb-kbd", "usb-mouse" *)
  sd : Sdhost.storage option;
  serial0 : char -> unit;            (* the PL011 *)
  serial1 : char -> unit;            (* the mini UART *)
  console : int;                     (* the serial the host's input goes to *)
}

(* the ARM1176's CP15 registers other than the MMU's *)
type cp15 = {
  mutable actlr : int;
  mutable cpacr : int;
  mutable dfsr : int;
  mutable ifsr : int;
  mutable dfar : int;
  mutable ifar : int;
  mutable fcse : int;
  mutable contextid : int;
  tpid : int array;
  mutable csselr : int;             (* the Pi 2's: the cache CCSIDR is about *)
}

(* A core of the Pi 2's four (plan_multicore.md, decision 9): what is
 * its own. Its registers, its MMU, its CP15, its decode cache (by
 * virtual address: each core has its own table of pages); whether it
 * waits (a WFI, until an interrupt of its own is pending); its
 * virtual timer (CNTV: the kernel's tick on a core other than the
 * first), its four mailboxes, and which of them and of its timers
 * interrupt it (the cores' controller, the BCM2836's at 0x40000000). *)
type core = {
  id : int;                         (* 0 to 3 *)
  cst : Arm32_isa.state;
  cmmu : Mmu32.t;
  ccp : cp15;
  (* the decode cache: by virtual address, bit 0 set when fetched in
   * user mode; emptied with the TLB and by I-cache invalidations *)
  ctags : int array;
  ccode : Arm32_isa.t array;
  cused : int array;
  mutable cused_n : int;            (* more than used_max: not all are in [cused] *)
  kept_words : int array;           (* a word's decoding kept (keep_decoded, below) *)
  kept_code : Arm32_isa.t array;
  mutable local_irq : bool;         (* its own interrupt (its timer, a mailbox) is pending *)
  mutable wfi : bool;               (* a WFI: its batch ends, time may jump to the next event *)
  mutable yielded : bool;           (* the batch ended for a device (Pwm) or a WFE, not for a WFI: no time skipped *)
  (* asked by another core that runs at the same time (cores_parallel):
   * its decode cache emptied, its TLB too *)
  forget_asked : bool Atomic.t;
  flush_asked : bool Atomic.t;
  mutable started : bool;           (* given somewhere to start (-device loader,cpu-num=) *)
  mutable asleep : bool;
  mutable cntv_ctl : int;
  mutable cntv_cval : int;          (* in the board's microseconds *)
  mail : int array;
  mutable timer_ctl : int;
  mutable mail_ctl : int;
  mutable cran : int;
}

(* The board runs one core at a time, in turns (a batch each), in one
 * thread: the same run each time. A Pi 1 is one core. What the cores
 * share is here: the memory, the devices, the time; [cur] is the core
 * whose turn it is, for a device that must know who wrote to it.
 * (old: [st], [mmu], [cp], [tags], [code], [used], [local_irq], [wfi]
 * and [yielded] were here too, the running core's, put there when its
 * turn came (select), so that the loop and CP15's code read one
 * board; each function now takes its core, so that two cores can run
 * at the same time on two domains: plan_multicore.md, stage 4.) *)
type t = {
  mem : Memory.t;
  mutable cores : core array;
  mutable cur : int;
  (* a core a domain (cores_parallel, below): the lock of what the
   * cores share but the memory (the devices, the time, [asleep]); the
   * cores that wait, on [wake]; who calls [run], on [tick] *)
  par : bool;
  lock : Parallel.lock;
  wake : Parallel.cond;
  tick : Parallel.cond;
  mutable ticked : bool;
  mutable spawned : bool;
  mutable failed : exn option;      (* what stopped a core's domain *)
  intc : Intc.t;
  timer : Systimer.t;
  pwm : Pwm.t;                     (* the jack's sound *)
  uart : Pl011.t;
  mini : Miniuart.t;
  (* claude: since the last [where]: the instructions run, and the
   * time skipped at WFIs (in instructions) *)
  mutable ran : int;
  mutable waited : int;
  mutable cfg : config;
  mutable instructions : int;
  mutable time_left : int;          (* instructions not yet a microsecond *)
  mutable undefined : int list;     (* the words already reported *)
  inq : char Queue.t;               (* the host's characters, for the UART *)
  fb : Framebuffer.t;
  keyboard : Usb.device option;
  mouse : Usb.device option;
  mutable key_events : (int * int * bool) list;   (* at a microsecond: a usage, down *)
}

let cache_bits = 16
(* the I/O space: the BCM2835's, and the BCM2836's (the same devices) *)
let io_of cfg = if cfg.pi2 then 0x3f000000 else 0x20000000

(*****************************************************************************)
(* Faster: the decode cache emptied, and filled again *)
(*****************************************************************************)

(* The decode cache is emptied with the TLB and at each invalidation of
 * the I-cache, which Plan 9 asks at every switch of process and every
 * page of text brought in: some 36,000 times while mini-9pi boots, one
 * every 10,000 instructions. Two switches, each a few lines:
 *
 * - [forget_used]: the slots filled since the cache was last emptied
 *   are remembered (up to [used_max] of them), and emptying it is
 *   those slots only, not the 65,536. (The fill was 3% of the time by
 *   JavaScript.)
 * - [keep_decoded]: what a word decodes to is kept by the word, in a
 *   table that nothing empties (a word means the same wherever it is
 *   and whoever runs it); after the cache is emptied an instruction
 *   is fetched again but not decoded again, and no new value is made
 *   for the collector. As tiny-machine's (TinyMachineCPU). A table a
 *   core: two cores would write its two halves at the same time. *)
let forget_used = ref true
let keep_decoded = ref true

(* (old: used and used_n were the module's, the one core's, then the
 * running core's in the board; kept_words and kept_code the module's) *)
let used_max = 4096

let kept_bits = 14

let decode (c : core) w =
  if not !keep_decoded then Arm32.decode w
  else begin
    let k = (w lxor (w lsr 12) lxor (w lsr 22)) land ((1 lsl kept_bits) - 1) in
    if c.kept_words.(k) = w then c.kept_code.(k)
    else begin
      let i = Arm32.decode w in
      c.kept_words.(k) <- w; c.kept_code.(k) <- i; i
    end
  end

(* a slot of the cache filled *)
let fill (c : core) slot key i =
  if !forget_used && c.ctags.(slot) = -1 then begin
    if c.cused_n < used_max then c.cused.(c.cused_n) <- slot;
    c.cused_n <- c.cused_n + 1
  end;
  c.ctags.(slot) <- key; c.ccode.(slot) <- i

(* Blocks: runs of instructions translated by the host and run without
 * this module's loop (web/jit's Jit, for a page: ARM to JavaScript).
 * The loop below asks at each instruction it is about to run, when
 * [blocks_on] and the MMU is on: [blocks] is given the decode cache's
 * key (the pc, and bit 0 when in user mode) and says how many
 * instructions it ran from there, 0 when it has no block: the
 * interpreter then runs that one. A block that raises (an abort, an
 * instruction not there) leaves r15 at the instruction's address + 8,
 * as the interpreter, and [blocks_done] then says how many
 * instructions ran, that one counted. [blocks_forget]: the I-cache
 * was invalidated, any instruction may have changed (not said when the
 * TLB is emptied: a block is found through the TLB each time).
 * [blocks_written]: the instructions of these physical addresses
 * changed, as a kernel built for a page says it (the request 5,
 * below), where a Pi's kernel invalidates all of the I-cache at each
 * page it writes. *)
let blocks_on = ref false
let blocks : (int -> int) ref = ref (fun _ -> 0)
let blocks_done : (unit -> int) ref = ref (fun () -> 1)
let blocks_forget : (unit -> unit) ref = ref ignore
let blocks_written : (int -> int -> unit) ref = ref (fun _ _ -> ())

(* the decode cache emptied (old: Array.fill t.tags 0 (1 lsl cache_bits) (-1)) *)
let forget (c : core) =
  if !forget_used && c.cused_n <= used_max then
    for k = 0 to c.cused_n - 1 do c.ctags.(c.cused.(k)) <- -1 done
  else Array.fill c.ctags 0 (1 lsl cache_bits) (-1);
  c.cused_n <- 0

(* (old: select t k, the running core's parts put in the board's
 * fields when its turn came) *)

(* Another core, which runs at the same time (cores_parallel), asked
 * to empty a cache of its own: only it may write it. Its batch is
 * ended as a WFE ends it, so that it looks before its next
 * instruction but one; a core that waits looks when it wakes. *)
let ask (o : core) (what : bool Atomic.t) = Atomic.set what true; o.yielded <- true; o.wfi <- true

(* every core's decode cache emptied (an instruction cache invalidated
 * on all of them: ICIALLUIS, and a kernel's word that it wrote code),
 * by the core [k] *)
let forget_all t (k : core) =
  Array.iter (fun (c : core) -> if c.started then (if t.par && c != k then ask c c.forget_asked else forget c)) t.cores

(* (the TLB emptied. For the blocks: nothing, when the kernel says
 * which pages of instructions it writes ([code_told], the request 5: a
 * block is found through the TLB each time); else as an I-cache's
 * invalidation, a kernel that says nothing of what it writes
 * (mini-xv6, which no cache of QEMU's ever asked) being trusted no
 * further than the decode cache trusts it: emptied here too.) *)
let code_told = ref false
let flush (c : core) = Mmu32.flush c.cmmu; forget c; if !blocks_on && not !code_told then !blocks_forget ()

(* (every core's, by the core [k]) *)
let flush_all t (k : core) =
  Array.iter (fun (c : core) -> if c.started then (if t.par && c != k then ask c c.flush_asked else flush c)) t.cores

(*****************************************************************************)
(* Faster: a core a domain *)
(*****************************************************************************)

(* The Pi 2's cores each on a domain of the host's, where the compiler
 * has domains (OCaml 5: Parallel.available) and when asked
 * ([cores_parallel], read by create; mini-qemu's -cores-parallel):
 * four busy cores then take one's time on the host and not four
 * times. Off, and under OCaml 4.14 whatever is asked, the cores take
 * turns in one thread, and a run is the same each time: what the
 * tests run. On, it is not: who gets a lock first is the host's
 * scheduler's.
 * (plan_multicore.md, decisions 10 to 12.)
 *
 *     the main domain           a domain a started core
 *     ----------------------    --------------------------------
 *     run: waits for a tick,    turn after turn (core_main); a WFI
 *     then the keys timed and   with nothing pending: waits on
 *     the UART's input; when    [wake]. The first core that does not
 *     every core waits, the     wait counts the time: its
 *     time to the next event    instructions are the board's clock
 *     the host's window, QMP    (advance), and it ticks
 *
 * What the cores share, and how:
 * - the memory: nothing. Two cores that write a word at once are the
 *   guest's race, as on the board. (Memory's cache of the last
 *   segment is shared too: a board has one segment of RAM, so it is
 *   written once.)
 * - strex: a lock of its own, and the word must still be what ldrex
 *   read (Arm32.strex; QEMU's way). It can be stored where the
 *   board's would not, when another core wrote the same value back
 *   in between: a lock's word, taken and given back, does not mind.
 * - the devices, the interrupt controller, the time: [lock], taken
 *   around each access to a device (create's shared), around the
 *   time's advance, and by who calls into the board from outside
 *   ([locked]: a key, the console's output read). A device is touched
 *   rarely against an instruction. The interrupt lines are read
 *   without it at each instruction: a word.
 * - a core's registers, MMU and caches: its own, written by its
 *   domain only; another core asks ([ask]).
 * Not safe there, and so the first core's only: Prof's counts. *)
let cores_parallel = ref false

(* with the lock, when the cores run at the same time *)
let hold t f =
  if not t.par then f ()
  else begin
    Parallel.take t.lock;
    match f () with
    | v -> Parallel.give t.lock; v
    | exception e -> Parallel.give t.lock; raise e
  end

(*****************************************************************************)
(* CP15 *)
(*****************************************************************************)

(* the ARM1176JZF-S's identification, as QEMU's arm1176 *)
let midr = 0x410fb767 and ctr = 0x1dd20d2

(* The Pi 2's Cortex-A7 (r0p5), where a kernel may ask: who it is, which
 * core (MPIDR: the first of four), and its caches, which an ARMv7
 * kernel empties by walking them (CLIDR: two levels, the first a data
 * and an instruction cache, the second one for both; CCSIDR by CSSELR:
 * 32KB in 4 ways, 32KB in 2, 512KB in 8, lines of 64 bytes). mini-9pi
 * walks them when it turns its caches on. The rest of its CP15 reads
 * as the ARM1176's: the cycle counter (c9) zero, as the ARM1176's
 * (c15) here. *)
let midr_a7 = 0x410fc075 and ctr_a7 = 0x84448003 and mpidr_a7 = 0x80000f00
let clidr_a7 = 0x0a200023
let ccsidr_a7 k = match k with 0 -> 0x700fe01a | 1 -> 0x201fe00a | 2 -> 0x707fe03a | _ -> 0

(* a core's own interrupt: its virtual timer's when its time has come,
 * it is on and not masked, and the controller routes it (bit 3); a
 * mailbox's that has a bit set and is routed *)
let core_irq t (c : core) =
  (c.cntv_ctl land 3 = 1 && c.timer_ctl land 8 <> 0 && Systimer.now t.timer >= c.cntv_cval)
  || (c.mail_ctl land 15 <> 0
      && ((c.mail.(0) <> 0 && c.mail_ctl land 1 <> 0) || (c.mail.(1) <> 0 && c.mail_ctl land 2 <> 0)
          || (c.mail.(2) <> 0 && c.mail_ctl land 4 <> 0) || (c.mail.(3) <> 0 && c.mail_ctl land 8 <> 0)))

(* what ends a core's wait: its own interrupt, and for the first the
 * devices' *)
let pending t (c : core) = core_irq t c || (c.id = 0 && (Intc.irq t.intc || Intc.fiq t.intc))

(* the cores that wait told to look again when one has its interrupt
 * (with the lock) *)
let wake t = if t.par && Array.exists (fun (c : core) -> c.asleep && pending t c) t.cores then Parallel.broadcast t.wake

(* what touches the board from outside its cores (a key, a character
 * typed, the console's output taken): with the lock when the cores are
 * domains, and the cores that wait told *)
let locked t f = hold t (fun () -> let v = f () in wake t; v)

let set_sctlr (k : core) v =
  k.cmmu.sctlr <- v;
  k.cst.mmu <- v land 1 <> 0;
  k.cst.vectors <- (if v land (1 lsl 13) <> 0 then Bits.mask32 (0xffff lsl 16) else 0);
  flush k

(* (a core's own: k) *)
let mrc t (k : core) ~crn ~crm ~opc2 =
  let c = k.ccp and m = k.cmmu in
  match crn, crm, opc2 with
  | 0, 0, 0 -> if t.cfg.pi2 then midr_a7 else midr
  | 0, 0, 1 -> if t.cfg.pi2 then ctr_a7 else ctr
  | 0, 0, 5 when t.cfg.pi2 -> mpidr_a7 + k.id
  (* the generic timer: CNTFRQ (a count a microsecond here), CNTV_TVAL
   * and CNTV_CTL (bit 2: its time has come) *)
  | 14, 0, 0 when t.cfg.pi2 -> 1000000
  | 14, 3, 0 when t.cfg.pi2 -> Bits.mask32 (k.cntv_cval - Systimer.now t.timer)
  | 14, 3, 1 when t.cfg.pi2 -> k.cntv_ctl lor (if Systimer.now t.timer >= k.cntv_cval then 4 else 0)
  (* the feature registers, as QEMU's arm1176 (9pi reads ID_PFR1 and
   * ID_MMFR3) *)
  | 0, 1, k -> [| 0x111; 0x11; 0x33; 0; 0x01130003; 0x10030302; 0x01222100; 0 |].(k)
  | 0, 2, k when k <= 5 -> [| 0x0140011; 0x12002111; 0x11231111; 0x01102131; 0x141; 0 |].(k)
  | 1, 0, 0 -> m.sctlr | 1, 0, 1 -> c.actlr | 1, 0, 2 -> c.cpacr
  | 2, 0, 0 -> m.ttbr0 | 2, 0, 1 -> m.ttbr1 | 2, 0, 2 -> m.ttbcr
  | 3, 0, 0 -> m.dacr
  | 5, 0, 0 -> c.dfsr | 5, 0, 1 -> c.ifsr
  | 6, 0, 0 -> c.dfar | 6, 0, 2 -> c.ifar
  | 13, 0, 0 -> c.fcse | 13, 0, 1 -> c.contextid | 13, 0, k when k >= 2 && k <= 4 -> c.tpid.(k - 2)
  | _ -> 0

let mcr t (k : core) ~crn ~crm ~opc2 v =
  let c = k.ccp and m = k.cmmu in
  match crn, crm, opc2 with
  | 1, 0, 0 -> set_sctlr k v
  | 1, 0, 1 -> c.actlr <- v
  | 1, 0, 2 ->
      (* only cp10 and cp11's access is kept, the rest reading as QEMU
       * gives it (0xC0F00000 after 9pi's 0x0FFFFFFF); VFP granted with
       * both full *)
      c.cpacr <- (v land 0x00f00000) lor 0xc0000000;
      k.cst.vfp_ok <- c.cpacr land 0x00f00000 = 0x00f00000
  | 2, 0, 0 -> m.ttbr0 <- v; flush k | 2, 0, 1 -> m.ttbr1 <- v; flush k | 2, 0, 2 -> m.ttbcr <- v; flush k
  | 3, 0, 0 -> m.dacr <- v; flush k
  | 5, 0, 0 -> c.dfsr <- v | 5, 0, 1 -> c.ifsr <- v
  | 6, 0, 0 -> c.dfar <- v | 6, 0, 2 -> c.ifar <- v
  (* the caches: only an instruction cache's invalidation matters, the
   * decode cache's; the TLB's *)
  (* (old: | 7, (1 | 5 | 7), 0 -> forget t; ...: one core. ICIALLUIS,
   * c7 c1 0, is every core's) *)
  | 7, 1, 0 -> forget_all t k; if !blocks_on then !blocks_forget ()
  | 7, (5 | 7), 0 -> forget k; if !blocks_on then !blocks_forget ()
  | 7, 0, 4 -> k.wfi <- true                              (* wait for interrupt *)
  (* (the TLB of every core: c8 c3) *)
  | 8, 3, _ -> flush_all t k
  | 8, _, _ -> flush k
  | 14, 3, 0 when t.cfg.pi2 ->
      k.cntv_cval <- Systimer.now t.timer + (if v land 0x80000000 <> 0 then 0 else v); k.local_irq <- core_irq t k
  | 14, 3, 1 when t.cfg.pi2 -> k.cntv_ctl <- v land 3; k.local_irq <- core_irq t k
  | 13, 0, 0 -> c.fcse <- v | 13, 0, 1 -> c.contextid <- v | 13, 0, k when k >= 2 && k <= 4 -> c.tpid.(k - 2) <- v
  | _ -> ()                                              (* cache and write-buffer operations, c15's *)

(*****************************************************************************)
(* Faster: a kernel's copies and fills done by the host *)
(*****************************************************************************)

(* A kernel built for a page (kernels/lib_machine/web/) asks the board
 * to move or fill its bytes itself, where the Pi's kernel has a loop:
 * memmove and a page's zeros were a third of the instructions of
 * mini-9pi's boot (plan_web.md, stage 2). The request is a read of a
 * register of CP15 that no ARM1176 has,
 *   mrc p15, 7, r0, c15, c0, op    r0 to, r1 from (or the byte), r2 bytes
 * (op 0 a move, 1 a fill), and reads as 1 when the host did it, 0 when
 * it would not: the kernel then runs its own loop, and a fault is that
 * loop's. The host does it only when each range is RAM in one piece,
 * read or written by the mode asking; nothing is moved otherwise.
 * [host_calls] off: the instruction is undefined, as on the Pi. *)
let host_calls = ref true

(* where [n] bytes at [va] are, if they are RAM in one piece ([access]:
 * Mmu32's), or -1 *)
let one_piece t (c : core) (st : Arm32_isa.state) va n access =
  let user = st.mode = 0x10 in
  let at a = if st.mmu then Mmu32.translate c.cmmu ~user (Bits.mask32 a) access else Bits.mask32 a in
  try
    let pa = at va in
    let rec go off = off >= n || (at (va + off) = pa + off && go (off + 4096)) in
    if go (4096 - (va land 0xfff)) then (ignore (Memory.direct t.mem pa n); pa) else -1
  with Arm32.Abort _ | Memory.Fault _ | Invalid_argument _ -> -1

(* The keys, the mouse and the cursor of such a kernel (Kweb there),
 * when its host is a page: no USB keyboard nor mouse on the board, no
 * controller polled for them, no cursor drawn into the framebuffer a
 * hundred times a second. A USB mouse that moves costs mini-9pi 5
 * million instructions a second, of the 6 a page runs (Boot_bench
 * -move).
 *   op 2  r0 a buffer of 8 bytes: the next thing typed or pointed. 1, a
 *         keyboard's report in it (a USB keyboard's 8 bytes: the
 *         modifiers, 0, six keys down); 2, the mouse's: its buttons,
 *         then x and y on the screen, 16 bits each; 0, nothing.
 *   op 3  r0 the cursor's 66 bytes (its offset, two signed bytes; its
 *         clr then set bits, 16 by 16 each): 1 when the host draws the
 *         cursor ([host_cursor]), and the kernel then does not. *)
let host_cursor = ref false
let host_events : string Queue.t = Queue.create ()
let host_keys = ref []
let host_shape = ref (0, "")

(* a key down or up, by its usage: the report of all the keys down *)
let host_key usage down =
  host_keys := List.filter (fun u -> u <> usage) !host_keys;
  if down then host_keys := !host_keys @ [ usage ];
  let mods = List.fold_left (fun m u -> if u >= 224 && u <= 231 then m lor (1 lsl (u - 224)) else m) 0 !host_keys in
  let keys = List.filter (fun u -> u < 224) !host_keys in
  let b = Bytes.make 9 '\000' in
  Bytes.set b 0 '\001'; Bytes.set b 1 (Char.chr mods);
  List.iteri (fun i u -> if i < 6 then Bytes.set b (3 + i) (Char.chr (u land 0xff))) keys;
  Queue.add (Bytes.to_string b) host_events

(* the mouse at (x, y) of the screen, its buttons (1 left, 2 middle, 4
 * right, as Plan 9's). A move is kept apart, the last one only, until
 * it is read or a button changes: a kernel slower than the hand reads
 * where the mouse is, not where it went through *)
let host_buttons = ref 0
let host_move = ref ""
let host_pointer x y buttons =
  let e = Printf.sprintf "\002%c%c%c%c%c" (Char.chr (buttons land 7)) (Char.chr (x land 0xff)) (Char.chr ((x lsr 8) land 0xff))
      (Char.chr (y land 0xff)) (Char.chr ((y lsr 8) land 0xff)) in
  if buttons = !host_buttons then host_move := e
  else begin
    if !host_move <> "" then Queue.add !host_move host_events;
    host_move := ""; host_buttons := buttons;
    Queue.add e host_events
  end
let host_next () =
  match Queue.take_opt host_events with
  | Some e -> Some e
  | None -> if !host_move = "" then None else begin let e = !host_move in host_move := ""; Some e end

(*   op 4  r0 the 49 words of a draw (mini-9pi's Memdraw.hosted):
 *         memdraw's general loop by the host, when one is set here
 *         ([host_draw]: Hostdraw's, with the kernel's own file of that
 *         loop compiled for the host): 1 drawn, 0 not this one, -1 no
 *         host that draws. It is given the memory and how to find a
 *         range of it ([one_piece]: n bytes at an address, to write or
 *         not; the physical address, or -1). *)
let host_draw : (Memory.t -> (int -> int -> bool -> int) -> int -> int) ref = ref (fun _ _ _ -> -1)

(*   op 5  r0 a physical address, r1 a count: the instructions there
 *         were written (a program's page brought in). What was
 *         decoded is forgotten, and the blocks of those pages. *)
(* The screen's rows such a kernel wrote, for a host that shows only
 * what changed: the kernel's pixels reach the framebuffer by its moves
 * (mini-9pi's flush, a row at a time), which the board does. The host
 * says where the framebuffer is ([host_watch]: its first byte, the
 * bytes a row, the rows), and asks which rows were written since it
 * last asked ([host_rows]). A kernel may also write there by itself (a
 * console before its draw device): the host shows all of it now and
 * then. *)
(* the physical pages an instruction was fetched from (1 GB of them) *)
let code_pages = Bytes.make (1 lsl 18) '\000'
let code_page pa = let p = pa lsr 12 in if p < Bytes.length code_pages then Bytes.unsafe_set code_pages p '\001'

let watch_base = ref 0 and watch_pitch = ref 1 and watch_rows = ref 0
let dirty_lo = ref max_int and dirty_hi = ref (-1)
let host_watch ~base ~pitch ~rows = watch_base := base; watch_pitch := max 1 pitch; watch_rows := rows
let host_rows () =
  let r = if !dirty_hi < !dirty_lo then None else Some (!dirty_lo, !dirty_hi + 1) in
  dirty_lo := max_int; dirty_hi := -1; r
let touched pa n =
  let first = pa - !watch_base and last = pa + n - 1 - !watch_base in
  if !watch_rows > 0 && last >= 0 && first < !watch_pitch * !watch_rows then begin
    let lo = max 0 first / !watch_pitch and hi = min (!watch_rows - 1) (last / !watch_pitch) in
    if lo < !dirty_lo then dirty_lo := lo;
    if hi > !dirty_hi then dirty_hi := hi
  end

let host_call t (c : core) (st : Arm32_isa.state) op =
  let d = st.r.(0) and x = st.r.(1) and n = st.r.(2) in
  if op = 5 then begin
    code_told := true;
    (* (only when an instruction was ever fetched from these pages: a
     * kernel says so of every page it writes, a screen's rows too) *)
    let fetched = ref false and page = ref (d lsr 12) in
    while not !fetched && !page <= (d + x - 1) lsr 12 do
      if !page < Bytes.length code_pages && Bytes.unsafe_get code_pages !page <> '\000' then fetched := true;
      incr page
    done;
    if !fetched then begin forget_all t c; if !blocks_on then !blocks_written d x end;
    1
  end
  else if op = 4 then !host_draw t.mem (fun va n write -> one_piece t c st va n (if write then 1 else 0)) d
  else
  if op = 2 then begin
    match host_next () with
    | None -> 0
    | Some e ->
        let pd = one_piece t c st d 8 1 in
        if pd < 0 then 0
        else begin
          let b, o = Memory.direct t.mem pd 8 in
          Bytes.blit_string e 1 b o (String.length e - 1);
          Char.code e.[0]
        end
  end
  else if op = 3 then begin
    let ps = one_piece t c st d 66 0 in
    if ps < 0 || not !host_cursor then 0
    else begin
      let b, o = Memory.direct t.mem ps 66 in
      host_shape := (fst !host_shape + 1, Bytes.sub_string b o 66); 1
    end
  end
  else if n <= 0 || n > 1 lsl 26 then 0
  else
    let pd = one_piece t c st d n 1 in
    if pd < 0 then 0
    else if op = 1 then begin
      let b, o = Memory.direct t.mem pd n in
      touched pd n;
      Bytes.fill b o n (Char.unsafe_chr (x land 0xff)); 1
    end
    else
      let ps = one_piece t c st x n 0 in
      if ps < 0 then 0
      else begin
        (* (the source's bytes found last: the cache of the last RAM
         * segment may have changed between the two) *)
        let bd, od = Memory.direct t.mem pd n in
        let bs, os = Memory.direct t.mem ps n in
        touched pd n;
        Bytes.blit bs os bd od n; 1
      end

(* mcr, mrc, mcrr, the hints *)
let coproc t (c : core) (st : Arm32_isa.state) (i : Arm32_isa.t) =
  match i with
  | Coproc { cp = 15; opc1 = 7; load = true; crn = 15; crm = 0; opc2; rd; _ } when !host_calls && opc2 <= 5 && rd <> 15 ->
      st.r.(rd) <- host_call t c st opc2
  | Coproc { cp = 15; opc1 = 0; load = true; crn; crm; opc2; rd; _ } ->
      let v = mrc t c ~crn ~crm ~opc2 in
      if rd = 15 then Arm32.write_cpsr st v 8 else st.r.(rd) <- v
  | Coproc { cp = 15; opc1 = 0; load = false; crn; crm; opc2; rd; _ } -> mcr t c ~crn ~crm ~opc2 st.r.(rd)
  | Coproc2 { cp = 15; load = false; _ } -> ()            (* the ARM1176's cache range operations *)
  (* the Cortex-A7's caches: CCSIDR and CLIDR (opc1 1), CSSELR (2) *)
  | Coproc { cp = 15; opc1 = 1; load = true; crn = 0; crm = 0; opc2; rd; _ } when t.cfg.pi2 && opc2 <= 1 ->
      st.r.(rd) <- (if opc2 = 1 then clidr_a7 else ccsidr_a7 c.ccp.csselr)
  | Coproc { cp = 15; opc1 = 2; crn = 0; crm = 0; opc2 = 0; load; rd; _ } when t.cfg.pi2 ->
      if load then st.r.(rd) <- c.ccp.csselr else c.ccp.csselr <- st.r.(rd) land 0xf
  | Hint { hint = 3; _ } -> c.wfi <- true
  (* (WFE, with several cores: a core that waits for another's word
   * gives its turn up, and looks again at its next) *)
  | Hint { hint = 2; _ } when Array.length t.cores > 1 -> c.wfi <- true; c.yielded <- true
  (* (and YIELD: a core that spins for a lock another holds says so,
   * mini-9pi's klock_take; nothing it waits for changes in its turn) *)
  | Hint { hint = 1; _ } when Array.length t.cores > 1 -> c.wfi <- true; c.yielded <- true
  | Hint _ -> ()
  | _ -> raise (Arm32.Unimplemented (0, st.r.(15) - 8))

(*****************************************************************************)
(* The board *)
(*****************************************************************************)

(* the VideoCore's share, at the top of RAM: QEMU's raspi1ap gives it
 * 64MB of 512, its raspi2b 64 of 1024 (the framebuffer then at
 * 0x3C100000; the last 16MB of that GB are under the I/O space) *)
let vc_size = 64 * 1024 * 1024

let create cfg =
  let io = io_of cfg in
  let par = !cores_parallel && Parallel.available && cfg.pi2 in
  (* a device that the cores, each on a domain, reach one at a time;
   * [after]: the cores that wait told, an access may be an interrupt *)
  let lock = Parallel.lock () and after = ref ignore in
  let shared (d : Memory.device) =
    if not par then d
    else
      let one f = Parallel.take lock; match f () with v -> !after (); Parallel.give lock; v | exception e -> Parallel.give lock; raise e in
      { Memory.read = (fun off n -> one (fun () -> d.read off n)); write = (fun off n v -> one (fun () -> d.write off n v)) } in
  let mem = Memory.create () in
  (* (the memory as the devices reach it, a controller that copies to
   * and from another device's register (Dma) or a mailbox that fills a
   * buffer: the same RAM and the same devices, these not behind the
   * lock, which who is in a device already holds) *)
  let inner = if par then Memory.create () else mem in
  let map ~base ~size name d =
    Memory.map_device mem ~base ~size name (shared d);
    if par then Memory.map_device inner ~base ~size name d in
  let st = Arm32.create mem in
  let mmu = Mmu32.create mem in
  let fb = Framebuffer.create inner in
  let intc = Intc.create () in
  let timer = Systimer.create ~line:(fun n on -> Intc.set intc n on) in
  let uart = Pl011.create ~output:cfg.serial0 ~line:(fun on -> Intc.set intc 57 on) in
  let mini = Miniuart.create ~output:cfg.serial1 ~line:(fun on -> Intc.set intc 29 on) in
  (* (the Pi 2's GB less what the I/O space hides) *)
  let ram = Bytes.make (min cfg.ram_size io) '\000' in
  Memory.map_bytes mem ~base:0 "ram" ram;
  if par then Memory.map_bytes inner ~base:0 "ram" ram;
  (* the I/O space, where no device answers: zero, and a note *)
  let unassigned = Devices.unassigned ~log:(fun what off -> cfg.log (Printf.sprintf "unassigned %s at 0x%x" what (io + off))) in
  map ~base:io ~size:0x1000000 "io" unassigned;
  map ~base:0x40000000 ~size:0x40000000 "gpu" unassigned;
  let local = ref unassigned in
  if cfg.pi2 then map ~base:0x40000000 ~size:0x100 "local" { Memory.read = (fun off n -> !local.read off n); write = (fun off n v -> !local.write off n v) };
  let dev base size name d = map ~base:(io + base) ~size name d in
  dev 0x3000 0x1c "systimer" (Systimer.device timer);
  dev 0xb200 0x28 "intc" (Intc.device intc);
  dev 0xb880 0x40 "mailbox" (Devices.mailbox ~mem:inner ~ram_size:cfg.ram_size ~vc_base:(cfg.ram_size - vc_size) ~board_rev:(if cfg.pi2 then 0xa21041 else 0x900021) ~on_framebuffer:(Framebuffer.configure fb));
  dev 0x104000 0x10 "rng" (Devices.rng ~pi4:false);
  dev 0x200000 0xb4 "gpio" (Devices.regs ~fixed:[] ());
  dev 0x201000 0x1000 "uart0" (Pl011.device uart);
  dev 0x215000 0x100 "aux" (Miniuart.device mini);
  dev 0x300000 0x100 "emmc" (Sdhost.device (Sdhost.create ~card:cfg.sd ~line:(fun on -> Intc.set intc 62 on)));
  let dma = Dma.create ~mem:inner ~io ~line:(fun n on -> Intc.set intc n on) in
  dev 0x7000 0x1000 "dma" (Dma.device dma);
  (* the sound: the PWM, its clock in the clock manager, its words from
   * the DMA controller on request line 5, at the samples' pace *)
  let yield = ref ignore in
  let pwm = Pwm.create ~pi4:false ~dma ~yield:(fun () -> !yield ()) in
  Dma.pace dma ~permap:5;
  dev 0x20c000 0x28 "pwm" (Pwm.device pwm);
  dev 0x1010a0 0x8 "pwm clock" (Pwm.clock pwm);
  (* the USB devices: behind the hub QEMU adds on the controller's one
   * port, on its ports in their order (1.1, 1.2, ...) *)
  let devices = List.mapi (fun i name ->
    let path = Printf.sprintf "1.%d" (i + 1) in
    name, (if name = "usb-mouse" then Usb.mouse ~path () else if name = "usb-net" then Usernet.usb ~path else Usb.keyboard ~path ())) cfg.usb_devices in
  let keyboard = List.assoc_opt "usb-kbd" devices and mouse = List.assoc_opt "usb-mouse" devices in
  let root = if devices = [] then None else Some (Usb.hub ~path:"1" (List.map snd devices)) in
  dev 0x980000 0x10000 "usb" (Dwc2.device (Dwc2.create ~mem:inner ~root ~line:(fun on -> Intc.set intc 9 on) ~now:(fun () -> Systimer.now timer)));
  let new_cp () = { actlr = 0; cpacr = 0; dfsr = 0; ifsr = 0; dfar = 0; ifar = 0; fcse = 0; contextid = 0; tpid = Array.make 3 0; csselr = 0 } in
  let new_core id st mmu started =
    { id; cst = st; cmmu = mmu; ccp = new_cp (); ctags = Array.make (1 lsl cache_bits) (-1); ccode = Array.make (1 lsl cache_bits) (Arm32_isa.Undefined 0);
      cused = Array.make used_max 0; cused_n = 0;
      kept_words = Array.make (1 lsl kept_bits) (-1); kept_code = Array.make (1 lsl kept_bits) (Arm32_isa.Undefined 0);
      local_irq = false; wfi = false; yielded = false; forget_asked = Atomic.make false; flush_asked = Atomic.make false; started; asleep = false; cntv_ctl = 0; cntv_cval = 0; mail = Array.make 4 0;
      timer_ctl = 0; mail_ctl = 0; cran = 0 } in
  let first = new_core 0 st mmu true in
  let t = { mem; cores = [| first |]; cur = 0; par; lock; wake = Parallel.cond (); tick = Parallel.cond (); ticked = false; spawned = false; failed = None; intc; timer; pwm; uart; mini; ran = 0; waited = 0; cfg;
            instructions = 0; time_left = 0; undefined = []; inq = Queue.create (); fb; keyboard; mouse; key_events = [] } in
  (* (the core that wrote to the device: the one whose turn it is. With
   * a core a domain, nothing: the time passes while it looks again) *)
  yield := (fun () -> if not par then begin let c = t.cores.(t.cur) in c.wfi <- true; c.yielded <- true end);
  after := (fun () -> wake t);
  (* (strex with the cores at the same time: the test and the store as
   * one step, and the word still what ldrex read) *)
  if par then begin
    let excl = Parallel.lock () in
    Arm32.strex := (fun (st : Arm32_isa.state) p v ->
      st.exclusive = p && begin
        Parallel.take excl;
        match Memory.load32 st.mem p = st.exclusive_value && (Memory.store32 st.mem p v; true) with
        | ok -> Parallel.give excl; ok
        | exception e -> Parallel.give excl; raise e
      end)
  end;
  st.coproc <- coproc t first;
  st.translate <- (fun va access -> Mmu32.translate mmu ~user:(st.mode = 0x10) va access);
  set_sctlr first 0x00050078;
  (* The Pi 2's three other cores, not started (start_core), and the
   * cores' controller: for core n, which timers interrupt it (0x40 +
   * 4n: bit 3 the virtual one), which mailboxes (0x50 + 4n), what is
   * pending (0x60 + 4n: bit 3, bits 4 to 7 the mailboxes, bit 8 the
   * other devices', the first core's), and its four mailboxes: bits
   * set at 0x80 + 16n + 4m, read and cleared at 0xC0 + 16n + 4m.
   * (QEMU's bcm2836_control.) *)
  if cfg.pi2 then begin
    let others = Array.init 3 (fun k ->
      let st = Arm32.create mem and mmu = Mmu32.create mem in
      let c = new_core (k + 1) st mmu false in
      st.coproc <- coproc t c;
      st.translate <- (fun va access -> Mmu32.translate mmu ~user:(st.mode = 0x10) va access);
      set_sctlr c 0x00050078;
      c) in
    t.cores <- Array.append [| first |] others;
    (* (each core's, and not the writer's alone: a mailbox written is
     * another core's interrupt. In turns it changes nothing, a turn
     * begins by asking this.
     * old: t.local_irq <- core_irq t t.cores.(t.cur)) *)
    let again () = Array.iter (fun (c : core) -> c.local_irq <- core_irq t c) t.cores in
    local := { Memory.read = (fun off _ ->
                 let n = (off lsr 2) land 3 in
                 let c = t.cores.(n) in
                 if off >= 0x40 && off < 0x50 then c.timer_ctl
                 else if off >= 0x50 && off < 0x60 then c.mail_ctl
                 else if off >= 0x60 && off < 0x70 then
                   (if c.cntv_ctl land 3 = 1 && Systimer.now t.timer >= c.cntv_cval then 8 else 0)
                   lor (if c.mail.(0) <> 0 then 0x10 else 0) lor (if c.mail.(1) <> 0 then 0x20 else 0)
                   lor (if c.mail.(2) <> 0 then 0x40 else 0) lor (if c.mail.(3) <> 0 then 0x80 else 0)
                   lor (if n = 0 && Intc.irq t.intc then 0x100 else 0)
                 else if off >= 0xc0 && off < 0x100 then t.cores.((off - 0xc0) lsr 4).mail.(n)
                 else 0);
               write = (fun off _ v ->
                 let n = (off lsr 2) land 3 in
                 if off >= 0x40 && off < 0x50 then t.cores.(n).timer_ctl <- v
                 else if off >= 0x50 && off < 0x60 then t.cores.(n).mail_ctl <- v
                 else if off >= 0x80 && off < 0xc0 then begin let c = t.cores.((off - 0x80) lsr 4) in c.mail.(n) <- c.mail.(n) lor v end
                 else if off >= 0xc0 && off < 0x100 then begin let c = t.cores.((off - 0xc0) lsr 4) in c.mail.(n) <- c.mail.(n) land lnot v end;
                 again ()) }
  end;
  t

(* another core of the Pi 2 started at [addr], in its reset state (QEMU's
 * -device loader,addr=,cpu-num=n) *)
let start_core t n ~addr =
  if n > 0 && n < Array.length t.cores then begin
    let c = t.cores.(n) in
    c.started <- true;
    Arm32.set_mode c.cst 0x13;
    c.cst.a_off <- true; c.cst.i_off <- true; c.cst.f_off <- true;
    c.cst.next <- addr
  end

(* a word put in memory (QEMU's -device loader,addr=,data=,data-len=4) *)
let poke t ~addr v = Memory.store32 t.mem addr v

(* as QEMU's arm boot loads a raw kernel: at 0x10000, with ATAGs at
 * 0x100 (the core, the memory), and the CPU in SVC with A, I and F
 * masked, r1 the machine (0xc42, BCM2708), r2 the ATAGs *)
let load_kernel t image =
  Memory.write_string t.mem 0x10000 image;
  let words = [ 5; 0x54410001; 1; 4096; 0;  4; 0x54410002; t.cfg.ram_size; 0;  0; 0 ] in
  List.iteri (fun i w -> Memory.store32 t.mem (0x100 + (4 * i)) w) words;
  let st = t.cores.(0).cst in
  Arm32.set_mode st 0x13;
  st.a_off <- true; st.i_off <- true; st.f_off <- true;
  st.r.(0) <- 0; st.r.(1) <- 0xc42; st.r.(2) <- 0x100;
  st.next <- 0x10000

(* a character from the host, when the UART can take it (one at a time:
 * the kernels run it with its FIFO off) *)
let input t c = Queue.add c t.inq

(* the console's UART takes the host's characters as it has room *)
let feed t =
  if t.cfg.console = 1 then (while Miniuart.room t.mini && not (Queue.is_empty t.inq) do Miniuart.input t.mini (Queue.pop t.inq) done)
  else if Pl011.empty t.uart && not (Queue.is_empty t.inq) then Pl011.input t.uart (Queue.pop t.inq)

(* a raw image at an address, the CPU there in its reset state (QEMU's
 * -device loader with cpu-num, -bios) *)
let load_raw t ~addr image =
  Memory.write_string t.mem addr image;
  let st = t.cores.(0).cst in
  Arm32.set_mode st 0x13;
  st.a_off <- true; st.i_off <- true; st.f_off <- true;
  st.next <- addr

let screen t = Framebuffer.rgb t.fb
let frame t = Framebuffer.raw t.fb
let frame_direct t = Framebuffer.direct t.fb

let now t = Systimer.now t.timer
(* the ears: on the A+ (and every later board) the left one is GPIO 45,
 * the PWM's second channel, the right one GPIO 40, its first; the first
 * Model B had them the other way *)
let set_audio t (output : rate:int -> int -> int -> unit) = Pwm.set_output t.pwm (fun ~rate first second -> output ~rate second first)

(* (each started core: the first with the board's counts, another with
 * what it ran itself) *)
let where t =
  let one k (c : core) =
    let st = c.cst in
    let mode = match st.Arm32_isa.mode with
      | 0x10 -> "usr" | 0x11 -> "fiq" | 0x12 -> "irq" | 0x13 -> "svc" | 0x17 -> "abt" | 0x1b -> "und" | _ -> "sys" in
    let cpu = { Status.pc = Int64.of_int st.next; user = st.mode = 0x10; label = mode; ran = (if k = 0 then t.ran + c.cran else c.cran); waited = (if k = 0 then t.waited else 0) } in
    c.cran <- 0; cpu in
  let cpus = List.filteri (fun k _ -> t.cores.(k).started) (Array.to_list (Array.mapi one t.cores)) in
  t.ran <- 0; t.waited <- 0;
  cpus

(* a key now (the window's) *)
let key t usage down = Option.iter (fun k -> Usb.key k usage down) t.keyboard

(* the mouse's input now (QMP's input-send-event) *)
let pointer t inputs = Option.iter (fun m -> Usb.pointer m inputs) t.mouse

(* keys pressed now and released after [hold] microseconds of the
 * board's time, as QEMU's send-key (its hold-time: 100ms) *)
let send_keys t usages ~hold =
  List.iter (fun u -> key t u true) usages;
  t.key_events <- t.key_events @ List.map (fun u -> now t + hold, u, false) usages

let timed_keys t =
  let due, later = List.partition (fun (at, _, _) -> at <= now t) t.key_events in
  t.key_events <- later;
  List.iter (fun (_, u, down) -> key t u down) due

(* a block's instructions from [key], or 0 ([blocks]); what the loop
 * below does of an abort and of an instruction not there, for the one
 * of a block that raised *)
let block t (c : core) (st : Arm32_isa.state) key =
  match !blocks key with
  | n -> n
  | exception Arm32.Abort (va, fsr) ->
      let pc = Bits.mask32 (st.r.(15) - 8) in
      c.ccp.dfar <- va; c.ccp.dfsr <- fsr;
      Arm32.take st Arm32_isa.Data_abort ~ret:(pc + 8);
      !blocks_done ()
  | exception Arm32.Unimplemented (w, _) ->
      let pc = Bits.mask32 (st.r.(15) - 8) in
      let w = if w = 0 then Memory.load32 t.mem (if st.mmu then Mmu32.translate c.cmmu ~user:false pc 0 else pc) else w in
      if not (List.mem w t.undefined) then begin
        t.undefined <- w :: t.undefined;
        t.cfg.log (Printf.sprintf "undefined instruction %08x at 0x%x" w pc)
      end;
      Arm32.take st Arm32_isa.Undefined_instruction ~ret:(pc + 4);
      !blocks_done ()

(* the board's pace changed: so many instructions to a microsecond from
 * now (a page, as its browser gets faster or slower at them) *)
let set_ips t n = t.cfg <- { t.cfg with ips = max 1 n }

(* the state, the MMU and the memory: for who translates blocks *)
(* (the first core's: a board translated is a Pi 1) *)
let parts t = let c = t.cores.(0) in c.cst, c.cmmu, t.mem

(* the instructions of a batch, then time: the system timer advances a
 * microsecond per [ips] instructions (plan_pi.md, decision 6) *)
(* (old: run, for the one core; now a core's turn, and run below gives
 * each core its own) *)
let turn t (c : core) ~batch =
  let st = c.cst in
  let first = c.id = 0 in
  let svc st _ = Arm32.take st Arm32_isa.Supervisor_call ~ret:(st.Arm32_isa.r.(15) - 4) in
  let mask = (1 lsl cache_bits) - 1 in
  (* claude: a WFI ends the batch where it is (the core waits there):
   * the time skipped at the WFI, not later in the batch between two
   * instructions -- mini-xv6's tick read the counter, the batch went
   * on to its end, 10ms were skipped there, and the compare it then
   * wrote was already past: no tick ever again *)
  let executed = ref 0 in
  while !executed < batch && not c.wfi do
    incr executed;
    let pc = st.next in
    if !Prof.on && (first || not t.par) then Prof.tick pc;
    (* (the devices' interrupts are the first core's; a core's own:
     * local_irq) *)
    if first && (not st.f_off) && Intc.fiq t.intc then Arm32.take st Arm32_isa.Fiq ~ret:(pc + 4)
    else if (not st.i_off) && (c.local_irq || (first && Intc.irq t.intc)) then Arm32.take st Arm32_isa.Irq ~ret:(pc + 4)
    else begin
      let key = pc lor (if st.mode = 0x10 then 1 else 0) in
      (* (a block from here, when there is one: [blocks_on]) *)
      let ran = if !blocks_on && st.mmu then block t c st key else 0 in
      if ran > 0 then executed := !executed + ran - 1
      else
      let slot = (pc lsr 2) land mask in
      match
        if c.ctags.(slot) = key then c.ccode.(slot)
        else begin
          let pa = if st.mmu then Mmu32.translate c.cmmu ~user:(st.mode = 0x10) pc 0 else pc in
          (* (old: Arm32.decode, and the two stores here: [decode], [fill]) *)
          let i = decode c (Memory.load32 t.mem pa) in
          code_page pa;
          fill c slot key i; i
        end
      with
      | exception Arm32.Abort (va, fsr) ->
          c.ccp.ifar <- va; c.ccp.ifsr <- fsr land 0x40f;
          Arm32.take st Arm32_isa.Prefetch_abort ~ret:(pc + 4)
      | i ->
          (* (old: Arm32.execute st ~addr:pc ~svc i; Arm32_fast.on, a switch) *)
          (try (if !Arm32_fast.on then Arm32_fast.execute st ~addr:pc ~svc i else Arm32.execute st ~addr:pc ~svc i) with
           | Arm32.Abort (va, fsr) ->
               c.ccp.dfar <- va; c.ccp.dfsr <- fsr;
               Arm32.take st Arm32_isa.Data_abort ~ret:(pc + 8)
           | Arm32.Unimplemented (w, _) ->
               let w = if w = 0 then Memory.load32 t.mem (if st.mmu then Mmu32.translate c.cmmu ~user:false pc 0 else pc) else w in
               if not (List.mem w t.undefined) then hold t (fun () ->
                 t.undefined <- w :: t.undefined;
                 t.cfg.log (Printf.sprintf "undefined instruction %08x at 0x%x" w pc));
               Arm32.take st Arm32_isa.Undefined_instruction ~ret:(pc + 4))
    end
  done;
  !executed

(* the board's time after [batch] instructions *)
let advance t batch =
  t.instructions <- t.instructions + batch;
  let ticks = t.time_left + batch in
  Systimer.advance t.timer (ticks / t.cfg.ips);
  Pwm.advance t.pwm (ticks / t.cfg.ips);
  t.time_left <- ticks mod t.cfg.ips

(* every core waits with nothing pending: the time to the next compare
 * skipped (at most 10ms, the idle loop checking again) *)
let skip t =
  let us = ref (min 10000 (max 1 (min (Systimer.until_next t.timer) (Pwm.until_next t.pwm)))) in
  (* (and to another core's timer) *)
  Array.iter (fun (c : core) ->
    if c.started && c.cntv_ctl land 3 = 1 && c.timer_ctl land 8 <> 0 then
      us := max 1 (min !us (c.cntv_cval - Systimer.now t.timer))) t.cores;
  Systimer.advance t.timer !us;
  Pwm.advance t.pwm !us;
  t.waited <- t.waited + (!us * t.cfg.ips)

(* A core on its domain (cores_parallel): its turns, for ever. It
 * waits, a WFI with nothing pending, until who writes its mailbox or
 * advances the time says so. The lowest core that does not wait
 * counts the time, a batch of its instructions at once (a core that
 * spins on a lock has turns of an instruction). *)
let core_main t (c : core) ~batch =
  (* (no lower core is there to count) *)
  let counts () = let rec go k = k >= c.id || (let o = t.cores.(k) in ((not o.started) || o.asleep) && go (k + 1)) in go 0 in
  let owed = ref 0 in
  try
    while true do
      if c.asleep then hold t (fun () ->
        while not (pending t c) do Parallel.wait t.wake t.lock done;
        c.asleep <- false);
      c.wfi <- false;
      if Atomic.exchange c.forget_asked false then forget c;
      if Atomic.exchange c.flush_asked false then flush c;
      c.local_irq <- core_irq t c;
      let ran = turn t c ~batch in
      c.cran <- c.cran + ran;
      owed := !owed + ran;
      let sleeps = c.wfi && not c.yielded in
      c.wfi <- false; c.yielded <- false;
      if sleeps || !owed >= batch then begin
        hold t (fun () ->
          if counts () then advance t !owed;
          if sleeps && not (pending t c) then c.asleep <- true;
          t.ticked <- true; Parallel.signal t.tick;
          wake t);
        owed := 0
      end
    done
  with e -> Parallel.take t.lock; t.failed <- Some e; t.ticked <- true; Parallel.signal t.tick; Parallel.give t.lock

(* The instructions of a batch, then time: the system timer advances a
 * microsecond per [ips] instructions (plan_pi.md, decision 6). With
 * several cores, a batch each in turn, in the same time: the time
 * that passes is the longest turn's. A core that waits (WFI) skips
 * its turns until an interrupt of its own is pending; when all wait,
 * the time to the next event is skipped, as for one. A turn ends the
 * core's exclusive access (ldrex): another core may have written the
 * word since, and its strex is then refused and tried again. *)
let run_turns t ~batch =
  let n = Array.length t.cores in
  let longest = ref 0 and all_wait = ref true and yielded = ref false in
  for k = 0 to n - 1 do
    let c = t.cores.(k) in
    if c.started then begin
      let pending = core_irq t c || (k = 0 && (Intc.irq t.intc || Intc.fiq t.intc)) in
      if c.asleep && pending then c.asleep <- false;
      if not c.asleep then begin
        (* (old: select t k) *)
        t.cur <- k;
        c.local_irq <- core_irq t c;
        c.wfi <- false;
        let ran = turn t c ~batch in
        if n > 1 then c.cst.exclusive <- -1;
        c.cran <- c.cran + ran;
        if ran > !longest then longest := ran;
        if c.wfi then begin
          c.wfi <- false;
          if c.yielded then begin c.yielded <- false; yielded := true end
          else if not (core_irq t c || (k = 0 && (Intc.irq t.intc || Intc.fiq t.intc))) then c.asleep <- true
        end;
        if not c.asleep then all_wait := false
      end
    end
  done;
  t.cur <- 0;
  (* a WFI with nothing pending: the time to the next compare skipped
   * (at most 10ms, the idle loop checking again) *)
  (* (old: the time skipped and the time advanced, here: [skip], [advance]) *)
  if !all_wait && not !yielded then skip t;
  let batch = !longest in
  t.ran <- t.ran + t.cores.(0).cran;
  t.cores.(0).cran <- 0;
  advance t batch;
  if t.key_events <> [] then timed_keys t;
  feed t

(* With a core a domain (cores_parallel): the cores started at the
 * first call, on their domains; then, each call, a tick of the core
 * that counts the time waited for (a batch of its instructions), or,
 * every core waiting, the time to the next event skipped as above;
 * and the keys timed and the UART's input. *)
let run_parallel t ~batch =
  if not t.spawned then begin
    t.spawned <- true;
    Array.iter (fun (c : core) -> if c.started then Parallel.spawn (fun () -> core_main t c ~batch)) t.cores
  end;
  hold t (fun () ->
    Option.iter raise t.failed;
    if Array.for_all (fun (c : core) -> (not c.started) || (c.asleep && not (pending t c))) t.cores then skip t
    else begin
      t.ticked <- false;
      while not t.ticked do Parallel.wait t.tick t.lock done;
      Option.iter raise t.failed
    end;
    if t.key_events <> [] then timed_keys t;
    feed t;
    wake t)

let run t ~batch = if t.par then run_parallel t ~batch else run_turns t ~batch

let parallel t = t.par
