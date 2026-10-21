(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMachineDevices.mli *)

(*****************************************************************************)
(* The registers of control, and the traps *)
(*****************************************************************************)

let status = 0 and epc = 1 and cause = 2 and tval = 3 and tvec = 4 and time = 5 and timecmp = 6 and base = 7 and bound = 8
(* v6's (plan_tiny_os.md): the core's number, the interrupts pending
 * and enabled (a bit per source), the pages' root, and a word for the
 * kernel (the trap frame's address while in user mode, 0 in the
 * kernel: RISC-V's sscratch) *)
and hartid = 9 and ip = 10 and ie_csr = 11 and satp = 12   (* scratch, 13, only read and written *)
(* The machine's speed in instructions per second, so that a kernel can
 * turn its time, which counts instructions, into seconds. *)
and rate_csr = 14
let csr_names = TinyMachineISA.csr_names
let read_only k = k = time || k = hartid || k = ip || k = rate_csr

(* status: the mode, the interrupts' bit, and the two as they were
 * before the trap *)
let supervisor_bit = 1 and ie = 2 and ps = 4 and pie = 8
(* t6's (plan_tiny_os.md): the window relocates, as the 360's and the
 * PDP-10's did: a user address a is base + a, below bound, a size.
 * Kept through traps and eret, as it is the kernel's choice *)
let relocate = 16

(* an interrupt's cause is 4, its sources in tval: the bits of ip and
 * ie, the timer's the first (v0's only one) *)
let c_sys = 1 and c_illegal = 2 and c_fault = 3 and c_intr = 4
let i_timer = 1 and i_console = 2 and i_disk = 4 and i_mouse = 8 and i_net = 16

(* the devices, at the top of memory, reached from anywhere by a
 * negative offset from r0: the console's output -16(r0), the halt
 * -12(r0); v6's in the 32 bytes below the top, the network's in the
 * 16 below those, the speaker's word below them, the date's, the
 * seed's (and one free) *)
let memsize = 1 lsl 27
(* old: devices = memsize - 32, before the network's four words *)
(* old: devices = memsize - 48, before the speaker's word *)
let console = memsize - 16 and halt = memsize - 12 and devices = memsize - 64
let console_in = memsize - 8
let disk_block = memsize - 32 and disk_addr = memsize - 28 and disk_cmd = memsize - 24 and disk_status = memsize - 20
let mouse_dev = memsize - 4
let net_addr = memsize - 48 and net_len = memsize - 44 and net_cmd = memsize - 40 and net_status = memsize - 36
let speaker_dev = memsize - 52
(* the date at the boot, read at -56(r0): seconds since 2000-01-01 UTC
 * (an ML integer of 31 bits holds them until 2034, where 1970's would
 * not fit), the host's clock or -date's, so a run is the same each time
 * when asked; the kernel counts on from it by its ticks. The web page
 * leaves it at 0. (old: none: tiny-kernel had no clock of the day) *)
let date_dev = memsize - 56
let date = ref 0
(* a seed, read at -60(r0), for the programs' first random numbers
 * (tetris's pieces): tiny-machine's -seed, so that a run is the same
 * however long the boot took; 0, the default, says none, and the
 * kernel gives its clock instead. (old: none, a game seeded by the
 * clock alone: make check's tetris another game at each change of the
 * kernel's code) *)
let seed_dev = memsize - 60
let seed = ref 0
(* the screen, below the devices: a megabyte no kernel's image reaches *)
let screen = 0xf00000 and width = 640 and height = 480

exception Trap of int * int                (* cause, tval *)

exception Halt of int

(*****************************************************************************)
(* The devices (v6's): the console's input, a disk *)
(*****************************************************************************)

(* The console's input: -8(r0) gives the next byte, 0xffffffff when none
 * has come, 0xfffffffe at the input's end; its interrupt while bytes
 * wait. Nothing is read before a kernel asks (enables the interrupt or
 * reads the register): v0 never does. The input's end interrupts
 * too, once, until it is read. Then a file or a pipe is read
 * whole, so that a run is the same every time; a terminal is polled,
 * as a person types when they type, and its ^C (SIGINT) is a byte 3
 * for the kernel, not the machine's end (^\ quits tiny-machine, as
 * Ctrl-A x mini-qemu). *)
type console = { mutable queue : string; mutable next : int; mutable eof : bool; mutable opened : bool; mutable eof_read : bool }

(* bytes typed: after those not yet read *)
let console_type k s = k.queue <- String.sub k.queue k.next (String.length k.queue - k.next) ^ s; k.next <- 0

let console_read k =
  if k.next < String.length k.queue then (k.next <- k.next + 1; Char.code k.queue.[k.next - 1])
  else if k.eof then (k.eof_read <- true; 0xfffffffe) else 0xffffffff

let console_waiting k = k.next < String.length k.queue || (k.eof && not k.eof_read)

(* The disk: an image file (-d), in blocks of 1 KB. The kernel writes a
 * block's number at -32(r0), a physical address at -28(r0), then the
 * command at -24(r0), 1 to read the block into memory, 2 to write it
 * from memory; the transfer is done at once, and the disk's interrupt
 * waits until the kernel writes -20(r0) (which reads 1 while it does).
 * -32(r0) read is the disk's size, in blocks (0: no disk). [wrote] is
 * told of each block written (tiny-machine writes it to the file then:
 * a machine that ends without its halt leaves the disk as the kernel
 * last wrote it, as a crash does). *)
let bsize = 1024

type disk = { image : Bytes.t; mutable block : int; mutable addr : int; mutable done_ : bool; mutable wrote : int -> unit }

let disk_command d (m : TinyMachineCPU.machine) cmd =
  let off = d.block * bsize in
  if d.block < 0 || d.block >= Bytes.length d.image / bsize || d.addr < 0 || d.addr > memsize - bsize then TinyMachineCPU.error "disk: block %d, address 0x%x: out of the image or the memory" d.block d.addr;
  (match cmd with
   | 1 -> Bytes.blit d.image off m.mem d.addr bsize
   | 2 -> Bytes.blit m.mem d.addr d.image off bsize; d.wrote d.block
   | _ -> TinyMachineCPU.error "disk: command %d" cmd);
  d.done_ <- true

(*****************************************************************************)
(* The network (plan_tiny_network.md) *)
(*****************************************************************************)

(* A wire with two ends, this machine at one: a packet is some bytes,
 * [packet_max] at most, sent whole and received whole. The kernel
 * writes a physical address at -48(r0) and a length at -44(r0), then
 * the command at -40(r0): 1 sends the bytes there (the host's [send]
 * has them at once), 2 takes the packet that waits to there (its
 * length, read at -44(r0) before, 0 when none waits; no more than the
 * length written is copied). The network's interrupt waits while a
 * packet does. -36(r0) reads 1 when there is a wire, 0 without one:
 * a send is then lost and nothing ever comes.
 *
 * What is at the other end is the host's. It gives a packet by
 * [net_give], to arrive so many instructions from now: [flying] has
 * those on their way, by their time, and [tick] lands them. So the
 * time of the network is the machine's too, and a run with it is the
 * same every time. No more than [queue_max] wait: the next is lost,
 * as a real card's when its kernel is slow.
 *
 * An empty packet is no packet (one sent is not, one given does not
 * reach the kernel): given, it comes back to [send] at its time. That
 * is the other end's clock, in the machine's time as the rest. *)
let packet_max = 2048 and queue_max = 64

type net = {
  wired : bool; mutable naddr : int; mutable nlen : int;
  mutable waiting : string list;                 (* landed, the first first *)
  mutable flying : (int * string) list;          (* each with its time, the nearest first *)
}

let net_command n (m : TinyMachineCPU.machine) send cmd =
  let room len = if n.naddr < 0 || len < 0 || len > packet_max || n.naddr > memsize - len then TinyMachineCPU.error "network: %d bytes at 0x%x: too long or out of the memory" len n.naddr in
  match cmd with
  | 1 -> room n.nlen; if n.wired && n.nlen > 0 then send (Bytes.sub_string m.mem n.naddr n.nlen)
  | 2 ->
      (match n.waiting with
       | p :: rest -> let len = min n.nlen (String.length p) in room len; Bytes.blit_string p 0 m.mem n.naddr len; n.waiting <- rest
       | [] -> ())
  | _ -> TinyMachineCPU.error "network: command %d" cmd

(*****************************************************************************)
(* The screen, the mouse, a session's events (plan_tiny_windows.md) *)
(*****************************************************************************)

(* A pixel's byte is a colour of Plan 9's table (its m8 pixels, rgbv:
 * libmemdraw's cmap.c, whose 256 entries this gives): two bits of red,
 * two of how bright, four of green and blue, turned by the first two
 * so that a row of 16 is a ramp; 0 is black, 255 white. *)
let colour i =
  let r = i lsr 6 and v = (i lsr 4) land 3 in
  let j = (i - v + r) land 15 in
  let g = j lsr 2 and b = j land 3 in
  let den = max r (max g b) in
  if den = 0 then (17 * v, 17 * v, 17 * v)
  else let num = 17 * ((4 * den) + v) in (r * num / den, g * num / den, b * num / den)

let colours = String.init 768 (fun k -> let r, g, b = colour (k / 3) in Char.chr (match k mod 3 with 0 -> r | 1 -> g | _ -> b))

(* The colour nearest to (r, g, b), by the squares of their differences,
 * for the colour of 15 bits it falls in (5 of red, of green, of blue),
 * found once each: a picture's pixels, by tiny-machine-fetch and the
 * page (old: each its own, the page's by the first pixel that fell in
 * the 15 bits) *)
let nearest =
  let known = Array.make 32768 (-1) in
  fun r g b ->
    let key = ((r lsr 3) lsl 10) lor ((g lsr 3) lsl 5) lor (b lsr 3) in
    if known.(key) < 0 then begin
      let v shift = ((key lsr shift) land 31) * 255 / 31 in
      let d k = let c i = Char.code colours.[(3 * k) + i] - v (10 - (5 * i)) in (c 0 * c 0) + (c 1 * c 1) + (c 2 * c 2) in
      let rec go k bk bd = if k = 256 then bk else let dk = d k in if dk < bd then go (k + 1) k dk else go (k + 1) bk bd in
      known.(key) <- go 1 0 (d 0)
    end;
    known.(key)

(* the mouse: its word, and whether it changed since it was read *)
type mouse = { mutable at : int; mutable moved : bool; mutable cursor : int }

(* The machine's speed, in instructions per second. A host sets it before
 * [create]; the machine gives it to the kernel in its rate register.
 * When a person watches (a window, the web page), the host holds the
 * machine to this speed (TinyMachine.ml's window says why). Without a
 * window nothing waits, and the rate only says how long a second is in
 * instructions. The default, 8 million, is the speed the web page can
 * keep up with, and the one the recorded sessions were made at. *)
let default_rate = 8_000_000
let rate = ref default_rate

let mouse_set ms x y buttons =
  let at = max 0 (min (width - 1) x) lor (max 0 (min (height - 1) y) lsl 12) lor (buttons lsl 24) in
  if at <> ms.at then (ms.at <- at; ms.moved <- true)

(* An event of a session, a line: "m x y buttons" the mouse, "k text"
 * keys typed (in the text \n is a new line, \ and three digits a
 * byte: \003). In a file (-events) a time comes first, the events in
 * the order of their times; a window's program (-window) writes them
 * without one, as they happen. *)
let event (ms : mouse) k line =
  let bad () = TinyMachineCPU.error "not an event: %s" line in
  let number w = match int_of_string_opt w with Some n -> n | None -> bad () in
  match String.split_on_char ' ' line with
  | [ "m"; x; y; buttons ] -> mouse_set ms (number x) (number y) (number buttons)
  | "k" :: _ ->
      let b = Buffer.create 16 and n = String.length line in
      let rec go i =
        if i < n then
          if line.[i] <> '\\' || i + 1 >= n then (Buffer.add_char b line.[i]; go (i + 1))
          else if line.[i + 1] = 'n' then (Buffer.add_char b '\n'; go (i + 2))
          else if i + 3 < n then (Buffer.add_char b (Char.chr (number (String.sub line (i + 1) 3) land 255)); go (i + 4))
          else bad () in
      go 2;
      console_type k (Buffer.contents b)
  | _ -> bad ()

(* a file's: each event's time, and the event *)
let timed_events text =
  List.filter_map (fun l ->
    match String.index_opt l ' ' with
    | _ when l = "" -> None
    | Some i -> (match int_of_string_opt (String.sub l 0 i) with Some t -> Some (t, String.sub l (i + 1) (String.length l - i - 1)) | None -> TinyMachineCPU.error "not an event: %s" l)
    | None -> TinyMachineCPU.error "not an event: %s" l)
    (String.split_on_char '\n' text)

(*****************************************************************************)
(* The speaker (plan_tiny_audio.md) *)
(*****************************************************************************)

(* The speaker is memory, as the screen is: a ring of [ring] bytes, a
 * sample each (signed, 0 silence), that it plays at [hz] samples a
 * second of the machine's time, one every rate / hz instructions. The
 * kernel says where the ring is by writing its address at -52(r0) (0:
 * off, the start), and reads there the samples played since, modulo
 * 2^30: where the speaker is in the ring, which the kernel writes ahead
 * of. A sample played is made 0 again, so a ring nobody writes is
 * silence and not the last second again and again (notes_audio.md's D:
 * the kernel needs no clock to clean behind the speaker).
 *
 * Nothing happens at each sample: the samples due are played when
 * somebody looks, the kernel by reading the word, the host by [hear]
 * (its window, a WAV), so the speaker costs no instruction of its own and
 * a run is the same every time. *)
let ring = 8192 and hz = 8000

type speaker = { mutable ring_at : int; mutable played : int; mutable since : int }

(* the samples due since the last look, given to [hear] and made 0 *)
let speaker_play (sp : speaker) (m : TinyMachineCPU.machine) time hear =
  if sp.ring_at <> 0 then begin
    let period = max 1 (!rate / hz) in
    let d = TinyMachineCPU.m32 (time - sp.since) in
    let n = if d > 0x40000000 then 0 else d / period in
    if n > 0 then begin
      let b = Bytes.make n '\000' in
      for i = 0 to min n ring - 1 do
        let a = sp.ring_at + ((sp.played + i) land (ring - 1)) in
        Bytes.set b i (Bytes.get m.mem a);
        Bytes.set m.mem a '\000'
      done;
      hear (Bytes.unsafe_to_string b);
      sp.played <- (sp.played + n) land 0x3fffffff;
      sp.since <- TinyMachineCPU.m32 (sp.since + (n * period))
    end
  end

type machine = {
  cpu : TinyMachineCPU.machine; csr : int array; cons : console; disk : disk; mouse : mouse; net : net; speaker : speaker; mutable events : (int * string) list;
  put : char -> unit; on_open : console -> unit; send : string -> unit; hear : string -> unit;   (* the host's *)
  (* a device or a register of control was touched: see [ticks] *)
  mutable touched : bool;
}

(* the sources wanting an interrupt *)
let pending mc =
  (if not (TinyMachineCPU.ult mc.csr.(time) mc.csr.(timecmp)) then i_timer else 0)
  lor (if console_waiting mc.cons then i_console else 0)
  lor (if mc.disk.done_ then i_disk else 0)
  lor (if mc.mouse.moved then i_mouse else 0)
  lor (if mc.net.waiting <> [] then i_net else 0)

let supervisor mc = mc.csr.(status) land supervisor_bit <> 0
let window_base mc = mc.csr.(base)

let trap mc cause_v tval_v epc_v =
  let c = mc.csr and st = mc.csr.(status) in
  c.(epc) <- epc_v; c.(cause) <- cause_v; c.(tval) <- tval_v;
  c.(status) <- supervisor_bit lor (if st land supervisor_bit <> 0 then ps else 0) lor (if st land ie <> 0 then pie else 0) lor (st land relocate);
  mc.cpu.pc <- TinyMachineCPU.addr c.(tvec)

(*****************************************************************************)
(* The CPU's hooks: the window, the devices, the new instructions *)
(*****************************************************************************)

let check mc a =
  let a = TinyMachineCPU.addr a in
  if supervisor mc then a
  else if mc.csr.(status) land relocate <> 0 then (if not (TinyMachineCPU.ult a mc.csr.(bound)) then raise (Trap (c_fault, a)); TinyMachineCPU.addr (mc.csr.(base) + a))
  else if TinyMachineCPU.ult a mc.csr.(base) || not (TinyMachineCPU.ult a mc.csr.(bound)) then raise (Trap (c_fault, a))
  else a

(* Pages (v6's): Sv32, RISC-V's 32-bit scheme (xv6's vm.c walks Sv39,
 * the 64-bit one: three levels of 9 bits for these two). With satp's
 * top bit set, an address is 10 bits of the root table's index, 10 of
 * a table's, 12 in the page; an entry is a page's number above 10 bits
 * of flags: V R W X U. A table's entry has none of R W X (no large
 * pages); a page's needs V and the access's R, W or X, and U in user
 * mode (the supervisor reaches every page: xv6's copyin walks the
 * tables anyway). Else a fault, the address in tval. Off (satp's top
 * bit clear), the window, as v0 has it. The pc stays below the
 * memory's size (the CPU keeps it modulo), so the virtual addresses a
 * program runs at do too. *)
type access = Read | Write | Exec

let translate mc (m : TinyMachineCPU.machine) access va =
  let sat = mc.csr.(satp) in
  if sat land 0x80000000 = 0 then check mc va
  else begin
    let va = TinyMachineCPU.m32 va in
    let fault () = raise (Trap (c_fault, va)) in
    let entry at = if not (TinyMachineCPU.ult at memsize) then fault (); TinyMachineCPU.load m TinyMachineISA.W at in
    let e1 = entry (((sat land 0x3fffff) lsl 12) + (4 * (va lsr 22))) in
    if e1 land 1 = 0 || e1 land 14 <> 0 then fault ();
    let e0 = entry (((e1 lsr 10) lsl 12) + (4 * ((va lsr 12) land 0x3ff))) in
    let needed = match access with Read -> 2 | Write -> 4 | Exec -> 8 in
    if e0 land 1 = 0 || e0 land needed = 0 || (not (supervisor mc) && e0 land 16 = 0) then fault ();
    let pa = ((e0 lsr 10) lsl 12) lor (va land 0xfff) in
    if not (TinyMachineCPU.ult pa memsize) then fault ();
    pa
  end

(* a load and a store: the pages or the window, then memory or a device *)
let load mc m s a =
  let a = translate mc m Read a in
  match TinyMachineCPU.word a with
  | w when w < devices -> TinyMachineCPU.load m s a
  | w when (mc.touched <- true; w = console_in) -> mc.on_open mc.cons; console_read mc.cons
  | w when w = disk_status -> if mc.disk.done_ then 1 else 0
  | w when w = disk_block -> Bytes.length mc.disk.image / bsize
  | w when w = mouse_dev -> mc.mouse.moved <- false; mc.mouse.at
  | w when w = net_len -> (match mc.net.waiting with p :: _ -> String.length p | [] -> 0)
  | w when w = net_status -> if mc.net.wired then 1 else 0
  | w when w = speaker_dev -> speaker_play mc.speaker m mc.csr.(time) mc.hear; mc.speaker.played
  | w when w = date_dev -> !date
  | w when w = seed_dev -> !seed
  | w when w >= devices -> 0
  | _ -> TinyMachineCPU.load m s a

let store mc m s a v =
  let a = translate mc m Write a in
  match TinyMachineCPU.word a with
  | w when w < devices -> TinyMachineCPU.store m s a v
  | w when (mc.touched <- true; w = console) -> mc.put (Char.chr (v land 0xff))
  | w when w = halt -> raise (Halt (v land 0xff))
  | w when w = disk_block -> mc.disk.block <- v
  | w when w = disk_addr -> mc.disk.addr <- v
  | w when w = disk_cmd -> disk_command mc.disk m v
  | w when w = disk_status -> mc.disk.done_ <- false
  | w when w = net_addr -> mc.net.naddr <- v
  | w when w = net_len -> mc.net.nlen <- v
  | w when w = net_cmd -> net_command mc.net m mc.send v
  | w when w = speaker_dev ->
      let v = TinyMachineCPU.addr v in
      if v <> 0 && v > memsize - ring then TinyMachineCPU.error "speaker: a ring at 0x%x: out of the memory" v;
      mc.speaker.ring_at <- v; mc.speaker.played <- 0; mc.speaker.since <- mc.csr.(time)
  (* written, the mouse's word is its look: 0 the arrow, 1 a hand *)
  | w when w = mouse_dev -> mc.mouse.cursor <- v
  | w when w >= devices -> ()
  | _ -> TinyMachineCPU.store m s a v

(* the words the CPU does not know: 0x3a-0x3c, csrr, csrw and eret,
 * the supervisor's, and 0x3e, csrrw d, csr, a (both at once: d the
 * register's old value, the register a's: at a trap, r1 swapped with
 * scratch frees a register); 0x3d, amoswap d, a, (b), anyone's: d the word at
 * the address in b, which becomes a, in one instruction (the atomic
 * swap a spinlock is made of, RISC-V's amoswap.w, ARM's swp) *)
let extra mc (m : TinyMachineCPU.machine) w =
  let op = (w lsr 24) land 0xff and d = (w lsr 20) land 15 and a = (w lsr 16) land 15 and k = w land 0xffff in
  let c = mc.csr and next () = m.pc <- TinyMachineCPU.addr (m.pc + 4) in
  mc.touched <- true;
  if op = 0x3d then begin
    let at = m.r.(k land 15) in
    let old = load mc m TinyMachineISA.W at in
    store mc m TinyMachineISA.W at m.r.(a);
    if d <> 0 then m.r.(d) <- old;
    next ()
  end
  else begin
    if not (supervisor mc) || op < 0x3a || op > 0x3e || (op <> 0x3c && k >= Array.length csr_names) then raise (Trap (c_illegal, w));
    let read k = if k = ip then pending mc else c.(k) in
    match op with
    | 0x3a -> if d <> 0 then m.r.(d) <- read k; next ()
    | 0x3e -> let old = read k and v = m.r.(a) in if not (read_only k) then c.(k) <- v; if d <> 0 then m.r.(d) <- old; next ()
    | 0x3b ->
        if not (read_only k) then c.(k) <- m.r.(a);
        if k = ie_csr && c.(k) land i_console <> 0 then mc.on_open mc.cons;
        next ()
    | _ ->
        let st = c.(status) in
        c.(status) <- (if st land ps <> 0 then supervisor_bit else 0) lor (if st land pie <> 0 then ie else 0) lor (st land relocate);
        m.pc <- TinyMachineCPU.addr c.(epc)
  end

let env mc : TinyMachineCPU.env = {
  fetch = (fun m pc -> TinyMachineCPU.load m TinyMachineISA.W (translate mc m Exec pc));
  load = load mc;
  store = store mc;
  sys = (fun _ n -> raise (Trap (c_sys, n)));
  illegal = extra mc;
}

(* the listing's new instructions (tiny-assembler makes them) *)
let show w =
  let op = (w lsr 24) land 0xff and d = (w lsr 20) land 15 and a = (w lsr 16) land 15 and k = w land 0xffff in
  match op with
  | 0x3a when k < Array.length csr_names -> Some (Printf.sprintf "csrr\tr%d, %s" d csr_names.(k))
  | 0x3b when k < Array.length csr_names -> Some (Printf.sprintf "csrw\t%s, r%d" csr_names.(k) a)
  | 0x3c -> Some "eret"
  | 0x3e when k < Array.length csr_names -> Some (Printf.sprintf "csrrw\tr%d, %s, r%d" d csr_names.(k) a)
  | 0x3d -> Some (Printf.sprintf "amoswap\tr%d, r%d, (r%d)" d a (k land 15))
  | _ -> None

(*****************************************************************************)
(* The machine at its start, and one instruction of its time *)
(*****************************************************************************)

(* [put] writes a byte of the console's output, [on_open] is called
 * when a kernel first asks for the console's input; [disk] is the
 * disk's image, [events] a session's (then its keys are the console's
 * only input, and its last event the input's end); [send], when there
 * is a wire, is given each packet the machine sends; [hear] the
 * speaker's samples *)
let create ~put ~on_open ~send ~hear ~disk ~events image =
  TinyMachineCPU.memsize := memsize;
  let m : TinyMachineCPU.machine = TinyMachineCPU.boot image in
  m.r.(TinyMachineISA.sp) <- devices;
  let c = Array.make (Array.length csr_names) 0 in
  c.(status) <- supervisor_bit;
  c.(timecmp) <- 0xffffffff;
  c.(ie_csr) <- i_timer;
  c.(rate_csr) <- !rate;
  { cpu = m; csr = c; cons = { queue = ""; next = 0; eof = events = Some []; opened = events <> None; eof_read = false };
    disk = { image = disk; block = 0; addr = 0; done_ = false; wrote = ignore };
    mouse = { at = 0; moved = false; cursor = 0 }; events = (match events with Some l -> l | None -> []); put; on_open;
    net = { wired = send <> None; naddr = 0; nlen = 0; waiting = []; flying = [] };
    speaker = { ring_at = 0; played = 0; since = 0 }; hear;
    send = (match send with Some f -> f | None -> ignore); touched = false }

(* the speaker's samples due, to [hear]: the host's, between two ticks *)
let speaker_hear mc = speaker_play mc.speaker mc.cpu mc.csr.(time) mc.hear

(* a time's distance from now, in instructions: 0 when it is now or
 * passed (the differences are of 32 bits, an int's or not; more than
 * 2^30 is a time passed, the count having gone round) *)
let from_now mc t = let d = TinyMachineCPU.m32 (t - mc.csr.(time)) in if d <= 0 || d > 0x40000000 then 0 else d

(* a packet for the machine, to land [after] instructions from now
 * (at the next when 0): the host's, between two ticks or in [send] *)
let net_give mc ~after packet =
  let t = TinyMachineCPU.m32 (mc.csr.(time) + max after 1) in
  let rec place = function
    | (t', p) :: rest when from_now mc t' <= max after 1 -> (t', p) :: place rest
    | later -> (t, packet) :: later in
  mc.net.flying <- place mc.net.flying;
  mc.touched <- true

(* the packets whose time has come: waiting, or lost when too many do;
 * an empty one is the host's clock *)
let rec landed mc =
  match mc.net.flying with
  | (t, p) :: rest when from_now mc t = 0 ->
      mc.net.flying <- rest;
      if p = "" then mc.send ""
      else if List.length mc.net.waiting < queue_max then mc.net.waiting <- mc.net.waiting @ [ p ];
      landed mc
  | _ -> ()

(* the time, a session's event that is due, a packet that lands, then
 * an interrupt or a step; Halt when the kernel halts the machine *)
let tick mc (env : TinyMachineCPU.env) =
  let m = mc.cpu and c = mc.csr in
  let pc = m.pc in
  c.(time) <- TinyMachineCPU.m32 (c.(time) + 1);
  (match mc.events with
   | (t, e) :: rest when not (TinyMachineCPU.ult c.(time) t) -> event mc.mouse mc.cons e; mc.events <- rest; if rest = [] then mc.cons.eof <- true
   | _ -> ());
  if mc.net.flying <> [] then landed mc;
  try
    let wanted = pending mc land c.(ie_csr) in
    if c.(status) land ie <> 0 && wanted <> 0 then trap mc c_intr wanted pc
    else TinyMachineCPU.step env m
  with Trap (cause_v, tval_v) -> trap mc cause_v tval_v (if cause_v = c_sys then TinyMachineCPU.addr (pc + 4) else pc)

(*****************************************************************************)
(* Faster: the instructions between two looks *)
(*****************************************************************************)

(* [ticks mc env n] is n ticks. A tick looks at everything before its
 * instruction: a session's event that is due, the five sources of an
 * interrupt, the interrupts' bit; nearly always to find nothing, and
 * it is most of an instruction's time. But what it looks at changes
 * at few moments, all known:
 *
 * - the time reaches a session's next event, or timecmp: both are so
 *   many instructions away, counted;
 * - an instruction reads or writes a device or a register of control
 *   (the console, the disk, the mouse; status, ie, timecmp...), or
 *   traps: [touched], set by load, store and extra, and a trap leaves
 *   the loop by its exception;
 * - a packet lands: at its time, counted too;
 * - the host types a key or moves the mouse: between two calls only.
 *
 * So after one tick that looked and found the machine calm, the steps
 * that follow, until the nearest of those moments, are steps and the
 * time's count, nothing else; and an interrupt is taken at the very
 * instruction the simple loop takes it at (tiny-kernel's recorded
 * sessions, whose screens depend on it, have the same sums). With
 * [batched] false, ticks is tick n times. (tests/TinyMachine_bench.sh,
 * tiny-kernel's paint.events: by js_of_ocaml under node, 6.8 million
 * instructions a second without it, 8.1 with it; natively 15.2 and
 * 22.0.) *)
let batched = ref true

(* how many instructions from now need no look: 0 if an interrupt would
 * be taken at the next *)
let calm mc =
  let c = mc.csr in
  if c.(status) land ie <> 0 && pending mc land c.(ie_csr) <> 0 then 0
  else begin
    (* to a time t from now, less one: the tick at t must look; a t
     * already passed or more than 2^30 away is far (the differences
     * are of 32 bits, an int's or not) *)
    let until t = let d = TinyMachineCPU.m32 (t - c.(time)) in if d <= 0 || d > 0x40000000 then 0x40000000 else d - 1 in
    (* (an event already due is the next tick's: a tick takes one) *)
    let event = match mc.events with (t, _) :: _ -> if TinyMachineCPU.ult c.(time) t then until t else 0 | [] -> 0x40000000 in
    (* a packet lands at its tick, which must look: one less, as [until] *)
    let packet = match mc.net.flying with (t, _) :: _ -> max 0 (from_now mc t - 1) | [] -> 0x40000000 in
    min packet (min event (until c.(timecmp)))
  end

let ticks mc (env : TinyMachineCPU.env) n =
  if not !batched then for _i = 1 to n do tick mc env done
  else begin
    let m = mc.cpu and c = mc.csr in
    let left = ref n in
    while !left > 0 do
      tick mc env; decr left;
      mc.touched <- false;
      let k = ref (min !left (calm mc)) in
      left := !left - !k;
      let pc = ref m.pc in
      (try
         while !k > 0 && not mc.touched do
           pc := m.pc;
           c.(time) <- TinyMachineCPU.m32 (c.(time) + 1);
           decr k;
           TinyMachineCPU.step env m
         done
       with Trap (cause_v, tval_v) -> trap mc cause_v tval_v (if cause_v = c_sys then TinyMachineCPU.addr (!pc + 4) else !pc));
      (* the steps not run, a device touched: they are still to do *)
      left := !left + !k
    done
  end
