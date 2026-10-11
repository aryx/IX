(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Board.mli *)

type config = {
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
}

type t = {
  st : Arm32_isa.state;
  mem : Memory.t;
  mmu : Mmu32.t;
  cp : cp15;
  intc : Intc.t;
  timer : Systimer.t;
  uart : Pl011.t;
  mini : Miniuart.t;
  mutable wfi : bool;               (* a WFI: time may jump to the next event *)
  (* claude: since the last [where]: the instructions run, and the
   * time skipped at WFIs (in instructions) *)
  mutable ran : int;
  mutable waited : int;
  mutable cfg : config;
  (* the decode cache: by virtual address, bit 0 set when fetched in
   * user mode; emptied with the TLB and by I-cache invalidations *)
  tags : int array;
  code : Arm32_isa.t array;
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
let io = 0x20000000

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
 *   for the collector. As tiny-machine's (TinyLibCPU). *)
let forget_used = ref true
let keep_decoded = ref true

let used_max = 4096
let used = Array.make used_max 0
let used_n = ref 0          (* more than used_max: not all are in [used] *)

let kept_bits = 14
let kept_words = Array.make (1 lsl kept_bits) (-1)
let kept_code = Array.make (1 lsl kept_bits) (Arm32_isa.Undefined 0)

let decode w =
  if not !keep_decoded then Arm32.decode w
  else begin
    let k = (w lxor (w lsr 12) lxor (w lsr 22)) land ((1 lsl kept_bits) - 1) in
    if kept_words.(k) = w then kept_code.(k)
    else begin
      let i = Arm32.decode w in
      kept_words.(k) <- w; kept_code.(k) <- i; i
    end
  end

(* a slot of the cache filled *)
let fill t slot key i =
  if !forget_used && t.tags.(slot) = -1 then begin
    if !used_n < used_max then used.(!used_n) <- slot;
    incr used_n
  end;
  t.tags.(slot) <- key; t.code.(slot) <- i

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
let forget t =
  if !forget_used && !used_n <= used_max then
    for k = 0 to !used_n - 1 do t.tags.(used.(k)) <- -1 done
  else Array.fill t.tags 0 (1 lsl cache_bits) (-1);
  used_n := 0

(* (the TLB emptied. For the blocks: nothing, when the kernel says
 * which pages of instructions it writes ([code_told], the request 5: a
 * block is found through the TLB each time); else as an I-cache's
 * invalidation, a kernel that says nothing of what it writes
 * (mini-xv6, which no cache of QEMU's ever asked) being trusted no
 * further than the decode cache trusts it: emptied here too.) *)
let code_told = ref false
let flush t = Mmu32.flush t.mmu; forget t; if !blocks_on && not !code_told then !blocks_forget ()

(*****************************************************************************)
(* CP15 *)
(*****************************************************************************)

(* the ARM1176JZF-S's identification, as QEMU's arm1176 *)
let midr = 0x410fb767 and ctr = 0x1dd20d2

let set_sctlr t v =
  t.mmu.sctlr <- v;
  t.st.mmu <- v land 1 <> 0;
  t.st.vectors <- (if v land (1 lsl 13) <> 0 then Bits.mask32 (0xffff lsl 16) else 0);
  flush t

let mrc t ~crn ~crm ~opc2 =
  let c = t.cp and m = t.mmu in
  match crn, crm, opc2 with
  | 0, 0, 0 -> midr | 0, 0, 1 -> ctr
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

let mcr t ~crn ~crm ~opc2 v =
  let c = t.cp and m = t.mmu in
  match crn, crm, opc2 with
  | 1, 0, 0 -> set_sctlr t v
  | 1, 0, 1 -> c.actlr <- v
  | 1, 0, 2 ->
      (* only cp10 and cp11's access is kept, the rest reading as QEMU
       * gives it (0xC0F00000 after 9pi's 0x0FFFFFFF); VFP granted with
       * both full *)
      c.cpacr <- (v land 0x00f00000) lor 0xc0000000;
      t.st.vfp_ok <- c.cpacr land 0x00f00000 = 0x00f00000
  | 2, 0, 0 -> m.ttbr0 <- v; flush t | 2, 0, 1 -> m.ttbr1 <- v; flush t | 2, 0, 2 -> m.ttbcr <- v; flush t
  | 3, 0, 0 -> m.dacr <- v; flush t
  | 5, 0, 0 -> c.dfsr <- v | 5, 0, 1 -> c.ifsr <- v
  | 6, 0, 0 -> c.dfar <- v | 6, 0, 2 -> c.ifar <- v
  (* the caches: only an instruction cache's invalidation matters, the
   * decode cache's; the TLB's *)
  | 7, (5 | 7), 0 -> forget t; if !blocks_on then !blocks_forget ()
  | 7, 0, 4 -> t.wfi <- true                              (* wait for interrupt *)
  | 8, _, _ -> flush t
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
let one_piece t (st : Arm32_isa.state) va n access =
  let user = st.mode = 0x10 in
  let at a = if st.mmu then Mmu32.translate t.mmu ~user (Bits.mask32 a) access else Bits.mask32 a in
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
(* the physical pages an instruction was fetched from (512 MB of them) *)
let code_pages = Bytes.make (1 lsl 17) '\000'
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

let host_call t (st : Arm32_isa.state) op =
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
    if !fetched then begin forget t; if !blocks_on then !blocks_written d x end;
    1
  end
  else if op = 4 then !host_draw t.mem (fun va n write -> one_piece t st va n (if write then 1 else 0)) d
  else
  if op = 2 then begin
    match host_next () with
    | None -> 0
    | Some e ->
        let pd = one_piece t st d 8 1 in
        if pd < 0 then 0
        else begin
          let b, o = Memory.direct t.mem pd 8 in
          Bytes.blit_string e 1 b o (String.length e - 1);
          Char.code e.[0]
        end
  end
  else if op = 3 then begin
    let ps = one_piece t st d 66 0 in
    if ps < 0 || not !host_cursor then 0
    else begin
      let b, o = Memory.direct t.mem ps 66 in
      host_shape := (fst !host_shape + 1, Bytes.sub_string b o 66); 1
    end
  end
  else if n <= 0 || n > 1 lsl 26 then 0
  else
    let pd = one_piece t st d n 1 in
    if pd < 0 then 0
    else if op = 1 then begin
      let b, o = Memory.direct t.mem pd n in
      touched pd n;
      Bytes.fill b o n (Char.unsafe_chr (x land 0xff)); 1
    end
    else
      let ps = one_piece t st x n 0 in
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
let coproc t (st : Arm32_isa.state) (i : Arm32_isa.t) =
  match i with
  | Coproc { cp = 15; opc1 = 7; load = true; crn = 15; crm = 0; opc2; rd; _ } when !host_calls && opc2 <= 5 && rd <> 15 ->
      st.r.(rd) <- host_call t st opc2
  | Coproc { cp = 15; opc1 = 0; load = true; crn; crm; opc2; rd; _ } ->
      let v = mrc t ~crn ~crm ~opc2 in
      if rd = 15 then Arm32.write_cpsr st v 8 else st.r.(rd) <- v
  | Coproc { cp = 15; opc1 = 0; load = false; crn; crm; opc2; rd; _ } -> mcr t ~crn ~crm ~opc2 st.r.(rd)
  | Coproc2 { cp = 15; load = false; _ } -> ()            (* the ARM1176's cache range operations *)
  | Hint { hint = 3; _ } -> t.wfi <- true
  | Hint _ -> ()
  | _ -> raise (Arm32.Unimplemented (0, st.r.(15) - 8))

(*****************************************************************************)
(* The board *)
(*****************************************************************************)

(* the VideoCore's share, at the top of RAM: QEMU's raspi1ap gives it
 * 64MB of 512 *)
let vc_size = 64 * 1024 * 1024

let create cfg =
  let mem = Memory.create () in
  let st = Arm32.create mem in
  let mmu = Mmu32.create mem in
  let fb = Framebuffer.create mem in
  let intc = Intc.create () in
  let timer = Systimer.create ~line:(fun n on -> Intc.set intc n on) in
  let uart = Pl011.create ~output:cfg.serial0 ~line:(fun on -> Intc.set intc 57 on) in
  let mini = Miniuart.create ~output:cfg.serial1 ~line:(fun on -> Intc.set intc 29 on) in
  Memory.map_bytes mem ~base:0 "ram" (Bytes.make cfg.ram_size '\000');
  (* the I/O space, where no device answers: zero, and a note *)
  let unassigned = Devices.unassigned ~log:(fun what off -> cfg.log (Printf.sprintf "unassigned %s at 0x%x" what (io + off))) in
  Memory.map_device mem ~base:io ~size:0x1000000 "io" unassigned;
  Memory.map_device mem ~base:0x40000000 ~size:0x40000000 "gpu" unassigned;
  let dev base size name d = Memory.map_device mem ~base:(io + base) ~size name d in
  dev 0x3000 0x1c "systimer" (Systimer.device timer);
  dev 0xb200 0x28 "intc" (Intc.device intc);
  dev 0xb880 0x40 "mailbox" (Devices.mailbox ~mem ~ram_size:cfg.ram_size ~vc_base:(cfg.ram_size - vc_size) ~board_rev:0x900021 ~on_framebuffer:(Framebuffer.configure fb));
  dev 0x200000 0xb4 "gpio" (Devices.regs ~fixed:[] ());
  dev 0x201000 0x1000 "uart0" (Pl011.device uart);
  dev 0x215000 0x100 "aux" (Miniuart.device mini);
  dev 0x300000 0x100 "emmc" (Sdhost.device (Sdhost.create ~card:cfg.sd ~line:(fun on -> Intc.set intc 62 on)));
  dev 0x7000 0x1000 "dma" (Dma.device (Dma.create ~mem ~line:(fun n on -> Intc.set intc n on)));
  (* the USB devices: behind the hub QEMU adds on the controller's one
   * port, on its ports in their order (1.1, 1.2, ...) *)
  let devices = List.mapi (fun i name ->
    let path = Printf.sprintf "1.%d" (i + 1) in
    name, (if name = "usb-mouse" then Usb.mouse ~path () else if name = "usb-net" then Usernet.usb ~path else Usb.keyboard ~path ())) cfg.usb_devices in
  let keyboard = List.assoc_opt "usb-kbd" devices and mouse = List.assoc_opt "usb-mouse" devices in
  let root = if devices = [] then None else Some (Usb.hub ~path:"1" (List.map snd devices)) in
  dev 0x980000 0x10000 "usb" (Dwc2.device (Dwc2.create ~mem ~root ~line:(fun on -> Intc.set intc 9 on) ~now:(fun () -> Systimer.now timer)));
  let cp = { actlr = 0; cpacr = 0; dfsr = 0; ifsr = 0; dfar = 0; ifar = 0; fcse = 0; contextid = 0; tpid = Array.make 3 0 } in
  let t = { st; mem; mmu; cp; intc; timer; uart; mini; wfi = false; ran = 0; waited = 0; cfg;
            tags = Array.make (1 lsl cache_bits) (-1); code = Array.make (1 lsl cache_bits) (Arm32_isa.Undefined 0);
            instructions = 0; time_left = 0; undefined = []; inq = Queue.create (); fb; keyboard; mouse; key_events = [] } in
  st.coproc <- coproc t;
  st.translate <- (fun va access -> Mmu32.translate mmu ~user:(st.mode = 0x10) va access);
  set_sctlr t 0x00050078;
  t

(* as QEMU's arm boot loads a raw kernel: at 0x10000, with ATAGs at
 * 0x100 (the core, the memory), and the CPU in SVC with A, I and F
 * masked, r1 the machine (0xc42, BCM2708), r2 the ATAGs *)
let load_kernel t image =
  Memory.write_string t.mem 0x10000 image;
  let words = [ 5; 0x54410001; 1; 4096; 0;  4; 0x54410002; t.cfg.ram_size; 0;  0; 0 ] in
  List.iteri (fun i w -> Memory.store32 t.mem (0x100 + (4 * i)) w) words;
  let st = t.st in
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
  let st = t.st in
  Arm32.set_mode st 0x13;
  st.a_off <- true; st.i_off <- true; st.f_off <- true;
  st.next <- addr

let screen t = Framebuffer.rgb t.fb
let frame t = Framebuffer.raw t.fb
let frame_direct t = Framebuffer.direct t.fb

let now t = Systimer.now t.timer

let where t =
  let st = t.st in
  let mode = match st.Arm32_isa.mode with
    | 0x10 -> "usr" | 0x11 -> "fiq" | 0x12 -> "irq" | 0x13 -> "svc" | 0x17 -> "abt" | 0x1b -> "und" | _ -> "sys" in
  let cpu = { Status.pc = Int64.of_int st.next; user = st.mode = 0x10; label = mode; ran = t.ran; waited = t.waited } in
  t.ran <- 0; t.waited <- 0;
  [ cpu ]

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
let block t (st : Arm32_isa.state) key =
  match !blocks key with
  | n -> n
  | exception Arm32.Abort (va, fsr) ->
      let pc = Bits.mask32 (st.r.(15) - 8) in
      t.cp.dfar <- va; t.cp.dfsr <- fsr;
      Arm32.take st Arm32_isa.Data_abort ~ret:(pc + 8);
      !blocks_done ()
  | exception Arm32.Unimplemented (w, _) ->
      let pc = Bits.mask32 (st.r.(15) - 8) in
      let w = if w = 0 then Memory.load32 t.mem (if st.mmu then Mmu32.translate t.mmu ~user:false pc 0 else pc) else w in
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
let parts t = t.st, t.mmu, t.mem

(* the instructions of a batch, then time: the system timer advances a
 * microsecond per [ips] instructions (plan_pi.md, decision 6) *)
let run t ~batch =
  let st = t.st in
  let svc st _ = Arm32.take st Arm32_isa.Supervisor_call ~ret:(st.Arm32_isa.r.(15) - 4) in
  let mask = (1 lsl cache_bits) - 1 in
  (* claude: a WFI ends the batch where it is (the core waits there):
   * the time skipped at the WFI, not later in the batch between two
   * instructions -- mini-xv6's tick read the counter, the batch went
   * on to its end, 10ms were skipped there, and the compare it then
   * wrote was already past: no tick ever again *)
  let executed = ref 0 in
  while !executed < batch && not t.wfi do
    incr executed;
    let pc = st.next in
    if !Prof.on then Prof.tick pc;
    if (not st.f_off) && Intc.fiq t.intc then Arm32.take st Arm32_isa.Fiq ~ret:(pc + 4)
    else if (not st.i_off) && Intc.irq t.intc then Arm32.take st Arm32_isa.Irq ~ret:(pc + 4)
    else begin
      let key = pc lor (if st.mode = 0x10 then 1 else 0) in
      (* (a block from here, when there is one: [blocks_on]) *)
      let ran = if !blocks_on && st.mmu then block t st key else 0 in
      if ran > 0 then executed := !executed + ran - 1
      else
      let slot = (pc lsr 2) land mask in
      match
        if t.tags.(slot) = key then t.code.(slot)
        else begin
          let pa = if st.mmu then Mmu32.translate t.mmu ~user:(st.mode = 0x10) pc 0 else pc in
          (* (old: Arm32.decode, and the two stores here: [decode], [fill]) *)
          let i = decode (Memory.load32 t.mem pa) in
          code_page pa;
          fill t slot key i; i
        end
      with
      | exception Arm32.Abort (va, fsr) ->
          t.cp.ifar <- va; t.cp.ifsr <- fsr land 0x40f;
          Arm32.take st Arm32_isa.Prefetch_abort ~ret:(pc + 4)
      | i ->
          (* (old: Arm32.execute st ~addr:pc ~svc i; Arm32_fast.on, a switch) *)
          (try (if !Arm32_fast.on then Arm32_fast.execute st ~addr:pc ~svc i else Arm32.execute st ~addr:pc ~svc i) with
           | Arm32.Abort (va, fsr) ->
               t.cp.dfar <- va; t.cp.dfsr <- fsr;
               Arm32.take st Arm32_isa.Data_abort ~ret:(pc + 8)
           | Arm32.Unimplemented (w, _) ->
               let w = if w = 0 then Memory.load32 t.mem (if st.mmu then Mmu32.translate t.mmu ~user:false pc 0 else pc) else w in
               if not (List.mem w t.undefined) then begin
                 t.undefined <- w :: t.undefined;
                 t.cfg.log (Printf.sprintf "undefined instruction %08x at 0x%x" w pc)
               end;
               Arm32.take st Arm32_isa.Undefined_instruction ~ret:(pc + 4))
    end
  done;
  (* a WFI with nothing pending: the time to the next compare skipped
   * (at most 10ms, the idle loop checking again) *)
  if t.wfi then begin
    t.wfi <- false;
    if not (Intc.irq t.intc || Intc.fiq t.intc) then begin
      let us = min 10000 (max 1 (Systimer.until_next t.timer)) in
      Systimer.advance t.timer us;
      t.waited <- t.waited + (us * t.cfg.ips)
    end
  end;
  let batch = !executed in
  t.ran <- t.ran + batch;
  t.instructions <- t.instructions + batch;
  let ticks = t.time_left + batch in
  Systimer.advance t.timer (ticks / t.cfg.ips);
  t.time_left <- ticks mod t.cfg.ips;
  if t.key_events <> [] then timed_keys t;
  feed t
