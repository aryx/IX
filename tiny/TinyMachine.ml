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
 * - {b The keys} are the console's input, the window's too with
 *   -window (the arrows the bytes 128 to 131: up, down, left, right;
 *   a key held is typed again and again).
 * - {b A speed}, with -window: 8 million instructions a second, so
 *   that a program's time, which is the machine's instructions, is the
 *   same on every host.
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
 * The machine itself is TinyLibMachine.ml (the registers of control,
 * the traps, the pages, the devices' state, one instruction of its
 * time); here its terminal: the console, the files, the window, the
 * loop. TinyMachineWeb.ml is the same for a web page.
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
(* The console, a terminal *)
(*****************************************************************************)

let tty = Unix.isatty Unix.stdin

let console_open (caps : < Cap.stdin; .. >) (k : TinyLibMachine.console) =
  if not k.opened then begin
    k.opened <- true;
    if not (tty) then (k.queue <- Procs.read_all (Console.stdin_fd caps); k.eof <- true)
    else Sys.set_signal Sys.sigint (Sys.Signal_handle (fun _ -> TinyLibMachine.console_type k "\003"))
  end

(* a terminal's bytes, when some are there *)
let console_poll (k : TinyLibMachine.console) =
  if k.opened && not k.eof && k.next >= String.length k.queue && tty then
    match Unix.select [ Unix.stdin ] [] [] 0.0 with
    | [], _, _ -> ()
    | _ ->
        let b = Bytes.create 256 in
        let n = Unix.read Unix.stdin b 0 256 in
        if n = 0 then k.eof <- true else (k.queue <- Bytes.sub_string b 0 n; k.next <- 0)
    | exception Unix.Unix_error (Unix.EINTR, _, _) -> ()   (* a ^C meanwhile *)

(*****************************************************************************)
(* The screen as a file, and in a window *)
(*****************************************************************************)

(* the screen as a PPM: a header, then red, green and blue bytes, row
 * after row *)
let ppm (m : TinyLibCPU.machine) =
  let width = TinyLibMachine.width and height = TinyLibMachine.height in
  let header = Printf.sprintf "P6\n%d %d\n255\n" width height in
  let h = String.length header in
  let out = Bytes.create (h + (3 * width * height)) in
  Bytes.blit_string header 0 out 0 h;
  for i = 0 to (width * height) - 1 do
    Bytes.blit_string TinyLibMachine.colours (3 * Char.code (Bytes.get m.mem (TinyLibMachine.screen + i))) out (h + (3 * i)) 3
  done;
  Bytes.to_string out

(* The host's window (-window) is another program's, tiny-machine-window
 * (TinyMachineWindow.ml), so that this one links no library of C's and
 * is built by ix's tools as by OCaml's: a child, given the screen on
 * its standard input, a PPM each time it changed, and writing the
 * events on its standard output; its end (the window closed) is the
 * machine's. Thirty times a second, by the host's clock: what it shows
 * is not the machine's time's, only what it types and points is.
 *
 * And with a window the machine has a speed, [rate] instructions a
 * second, below what a host gives (some 10 million of a kernel's and
 * its programs', 50 of a loop that waits): its time is its
 * instructions, so without one a game's pieces would fall by how fast
 * the host is, and faster when nothing else runs. It sleeps when it is
 * ahead ([due], the host's time the instructions so far should take),
 * and does not run to catch up. A recorded session has no window and
 * does not wait. *)
type window = {
  to_w : Unix.file_descr; from_w : Unix.file_descr; mutable shown : string; mutable frame : float; mutable partial : string;
  mutable due : float;
}

let window_open (caps : < Cap.fork; Cap.exec; .. >) =
  let screen_r, to_w = Unix.pipe ~cloexec:true () and from_w, events_w = Unix.pipe ~cloexec:true () in
  (* beside this program, by its installed name or by dune's *)
  let name = if Filename.check_suffix Sys.executable_name ".exe" then "TinyMachineWindow.exe" else "tiny-machine-window" in
  ignore (Procs.spawn caps (Filename.concat (Filename.dirname Sys.executable_name) name) [] ~stdin:screen_r ~stdout:events_w);
  Unix.close screen_r; Unix.close events_w;
  Sys.set_signal Sys.sigpipe Sys.Signal_ignore;   (* the window closed while a screen is written: its end is read next *)
  { to_w; from_w; shown = ""; frame = 0.; partial = ""; due = Unix.gettimeofday () }

(* every [polled] instructions *)
let polled = 0x10000
let window_poll w (m : TinyLibCPU.machine) ms k =
  let now = Unix.gettimeofday () in
  w.due <- w.due +. (float_of_int polled /. TinyLibMachine.rate);
  if w.due > now then Unix.sleepf (w.due -. now) else if now -. w.due > 0.1 then w.due <- now;
  let now = Unix.gettimeofday () in
  if now -. w.frame > 1. /. 30. then begin
    w.frame <- now;
    let pixels = Bytes.sub_string m.mem TinyLibMachine.screen (TinyLibMachine.width * TinyLibMachine.height) in
    if pixels <> w.shown then (w.shown <- pixels; Procs.write_all w.to_w (ppm m));
    match Unix.select [ w.from_w ] [] [] 0.0 with
    | [], _, _ -> ()
    | _ ->
        let b = Bytes.create 4096 in
        let n = Unix.read w.from_w b 0 4096 in
        if n = 0 then raise (TinyLibMachine.Halt 0);
        (match String.split_on_char '\n' (w.partial ^ Bytes.sub_string b 0 n) with
         | [] -> ()
         | lines ->
             let rec go = function [ last ] -> w.partial <- last | l :: rest -> TinyLibMachine.event ms k l; go rest | [] -> () in
             go lines)
    | exception Unix.Unix_error (Unix.EINTR, _, _) -> ()
  end

(*****************************************************************************)
(* The loop: the hosts' turns, then the machine's instruction *)
(*****************************************************************************)

type options = { disk_file : string option; screen_file : string option; events_file : string option; window : bool }

let run caps o image =
  let disk_file = o.disk_file in
  let disk = match disk_file with Some f -> Bytes.of_string (FS.read caps (Fpath.v f)) | None -> Bytes.empty in
  (* a session's keys are the console's input: the host's is then not
   * read, and a session's last event is its end. A window's keys are
   * the console's too, with the host's: a kernel that writes on the
   * console and not yet on the screen is typed at where it answers *)
  let events = Option.map (fun f -> TinyLibMachine.timed_events (FS.read caps (Fpath.v f))) o.events_file in
  let stdin_keys = events = None in
  let put ch = Console.print caps (String.make 1 ch); flush (Console.stdout caps) in
  let mc : TinyLibMachine.machine = TinyLibMachine.create ~put ~on_open:(console_open caps) ~disk ~events image in
  let m = mc.cpu and c = mc.csr in
  let window = if o.window then Some (window_open caps) else None in
  let env = TinyLibMachine.env mc in
  let halted n =
    (match disk_file with Some f when mc.disk.dirty -> FS.write caps (Fpath.v f) (Bytes.to_string mc.disk.image) | _ -> ());
    Option.iter (fun f -> FS.write caps (Fpath.v f) (ppm m)) o.screen_file;
    n in
  try
    while true do
      (* the hosts' turns, by the time this instruction will be *)
      let t = c.(TinyLibMachine.time) + 1 in
      if stdin_keys && t land 1023 = 0 then console_poll mc.cons;
      if t land (polled - 1) = 0 then Option.iter (fun w -> window_poll w m mc.mouse mc.cons) window;
      TinyLibMachine.tick mc env
    done;
    0
  with TinyLibMachine.Halt n -> halted n

let main (caps : < Cap.stdin; Cap.stdout; Cap.stderr; Cap.argv; Cap.open_in; Cap.open_out; Cap.fork; Cap.exec; .. >) =
  let args = List.tl (Array.to_list (CapSys.argv caps)) in
  TinyLibCPU.memsize := TinyLibMachine.memsize;
  let image files =
    if files = [] || (List.hd files).[0] = '-' then raise Exit;
    TinyLibCPU.image ~ext:TinyLibMachine.ext ~origin:0 (List.map (fun f -> f, FS.read caps (Fpath.v f)) files) in
  try
    match args with
    | ("-h" | "--help") :: _ -> Console.print caps help; 0
    | "-l" :: files -> Console.print caps (TinyLibCPU.listing ~ext:TinyLibMachine.ext ~origin:0 (image files)); 0
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

let () = Cap.main (fun caps -> Logging.setup caps ~name:"tiny-machine"; CapStdlib.exit caps (main caps))
