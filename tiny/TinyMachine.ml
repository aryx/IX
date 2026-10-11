(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMachine.mli *)

let usage = "usage: tiny-machine [-l | -o image | -d disk | -window | -screen ppm | -events file | -net dir | -net-trace | -net-loop n] kernel.tm [program.tm...] | image"

(* -h: how, by examples, each one as it runs *)
let help = usage ^ {|
TinyCPU's CPU with a kernel's machine: two modes, traps, a timer, pages, a
console and a disk. ./tiny-machine tiny-kernel, v6, t6 or v0 builds a kernel
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
  tiny-machine -net dir -net-trace kernel.img    a network: the wire's other end is this
                                                 program, at 10.0.0.1 (the machine is
                                                 10.0.0.2), answering a ping (tiny-kernel:
                                                 ping) 5 ms of the machine's time after;
                                                 dir is for the files it will serve;
                                                 -net-trace: each packet said on the
                                                 standard error, with its time
  tiny-machine -net-loop 100 kernel.img          a network whose wire comes back: each
                                                 packet sent is received 100 instructions
                                                 after (a test's; -36(r0) then reads 1)
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

(* the instructions a packet of the peer's takes to arrive: 5 ms of the
 * machine's time, two of tiny-kernel's ticks, so that a ping measures
 * something *)
let latency = 40000

type options = { disk_file : string option; screen_file : string option; events_file : string option; window : bool; net_loop : int option; net : string option; net_trace : bool }

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
  (* the wire's other end: with -net-loop, the wire itself, coming back.
   * [send] is called by the machine it gives packets to: by a reference *)
  let machine = ref None in
  let give after packet = Option.iter (fun mc -> TinyLibMachine.net_give mc ~after packet) !machine in
  (* -net-trace: a packet's line, with the machine's time in its ms *)
  let said dir packet =
    if o.net_trace then
      Option.iter (fun (mc : TinyLibMachine.machine) ->
        Console.eprint caps (Printf.sprintf "%9.1f ms  %s %s\n" (float_of_int mc.csr.(TinyLibMachine.time) *. 1000. /. TinyLibMachine.rate) dir (TinyNetwork.net_describe packet))) !machine in
  (* -net: the peer, TinyNetwork.ml as the kernel has it, at the other
   * address: what it says to send back arrives [latency] later *)
  let peer packet =
    said ">" packet;
    List.iter (fun back -> said "<" back; give latency back) (fst (TinyNetwork.net_input TinyNetwork.net_peer packet)) in
  let send = match o.net_loop, o.net with
    | Some after, _ -> Some (give after)
    | None, Some _ -> Some peer
    | None, None -> None in
  let mc : TinyLibMachine.machine = TinyLibMachine.create ~put ~on_open:(console_open caps) ?send ~disk ~events image in
  machine := Some mc;
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
      (* old: TinyLibMachine.tick mc env, an instruction a turn of this
       * loop; now the instructions to the next turn that does something *)
      TinyLibMachine.ticks mc env (1024 - (t land 1023))
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
          | "-net" :: dir :: rest -> options { o with net = Some dir } rest
          | "-net-trace" :: rest -> options { o with net_trace = true } rest
          | "-net-loop" :: n :: rest when int_of_string_opt n <> None -> options { o with net_loop = int_of_string_opt n } rest
          | files -> run caps o (image files) in
        options { disk_file = None; screen_file = None; events_file = None; window = false; net_loop = None; net = None; net_trace = false } args
  with
  | Exit -> Console.eprint caps (usage ^ "   (-h: how)\n"); 2
  | TinyLibCPU.Error e | Sys_error e -> Console.eprint caps ("tiny-machine: " ^ e ^ "\n"); 1

let () = Cap.main (fun caps -> Logging.setup caps ~name:"tiny-machine"; CapStdlib.exit caps (main caps))
