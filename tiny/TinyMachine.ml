(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* A tiny machine of our own: TinyLibCPU.ml's CPU with what a kernel
 * needs around it, designed as its instructions were. TinyCPU.ml runs
 * the CPU as a user program runs, its system calls answered by the
 * host; here nothing answers them but a program the machine runs, a
 * kernel, in the same assembly; its usage and examples: [help], what
 * tiny-machine -h prints.
 *
 * The link is TinyLibCPU's: the files one after the other, their
 * labels one namespace, so a kernel's table names its programs; the
 * kernel first, at 0. An image is the memory's first bytes, as they are
 * at the start: no header, since the machine always starts at 0 in
 * supervisor mode (the Pi's kernel.img, loaded at 0x8000 by its
 * firmware, is the same idea). Files named .tm are assembly, another
 * an image. tiny-os/ is an OS for it, by versions, each with a Makefile
 * that builds and runs it: v0/ a page of assembly and its programs, v6/
 * xv6's kind of kernel in C, its disk made by tiny-mkfs; ./tiny-machine
 * v0 or v6, at the top of ix, builds and boots one.
 *
 * The machine, what the CPU lacked to run a kernel:
 *
 * - {b Two modes}, supervisor and user, a bit of [status]. The machine
 *   starts in supervisor mode at 0.
 * - {b One way in, one way out.} A trap saves the pc in [epc], the
 *   reason in [cause] (1 sys, 2 an illegal word, 3 a fault, 4 the
 *   timer), what goes with it in [tval] (the call's number, the word,
 *   the address), the mode and the interrupts' bit in [status]; it
 *   enters supervisor mode with interrupts off and jumps to [tvec].
 *   [eret] undoes it: the mode and the interrupts' bit back, the pc at
 *   [epc]. epc is where to resume: past a sys, on a faulting
 *   instruction, on the instruction an interrupt came before.
 * - {b Registers of control}, read by [csrr d, name] and written by
 *   [csrw name, a]: status epc cause tval tvec time timecmp base
 *   bound. time counts the instructions (the time is the program's
 *   alone, so every run is the same); the timer interrupts when time
 *   reaches timecmp and interrupts are on. csrr, csrw and eret are
 *   illegal in user mode.
 * - {b Protection by a window.} In user mode an address must be in
 *   [base, bound), the fetch's too, or it is a fault. No relocation:
 *   a user program is assembled where it runs; what a window buys is
 *   that a program can harm only itself (RISC-V's PMP, the 360's
 *   storage keys, without pages).
 * - {b Two devices at the top of memory}, reached from anywhere by a
 *   negative offset from r0: a store to -16(r0) writes a byte to the
 *   console, a store to -12(r0) halts the machine, the value its exit
 *   status. They are outside any window a kernel gives, so only it
 *   reaches them.
 *
 * What tiny-os v6 (xv6's kind of kernel) adds, each kept apart so that
 * v0 runs as it did (plan_tiny_os.md, phase 2):
 *
 * - {b 16 MB}, the devices still at the top (-16(r0) the console).
 * - {b Pages}, Sv32 (RISC-V's 32-bit scheme, xv6's): satp's top bit
 *   turns them on, the window off; a fault's address in tval.
 * - {b amoswap d, a, (b)}, the atomic swap a spinlock is made of, in
 *   either mode; {b hartid}, the core's number (0: one core, for now);
 *   {b scratch} and {b csrrw}, for a trap's first register.
 * - {b Interrupts by source}: ip (pending) and ie (enabled), a bit
 *   each; the timer's is the first, enabled at the start as v0 wants;
 *   an interrupt's cause is 4, its sources in tval.
 * - {b The console's input} at -8(r0), and its interrupt; {b a disk}
 *   (-d image), 1 KB blocks moved at once, and its interrupt.
 *
 * And t6 (tiny-os's free kernel) one more: status's bit 16, the window
 * relocating (a user address plus base, below bound).
 *
 * And for a window system (plan_tiny_windows.md), each an option, so
 * that a kernel without one runs as it did:
 *
 * - {b A screen}: 640 by 480 pixels, a byte each, at 0xf00000, memory
 *   like any other (a kernel stores a pixel by stb); a byte is a
 *   colour in Plan 9's table of 256. -window shows it in a window of
 *   the host's, -screen f writes it at the halt, a PPM.
 * - {b A mouse}: the word at -4(r0), its x in the low 12 bits, its y
 *   in the next 12, its buttons above (1 left, 2 middle, 4 right, as
 *   Plan 9's); its interrupt, the fourth source, from a change until
 *   the word is read.
 * - {b The keys} are the console's input, the window's with -window
 *   (the arrows the bytes 128 to 131: up, down, left, right).
 * - {b A session replayed} (-events f): the mouse and the keys from a
 *   file, each at its time; the time being the instructions counted,
 *   the screen at the halt is the same on every run.
 *
 * The CPU's hooks carry all of it (TinyLibCPU's [env]): the fetch, the
 * load and the store go through the pages or the window and find the
 * devices; sys raises a trap; a word the CPU does not know is csrr,
 * csrw or eret, in supervisor mode, or amoswap, or a trap. The loop
 * around [step] adds the rest: the time, the interrupts.
 *
 * The tests: TinyMachine_test.sh runs tiny-os/v0/kernel.tm, a page of
 * kernel, with its four user programs (two printing, one executing
 * csrw, one storing into the kernel), on a long and a short timer
 * period: every letter printed, the two faults caught, the printing
 * interleaved by the short period and not by the long one; and the
 * programs of TinyMachine_tests/ (amoswap and csrrw, the pages, the
 * console's input, the disk, the relocating window) against their
 * .expected. tiny-os's v6 and t6 run on it too (their make check).
 *
 * Exercises, each cheap because the time is the instructions counted
 * and everything else is a hook of the CPU:
 * - several cores (plan_tiny_os.md, phase 5): N CPUs sharing the
 *   memory, stepped in an order a seed draws; a race then comes back
 *   from its seed, which real hardware never gives;
 * - wfi: a core waiting for an interrupt, the time jumping to timecmp,
 *   so an idle kernel costs nothing;
 * - a slow disk: the transfer done N instructions after the command,
 *   so a kernel must sleep for it (v6's diskrw becomes xv6's);
 * - a TLB: the last translations kept, flushed by a write of satp; a
 *   kernel that forgets a flush then shows its bug, as on real machines;
 * - pages' A and D bits, set by the load and the store, for a clock
 *   page replacement in a kernel.
 *
 * References: the RISC-V privileged specification (from memory): the
 * trap registers, their names, mret; Wirth and Gutknecht, Project
 * Oberon (from memory): a machine and its system designed together;
 * Nisan and Schocken, The Elements of Computing Systems (Hack):
 * devices as memory. *)

let usage = "usage: tiny-machine [-l | -o image | -d disk | -window | -screen ppm | -events file] kernel.tm [program.tm...] | image"

(* -h: how, by examples, each one as it runs *)
let help = usage ^ {|
TinyCPU's CPU with a kernel's machine: two modes, traps, a timer, pages, a
console and a disk. ./tiny-machine v0, v6, t6 or tiny-kernel builds a kernel
and runs it; the same by hand, in tiny/tiny-os/v0/, for example:
  tiny-machine kernel.tm a.tm b.tm c.tm d.tm     assembled, linked (the kernel
                                                 first, at 0), run: aabbc<illegal>...
  tiny-machine -o kernel.img kernel.tm a.tm ...  the same, to an image
  tiny-machine kernel.img                        the image run
  tiny-machine -l kernel.img                     the listing: 0:  20100000  lui r1, 0x0
  tiny-machine -d fs.img kernel.img              v6 (in tiny-os/v6/), fs.img its disk,
                                                 written back at the halt
  tiny-machine -window kernel.img                its screen (640 by 480, at 0xf00000) in
                                                 a window, whose keys and mouse are its
  tiny-machine -events f -screen s.ppm kernel.img
                                                 the keys and the mouse from f, a line
                                                 each (1000 m 320 240 1: at time 1000 the
                                                 mouse there, its left button down;
                                                 2000 k ls\n: these keys), the input's
                                                 end after the last; the screen at the
                                                 halt in s.ppm
The console is this terminal; ^D ends v6's shell, and the machine; ^C
is the kernel's (tiny-kernel: the program running killed); ^\ quits.
|}

(*****************************************************************************)
(* The registers of control, and the traps *)
(*****************************************************************************)

let status = 0 and epc = 1 and cause = 2 and tval = 3 and tvec = 4 and time = 5 and timecmp = 6 and base = 7 and bound = 8
(* v6's (plan_tiny_os.md): the core's number, the interrupts pending
 * and enabled (a bit per source), the pages' root, and a word for the
 * kernel (the trap frame's address while in user mode, 0 in the
 * kernel: RISC-V's sscratch) *)
and hartid = 9 and ip = 10 and ie_csr = 11 and satp = 12   (* scratch, 13, only read and written *)
let csr_names = [| "status"; "epc"; "cause"; "tval"; "tvec"; "time"; "timecmp"; "base"; "bound"; "hartid"; "ip"; "ie"; "satp"; "scratch" |]
let read_only k = k = time || k = hartid || k = ip

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
let i_timer = 1 and i_console = 2 and i_disk = 4 and i_mouse = 8

(* the devices, at the top of memory, reached from anywhere by a
 * negative offset from r0: the console's output -16(r0), the halt
 * -12(r0); v6's in the 32 bytes below the top *)
let memsize = 1 lsl 24
let console = memsize - 16 and halt = memsize - 12 and devices = memsize - 32
let console_in = memsize - 8
let disk_block = memsize - 32 and disk_addr = memsize - 28 and disk_cmd = memsize - 24 and disk_status = memsize - 20
let mouse_dev = memsize - 4
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

let tty = Unix.isatty Unix.stdin

(* bytes typed: after those not yet read *)
let console_type k s = k.queue <- String.sub k.queue k.next (String.length k.queue - k.next) ^ s; k.next <- 0

let console_open (caps : < Cap.stdin; .. >) k =
  if not k.opened then begin
    k.opened <- true;
    if not (tty) then (let (_ : < Cap.stdin; .. >) = caps in k.queue <- In_channel.input_all stdin; k.eof <- true)
    else Sys.set_signal Sys.sigint (Sys.Signal_handle (fun _ -> console_type k "\003"))
  end

(* a terminal's bytes, when some are there *)
let console_poll k =
  if k.opened && not k.eof && k.next >= String.length k.queue && tty then
    match Unix.select [ Unix.stdin ] [] [] 0.0 with
    | [], _, _ -> ()
    | _ ->
        let b = Bytes.create 256 in
        let n = Unix.read Unix.stdin b 0 256 in
        if n = 0 then k.eof <- true else (k.queue <- Bytes.sub_string b 0 n; k.next <- 0)
    | exception Unix.Unix_error (Unix.EINTR, _, _) -> ()   (* a ^C meanwhile *)

let console_read k =
  if k.next < String.length k.queue then (k.next <- k.next + 1; Char.code k.queue.[k.next - 1])
  else if k.eof then (k.eof_read <- true; 0xfffffffe) else 0xffffffff

let console_waiting k = k.next < String.length k.queue || (k.eof && not k.eof_read)

(* The disk: an image file (-d), in blocks of 1 KB. The kernel writes a
 * block's number at -32(r0), a physical address at -28(r0), then the
 * command at -24(r0), 1 to read the block into memory, 2 to write it
 * from memory; the transfer is done at once, and the disk's interrupt
 * waits until the kernel writes -20(r0) (which reads 1 while it does).
 * The image is written back when the machine halts. *)
let bsize = 1024

type disk = { image : Bytes.t; mutable block : int; mutable addr : int; mutable done_ : bool; mutable dirty : bool }

let disk_command d (m : TinyLibCPU.machine) cmd =
  let off = d.block * bsize in
  if off + bsize > Bytes.length d.image || d.addr + bsize > memsize then TinyLibCPU.error "disk: block %d, address 0x%x: out of the image or the memory" d.block d.addr;
  (match cmd with
   | 1 -> Bytes.blit d.image off m.mem d.addr bsize
   | 2 -> Bytes.blit m.mem d.addr d.image off bsize; d.dirty <- true
   | _ -> TinyLibCPU.error "disk: command %d" cmd);
  d.done_ <- true

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

(* the screen as a PPM: a header, then red, green and blue bytes, row
 * after row *)
let ppm (m : TinyLibCPU.machine) =
  let header = Printf.sprintf "P6\n%d %d\n255\n" width height in
  let h = String.length header in
  let out = Bytes.create (h + (3 * width * height)) in
  Bytes.blit_string header 0 out 0 h;
  for i = 0 to (width * height) - 1 do
    Bytes.blit_string colours (3 * Char.code (Bytes.get m.mem (screen + i))) out (h + (3 * i)) 3
  done;
  Bytes.to_string out

(* the mouse: its word, and whether it changed since it was read *)
type mouse = { mutable at : int; mutable moved : bool }

(* An event of a session, a line: "m x y buttons" the mouse, "k text"
 * keys typed (in the text \n is a new line, \ and three digits a
 * byte: \003). In a file (-events) a time comes first, the events in
 * the order of their times; a window's program (-window) writes them
 * without one, as they happen. *)
let event (ms : mouse) k line =
  let bad () = TinyLibCPU.error "not an event: %s" line in
  let number w = match int_of_string_opt w with Some n -> n | None -> bad () in
  match String.split_on_char ' ' line with
  | [ "m"; x; y; buttons ] ->
      let at = max 0 (min (width - 1) (number x)) lor (max 0 (min (height - 1) (number y)) lsl 12) lor (number buttons lsl 24) in
      if at <> ms.at then (ms.at <- at; ms.moved <- true)
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
    | Some i -> (match int_of_string_opt (String.sub l 0 i) with Some t -> Some (t, String.sub l (i + 1) (String.length l - i - 1)) | None -> TinyLibCPU.error "not an event: %s" l)
    | None -> TinyLibCPU.error "not an event: %s" l)
    (String.split_on_char '\n' text)

(* The host's window (-window) is another program's, tiny-machine-window
 * (TinyMachineWindow.ml), so that this one links no library of C's and
 * is built by ix's tools as by OCaml's: a child, given the screen on
 * its standard input, a PPM each time it changed, and writing the
 * events on its standard output; its end (the window closed) is the
 * machine's. Thirty times a second, by the host's clock: what it shows
 * is not the machine's time's, only what it types and points is. *)
type window = { to_w : Unix.file_descr; from_w : Unix.file_descr; mutable shown : string; mutable frame : float; mutable partial : string }

let window_open (caps : < Cap.fork; Cap.exec; .. >) =
  let screen_r, to_w = Unix.pipe ~cloexec:true () and from_w, events_w = Unix.pipe ~cloexec:true () in
  (* beside this program, by its installed name or by dune's *)
  let name = if Filename.check_suffix Sys.executable_name ".exe" then "TinyMachineWindow.exe" else "tiny-machine-window" in
  ignore (Procs.spawn caps (Filename.concat (Filename.dirname Sys.executable_name) name) [] ~stdin:screen_r ~stdout:events_w);
  Unix.close screen_r; Unix.close events_w;
  Sys.set_signal Sys.sigpipe Sys.Signal_ignore;   (* the window closed while a screen is written: its end is read next *)
  { to_w; from_w; shown = ""; frame = 0.; partial = "" }

let window_poll w (m : TinyLibCPU.machine) ms k =
  let now = Unix.gettimeofday () in
  if now -. w.frame > 1. /. 30. then begin
    w.frame <- now;
    let pixels = Bytes.sub_string m.mem screen (width * height) in
    if pixels <> w.shown then (w.shown <- pixels; Procs.write_all w.to_w (ppm m));
    match Unix.select [ w.from_w ] [] [] 0.0 with
    | [], _, _ -> ()
    | _ ->
        let b = Bytes.create 4096 in
        let n = Unix.read w.from_w b 0 4096 in
        if n = 0 then raise (Halt 0);
        (match String.split_on_char '\n' (w.partial ^ Bytes.sub_string b 0 n) with
         | [] -> ()
         | lines ->
             let rec go = function [ last ] -> w.partial <- last | l :: rest -> event ms k l; go rest | [] -> () in
             go lines)
    | exception Unix.Unix_error (Unix.EINTR, _, _) -> ()
  end

type machine = { cpu : TinyLibCPU.machine; csr : int array; cons : console; disk : disk; mouse : mouse; mutable events : (int * string) list }

(* the sources wanting an interrupt *)
let pending mc =
  (if mc.csr.(time) >= mc.csr.(timecmp) then i_timer else 0)
  lor (if console_waiting mc.cons then i_console else 0)
  lor (if mc.disk.done_ then i_disk else 0)
  lor (if mc.mouse.moved then i_mouse else 0)

let supervisor mc = mc.csr.(status) land supervisor_bit <> 0

let trap mc cause_v tval_v epc_v =
  let c = mc.csr and st = mc.csr.(status) in
  c.(epc) <- epc_v; c.(cause) <- cause_v; c.(tval) <- tval_v;
  c.(status) <- supervisor_bit lor (if st land supervisor_bit <> 0 then ps else 0) lor (if st land ie <> 0 then pie else 0) lor (st land relocate);
  mc.cpu.pc <- TinyLibCPU.addr c.(tvec)

(*****************************************************************************)
(* The CPU's hooks: the window, the devices, the new instructions *)
(*****************************************************************************)

let check mc a =
  let a = TinyLibCPU.addr a in
  if supervisor mc then a
  else if mc.csr.(status) land relocate <> 0 then (if a >= mc.csr.(bound) then raise (Trap (c_fault, a)); TinyLibCPU.addr (mc.csr.(base) + a))
  else if a < mc.csr.(base) || a >= mc.csr.(bound) then raise (Trap (c_fault, a))
  else a

(* Pages (v6's): Sv32, RISC-V's 32-bit scheme, xv6's vm.c's. With satp's
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

let translate mc (m : TinyLibCPU.machine) access va =
  let sat = mc.csr.(satp) in
  if sat land 0x80000000 = 0 then check mc va
  else begin
    let va = TinyLibCPU.m32 va in
    let fault () = raise (Trap (c_fault, va)) in
    let entry at = if at >= memsize then fault (); TinyLibCPU.load m TinyLibCPU.W at in
    let e1 = entry (((sat land 0x3fffff) lsl 12) + (4 * (va lsr 22))) in
    if e1 land 1 = 0 || e1 land 14 <> 0 then fault ();
    let e0 = entry (((e1 lsr 10) lsl 12) + (4 * ((va lsr 12) land 0x3ff))) in
    let needed = match access with Read -> 2 | Write -> 4 | Exec -> 8 in
    if e0 land 1 = 0 || e0 land needed = 0 || (not (supervisor mc) && e0 land 16 = 0) then fault ();
    let pa = ((e0 lsr 10) lsl 12) lor (va land 0xfff) in
    if pa >= memsize then fault ();
    pa
  end

(* a load and a store: the pages or the window, then memory or a device *)
let load caps mc m s a =
  let a = translate mc m Read a in
  match TinyLibCPU.word a with
  | w when w = console_in -> console_open caps mc.cons; console_read mc.cons
  | w when w = disk_status -> if mc.disk.done_ then 1 else 0
  | w when w = mouse_dev -> mc.mouse.moved <- false; mc.mouse.at
  | w when w >= devices -> 0
  | _ -> TinyLibCPU.load m s a

let store caps mc m s a v =
  let a = translate mc m Write a in
  match TinyLibCPU.word a with
  | w when w = console -> Console.print caps (String.make 1 (Char.chr (v land 0xff))); flush stdout
  | w when w = halt -> raise (Halt (v land 0xff))
  | w when w = disk_block -> mc.disk.block <- v
  | w when w = disk_addr -> mc.disk.addr <- v
  | w when w = disk_cmd -> disk_command mc.disk m v
  | w when w = disk_status -> mc.disk.done_ <- false
  | w when w >= devices -> ()
  | _ -> TinyLibCPU.store m s a v

(* the words the CPU does not know: 0x3a-0x3c, csrr, csrw and eret,
 * the supervisor's, and 0x3e, csrrw d, csr, a (both at once: d the
 * register's old value, the register a's: at a trap, r1 swapped with
 * scratch frees a register); 0x3d, amoswap d, a, (b), anyone's: d the word at
 * the address in b, which becomes a, in one instruction (the atomic
 * swap a spinlock is made of, RISC-V's amoswap.w, ARM's swp) *)
let extra caps mc (m : TinyLibCPU.machine) w =
  let op = (w lsr 24) land 0xff and d = (w lsr 20) land 15 and a = (w lsr 16) land 15 and k = w land 0xffff in
  let c = mc.csr and next () = m.pc <- TinyLibCPU.addr (m.pc + 4) in
  if op = 0x3d then begin
    let at = m.r.(k land 15) in
    let old = load caps mc m TinyLibCPU.W at in
    store caps mc m TinyLibCPU.W at m.r.(a);
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
        if k = ie_csr && c.(k) land i_console <> 0 then console_open caps mc.cons;
        next ()
    | _ ->
        let st = c.(status) in
        c.(status) <- (if st land ps <> 0 then supervisor_bit else 0) lor (if st land pie <> 0 then ie else 0) lor (st land relocate);
        m.pc <- TinyLibCPU.addr c.(epc)
  end

let env (caps : < Cap.stdin; Cap.stdout; .. >) mc : TinyLibCPU.env = {
  fetch = (fun m pc -> TinyLibCPU.load m TinyLibCPU.W (translate mc m Exec pc));
  load = load caps mc;
  store = store caps mc;
  sys = (fun _ n -> raise (Trap (c_sys, n)));
  illegal = extra caps mc;
}

(* the assembler's and the listing's new instructions *)
let ext : TinyLibCPU.extension =
  let csr s =
    match List.assoc_opt (String.trim s) (List.mapi (fun k n -> n, k) (Array.to_list csr_names)) with
    | Some k -> k | None -> TinyLibCPU.error "not a register of control: %s" s in
  let w op d a k = TinyLibCPU.Words (4, fun _ _ -> [ (op lsl 24) lor (d lsl 20) lor (a lsl 16) lor k ]) in
  {
    parse = (fun name args ->
      match name, args with
      | "csrr", [ d; c ] -> Some (w 0x3a (TinyLibCPU.reg d) 0 (csr c))
      | "csrw", [ c; a ] -> Some (w 0x3b 0 (TinyLibCPU.reg a) (csr c))
      | "eret", [] -> Some (w 0x3c 0 0 0)
      | "csrrw", [ d; c; a ] -> Some (w 0x3e (TinyLibCPU.reg d) (TinyLibCPU.reg a) (csr c))
      | "amoswap", [ d; a; b ] ->
          let b = String.trim b in
          if String.length b < 2 || b.[0] <> '(' || b.[String.length b - 1] <> ')' then TinyLibCPU.error "amoswap's address: (rN)";
          Some (w 0x3d (TinyLibCPU.reg d) (TinyLibCPU.reg a) (TinyLibCPU.reg (String.sub b 1 (String.length b - 2))))
      | _ -> None);
    show = (fun w ->
      let op = (w lsr 24) land 0xff and d = (w lsr 20) land 15 and a = (w lsr 16) land 15 and k = w land 0xffff in
      match op with
      | 0x3a when k < Array.length csr_names -> Some (Printf.sprintf "csrr\tr%d, %s" d csr_names.(k))
      | 0x3b when k < Array.length csr_names -> Some (Printf.sprintf "csrw\t%s, r%d" csr_names.(k) a)
      | 0x3c -> Some "eret"
      | 0x3e when k < Array.length csr_names -> Some (Printf.sprintf "csrrw\tr%d, %s, r%d" d csr_names.(k) a)
      | 0x3d -> Some (Printf.sprintf "amoswap\tr%d, r%d, (r%d)" d a (k land 15))
      | _ -> None);
  }

(*****************************************************************************)
(* The loop: the time, the interrupt, a step *)
(*****************************************************************************)

type options = { disk_file : string option; screen_file : string option; events_file : string option; window : bool }

let run caps o image =
  let disk_file = o.disk_file in
  let m : TinyLibCPU.machine = TinyLibCPU.boot image in
  m.r.(TinyLibCPU.sp) <- devices;
  let c = Array.make (Array.length csr_names) 0 in
  c.(status) <- supervisor_bit;
  c.(timecmp) <- 0xffffffff;
  c.(ie_csr) <- i_timer;
  let disk_image = match disk_file with Some f -> Bytes.of_string (FS.read caps (Fpath.v f)) | None -> Bytes.empty in
  (* a session's keys, or a window's, are the console's input: the
   * host's is then not read, and a session's last event is its end *)
  let events = Option.map (fun f -> timed_events (FS.read caps (Fpath.v f))) o.events_file in
  let stdin_keys = events = None && not o.window in
  let mc = { cpu = m; csr = c; cons = { queue = ""; next = 0; eof = events = Some []; opened = not stdin_keys; eof_read = false };
             disk = { image = disk_image; block = 0; addr = 0; done_ = false; dirty = false };
             mouse = { at = 0; moved = false }; events = (match events with Some l -> l | None -> []) } in
  let window = if o.window then Some (window_open caps) else None in
  let env = env caps mc in
  let halted n =
    (match disk_file with Some f when mc.disk.dirty -> FS.write caps (Fpath.v f) (Bytes.to_string mc.disk.image) | _ -> ());
    Option.iter (fun f -> FS.write caps (Fpath.v f) (ppm m)) o.screen_file;
    n in
  try
    while true do
      let pc = m.pc in
      c.(time) <- TinyLibCPU.m32 (c.(time) + 1);
      if stdin_keys && c.(time) land 1023 = 0 then console_poll mc.cons;
      (match mc.events with
       | (t, e) :: rest when t <= c.(time) -> event mc.mouse mc.cons e; mc.events <- rest; if rest = [] then mc.cons.eof <- true
       | _ -> ());
      if c.(time) land 0xffff = 0 then Option.iter (fun w -> window_poll w m mc.mouse mc.cons) window;
      try
        let wanted = pending mc land c.(ie_csr) in
        if c.(status) land ie <> 0 && wanted <> 0 then trap mc c_intr wanted pc
        else TinyLibCPU.step env m
      with Trap (cause_v, tval_v) -> trap mc cause_v tval_v (if cause_v = c_sys then TinyLibCPU.addr (pc + 4) else pc)
    done;
    0
  with Halt n -> halted n

let main (caps : < Cap.stdin; Cap.stdout; Cap.stderr; Cap.argv; Cap.open_in; Cap.open_out; Cap.fork; Cap.exec; .. >) =
  let args = List.tl (Array.to_list (CapSys.argv caps)) in
  TinyLibCPU.memsize := memsize;
  let image files =
    if files = [] || (List.hd files).[0] = '-' then raise Exit;
    TinyLibCPU.image ~ext ~origin:0 (List.map (fun f -> f, FS.read caps (Fpath.v f)) files) in
  try
    match args with
    | ("-h" | "--help") :: _ -> Console.print caps help; 0
    | "-l" :: files -> Console.print caps (TinyLibCPU.listing ~ext ~origin:0 (image files)); 0
    | "-o" :: out :: files -> FS.write caps (Fpath.v out) (image files); 0
    | args ->
        let rec options o = function
          | "-d" :: f :: rest -> options { o with disk_file = Some f } rest
          | "-screen" :: f :: rest -> options { o with screen_file = Some f } rest
          | "-events" :: f :: rest -> options { o with events_file = Some f } rest
          | "-window" :: rest -> options { o with window = true } rest
          | files -> run caps o (image files) in
        options { disk_file = None; screen_file = None; events_file = None; window = false } args
  with
  | Exit -> Console.eprint caps (usage ^ "   (-h: how)\n"); 2
  | TinyLibCPU.Error e | Sys_error e -> Console.eprint caps ("tiny-machine: " ^ e ^ "\n"); 1

let () = Cap.main (fun caps -> CapStdlib.exit caps (main caps))
