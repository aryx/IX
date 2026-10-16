(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMachine.mli *)

let usage = "usage: tiny-machine [-l | -o image | -d disk | -window | -rate n | -screen ppm | -events file | -net dir | -net-trace | -net-lose n | -net-out | -net-forward h:m | -net-pcap f | -net-loop n] kernel.tm [program.tm...] | image"

(* -h: how, by examples, each one as it runs *)
let help = usage ^ {|
TinyCPU's CPU with a kernel's machine: two modes, traps, a timer, pages, a
console and a disk. ./tiny-machine tiny-kernel, t6 or v0 builds a kernel
and runs it; the same by hand, in tiny/TinyKernel/steps/v0/, for example:
  tiny-machine kernel.tm a.tm b.tm c.tm d.tm     assembled, linked (the kernel
                                                 first, at 0), run: aabbc<illegal>...
  tiny-machine -o kernel.img kernel.tm a.tm ...  the same, to an image
  tiny-machine kernel.img                        the image run
  tiny-machine -l kernel.img                     the listing: 0:  20100000  lui r1, 0x0
  tiny-machine -d fs.img kernel.img              t6 (in TinyKernel/steps/t6/), fs.img its disk,
                                                 written back at the halt
  tiny-machine -window kernel.img                its screen (640 by 480, at 0xf00000) in
                                                 a window, whose keys and mouse are its
  tiny-machine -window -rate 40 kernel.img       the machine at 40 million instructions a
                                                 second (with a window, 20 by default; without
                                                 one, 8, the speed the recorded sessions and
                                                 the web page use). tiny-kernel reads the
                                                 rate, so its programs keep their pace: a
                                                 faster machine has more instructions in
                                                 each of its ticks of 2.5 ms
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
                                                 ping) 5 ms of the machine's time after,
                                                 and giving dir's files by their names
                                                 (tiny-kernel: get hello.txt);
                                                 -net-trace: each packet said on the
                                                 standard error, with its time;
                                                 -net-lose 9: its ninth packet is lost;
                                                 -net-pcap f: the packets written in f at
                                                 the halt, for tcpdump -r or Wireshark
  tiny-machine -net dir -net-out kernel.img      and it is the way to other machines: a
                                                 connection the kernel asks for to another
                                                 address is made by the host (TCP), and a
                                                 name has an address (tiny-kernel: get /
                                                 gopher.floodgap.com, web example.com);
                                                 a line "www address" asks the host for a
                                                 web page, fetched by tiny-machine-fetch
                                                 (tiny-kernel: rc, then get 'www OCaml'),
                                                 or kept in dir without -net-out
  tiny-machine -net dir -net-forward 8080:80 kernel.img
                                                 a connection to the host's port 8080 is
                                                 one to the machine's port 80 (tiny-kernel:
                                                 httpd, then http://localhost:8080/)
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

(* a ^C of the terminal's, not yet given to the machine. (old: the
 * signal's handler typed it itself; when it came while console_poll
 * was reading, the bytes read replaced the queue it had just been
 * added to, and the ^C was lost: a key typed right after it did that) *)
let interrupted = ref false

let console_open (caps : < Cap.stdin; .. >) (k : TinyMachineDevices.console) =
  if not k.opened then begin
    k.opened <- true;
    if not (tty) then (k.queue <- Procs.read_all (Console.stdin_fd caps); k.eof <- true)
    else Sys.set_signal Sys.sigint (Sys.Signal_handle (fun _ -> interrupted := true))
  end

(* a terminal's bytes, when some are there *)
let console_poll (k : TinyMachineDevices.console) =
  if !interrupted then (interrupted := false; TinyMachineDevices.console_type k "\003");
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
let ppm (m : TinyMachineCPU.machine) =
  let width = TinyMachineDevices.width and height = TinyMachineDevices.height in
  let header = Printf.sprintf "P6\n%d %d\n255\n" width height in
  let h = String.length header in
  let out = Bytes.create (h + (3 * width * height)) in
  Bytes.blit_string header 0 out 0 h;
  for i = 0 to (width * height) - 1 do
    Bytes.blit_string TinyMachineDevices.colours (3 * Char.code (Bytes.get m.mem (TinyMachineDevices.screen + i))) out (h + (3 * i)) 3
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
 * With a window, the machine also has a speed: it runs
 * TinyMachineDevices.rate instructions a second, which must be below
 * what the host can do. The machine's time is counted in instructions,
 * so without a fixed speed a game's pieces would fall as fast as the
 * host happens to be, faster when nothing else runs. The machine sleeps
 * when it is ahead ([due] is the host's time at which the instructions
 * run so far should be done), and it does not hurry to catch up when
 * it is behind. A recorded session has no window and never waits. The
 * kernel reads the rate from the machine and makes its tick 2.5 ms long
 * whatever the speed. So on a faster machine, a program paced by ticks
 * (a game) keeps its pace, and a program that computes (the browser)
 * finishes sooner. *)
type window = {
  to_w : Unix.file_descr; from_w : Unix.file_descr; mutable shown : string; mutable frame : float; mutable partial : string;
  mutable cursor : int;
  mutable due : float;
}

let window_open (caps : < Cap.fork; Cap.exec; .. >) =
  let screen_r, to_w = Unix.pipe ~cloexec:true () and from_w, events_w = Unix.pipe ~cloexec:true () in
  (* beside this program, by its installed name or by dune's *)
  let name = if Filename.check_suffix Sys.executable_name ".exe" then "TinyMachine/TinyMachineWindow.exe" else "tiny-machine-window" in
  ignore (Procs.spawn caps (Filename.concat (Filename.dirname Sys.executable_name) name) [] ~stdin:screen_r ~stdout:events_w);
  Unix.close screen_r; Unix.close events_w;
  Sys.set_signal Sys.sigpipe Sys.Signal_ignore;   (* the window closed while a screen is written: its end is read next *)
  { to_w; from_w; shown = ""; frame = 0.; partial = ""; cursor = 0; due = Unix.gettimeofday () }

(* every [polled] instructions *)
let polled = 0x10000
let window_poll w (m : TinyMachineCPU.machine) (ms : TinyMachineDevices.mouse) k =
  let now = Unix.gettimeofday () in
  w.due <- w.due +. (float_of_int polled /. float_of_int !TinyMachineDevices.rate);
  if w.due > now then Unix.sleepf (w.due -. now) else if now -. w.due > 0.1 then w.due <- now;
  let now = Unix.gettimeofday () in
  if now -. w.frame > 1. /. 30. then begin
    w.frame <- now;
    let pixels = Bytes.sub_string m.mem TinyMachineDevices.screen (TinyMachineDevices.width * TinyMachineDevices.height) in
    if pixels <> w.shown then (w.shown <- pixels; Procs.write_all w.to_w (ppm m));
    (* the mouse's look, when a program changed it *)
    if ms.cursor <> w.cursor then begin
      w.cursor <- ms.cursor;
      Procs.write_all w.to_w (Printf.sprintf "C %d\n" ms.cursor)
    end;
    match Unix.select [ w.from_w ] [] [] 0.0 with
    | [], _, _ -> ()
    | _ ->
        let b = Bytes.create 4096 in
        let n = Unix.read w.from_w b 0 4096 in
        if n = 0 then raise (TinyMachineDevices.Halt 0);
        (match String.split_on_char '\n' (w.partial ^ Bytes.sub_string b 0 n) with
         | [] -> ()
         | lines ->
             let rec go = function [ last ] -> w.partial <- last | l :: rest -> TinyMachineDevices.event ms k l; go rest | [] -> () in
             go lines)
    | exception Unix.Unix_error (Unix.EINTR, _, _) -> ()
  end

(*****************************************************************************)
(* The loop: the hosts' turns, then the machine's instruction *)
(*****************************************************************************)

type options = { disk_file : string option; screen_file : string option; events_file : string option; window : bool; rate : int option; net_loop : int option; net : string option; net_trace : bool; net_lose : int list; net_out : bool; net_forward : (int * int) list; net_pcap : string option }

(* The way out (TinyMachineSocket.mli): a connection of the host's is
 * a program run beside this one, tiny-machine-socket, its bytes on two
 * pipes: no socket here. What it says first (+ or -) is whether there
 * is a connection; a relay is then the pipes, as TinyMachinePeer wants
 * them. The ones that ended are waited for when the next one starts. *)
let helpers = ref []

let helper (caps : < Cap.fork; Cap.exec; .. >) args =
  helpers := List.filter (fun pid -> match Unix.waitpid [ Unix.WNOHANG ] pid with 0, _ -> true | _ -> false | exception Unix.Unix_error _ -> false) !helpers;
  let in_r, to_ = Unix.pipe ~cloexec:true () and from, out_w = Unix.pipe ~cloexec:true () in
  let name = if Filename.check_suffix Sys.executable_name ".exe" then "TinyMachine/TinyMachineSocket.exe" else "tiny-machine-socket" in
  helpers := Procs.spawn caps (Filename.concat (Filename.dirname Sys.executable_name) name) args ~stdin:in_r ~stdout:out_w :: !helpers;
  Unix.close in_r; Unix.close out_w;
  Sys.set_signal Sys.sigpipe Sys.Signal_ignore;
  to_, from

(* what it wrote, if it wrote: None when nothing waits, "" at its end *)
let helper_read from wait =
  match Unix.select [ from ] [] [] wait with
  | [], _, _ -> None
  | _ -> let b = Bytes.create 4096 in Some (Bytes.sub_string b 0 (Unix.read from b 0 4096))
  | exception Unix.Unix_error (Unix.EINTR, _, _) -> None

(* [first]: the bytes that came with the helper's + (a client's
 * request is often there before the + is read) *)
let helper_relay (to_, from) first : TinyMachinePeer.relay =
  let first = ref first in
  { take = (fun () ->
      if !first <> "" then (let bytes = !first in first := ""; Some bytes)
      else match helper_read from 0. with None -> Some "" | Some "" -> None | Some bytes -> Some bytes);
    put = (fun bytes -> try Procs.write_all to_ bytes with Unix.Unix_error _ -> ());
    shut = (fun () -> Unix.close to_; Unix.close from) }

(* what the helper said first, if it has: a relay when it is +, its
 * pipes closed when it is not *)
let helper_said pipes wait =
  match helper_read (snd pipes) wait with
  | None -> None
  | Some bytes when bytes <> "" && bytes.[0] = '+' -> Some (Some (helper_relay pipes (String.sub bytes 1 (String.length bytes - 1))))
  | Some _ -> (helper_relay pipes "").shut (); Some None

(* -net-out, for "www address": a web page fetched by tiny-machine-fetch,
 * a program beside this one (it links ix's TLS and HTTP), whose output
 * is the page. The machine waits meanwhile, which changes nothing of
 * its time. None when the helper could not fetch it (no network, no
 * such host): then its output is a line that says why. *)
let fetch (caps : < Cap.fork; Cap.exec; .. >) args =
  let in_r, in_w = Unix.pipe ~cloexec:true () and from, out_w = Unix.pipe ~cloexec:true () in
  let name = if Filename.check_suffix Sys.executable_name ".exe" then "TinyMachine/TinyMachineFetch.exe" else "tiny-machine-fetch" in
  let pid = Procs.spawn caps (Filename.concat (Filename.dirname Sys.executable_name) name) args ~stdin:in_r ~stdout:out_w in
  Unix.close in_r; Unix.close in_w; Unix.close out_w;
  let b = Buffer.create 65536 and chunk = Bytes.create 65536 in
  let rec read () = match Unix.read from chunk 0 65536 with 0 -> () | n -> Buffer.add_subbytes b chunk 0 n; read () | exception Unix.Unix_error (Unix.EINTR, _, _) -> read () in
  read ();
  Unix.close from;
  match Unix.waitpid [] pid with
  | _, Unix.WEXITED 0 -> Ok (Buffer.contents b)
  | _ -> Error (Buffer.contents b)

(* -net-out: a connection to an address and a port, if there is one in
 * the five seconds the helper tries for (the machine waits meanwhile);
 * a name's address, as text *)
let outside caps : TinyMachinePeer.outside =
  { connect = (fun address port ->
      let pipes = helper caps [ "dial"; address; string_of_int port ] in
      match helper_said pipes 10. with
      | Some relay -> relay
      | None -> (helper_relay pipes "").shut (); None);
    name = (fun name ->
      let to_, from = helper caps [ "name"; name ] in
      let answer = match helper_read from 10. with Some line -> String.trim line | None -> "" in
      Unix.close to_; Unix.close from;
      answer) }

(* pcap: a capture's header (the magic, version 2.4, a packet's 65,535
 * bytes at most, link type 101: raw IP), and a packet after its time
 * (seconds, microseconds) and its length twice, all little-endian:
 * what tcpdump -r and Wireshark read *)
let le32 v = String.init 4 (fun i -> Char.chr ((v lsr (8 * i)) land 255))
let pcap_header = le32 0xa1b2c3d4 ^ "\002\000\004\000" ^ le32 0 ^ le32 0 ^ le32 65535 ^ le32 101
let pcap_packet instructions packet =
  let us = int_of_float (float_of_int instructions *. 1e6 /. float_of_int !TinyMachineDevices.rate) in
  le32 (us / 1000000) ^ le32 (us mod 1000000) ^ le32 (String.length packet) ^ le32 (String.length packet) ^ packet

(* The speed with a window, in instructions per second, when -rate does
 * not say. A host that cannot keep up just runs as fast as it can: a
 * 2.2 GHz Neoverse ran the native machine at 22 million a second, an
 * M3 Pro at 50 to 66 (plan_tiny_web.md, tests/TinyMachine_bench.sh). *)
let window_rate = 20_000_000

let run caps o image =
  TinyMachineDevices.rate := (match o.rate with Some r -> r | None -> if o.window then window_rate else TinyMachineDevices.default_rate);
  let disk_file = o.disk_file in
  let disk = match disk_file with Some f -> Bytes.of_string (FS.read caps (Fpath.v f)) | None -> Bytes.empty in
  (* a session's keys are the console's input: the host's is then not
   * read, and a session's last event is its end. A window's keys are
   * the console's too, with the host's: a kernel that writes on the
   * console and not yet on the screen is typed at where it answers *)
  let events = Option.map (fun f -> TinyMachineDevices.timed_events (FS.read caps (Fpath.v f))) o.events_file in
  let stdin_keys = events = None in
  let put ch = Console.print caps (String.make 1 ch); flush (Console.stdout caps) in
  (* the wire's other end: with -net-loop, the wire itself, coming back.
   * [send] is called by the machine it gives packets to: by a reference *)
  let machine = ref None in
  let give after packet = Option.iter (fun mc -> TinyMachineDevices.net_give mc ~after packet) !machine in
  (* -net-trace: a packet's line, with the machine's time in its ms *)
  let said dir packet =
    if o.net_trace then
      Option.iter (fun (mc : TinyMachineDevices.machine) ->
        Console.eprint caps (Printf.sprintf "%9.1f ms  %s %s\n" (float_of_int mc.csr.(TinyMachineDevices.time) *. 1000. /. float_of_int !TinyMachineDevices.rate) dir (TinyMachinePeer.net_describe packet))) !machine in
  (* -net dir: the peer (TinyMachinePeer: TinyKernelNetwork.ml as the kernel has
   * it, at the other address), its documents the directory's files by
   * their names, no path; -net-lose: which of its packets are lost *)
  let document dir line messages =
    let file name = if name = "" || name.[0] = '.' || String.contains name '/' then None else FS.read_opt caps (Fpath.v (Filename.concat dir name)) in
    (* "www address": a web page for tiny-kernel's browser. With
     * -net-out it is fetched; without, or when the fetch fails, a kept
     * copy of a Wikipedia article in dir (OCaml.html) answers. *)
    if String.length line > 4 && String.sub line 0 4 = "www " then begin
      let url = TinyMachinePeer.www_address (String.sub line 4 (String.length line - 4)) in
      let kept () = Option.bind (TinyMachinePeer.www_kept url) file in
      let page =
        if o.net_out then
          match fetch caps [ url ] with
          | Ok body -> body
          | Error why -> (match kept () with Some body -> body | None -> why)
        else
          match kept () with
          | Some body -> body
          | None -> "www: " ^ url ^ ": no copy kept in " ^ dir ^ " (with -net-out, tiny-machine fetches it)\n" in
      messages (TinyMachinePeer.messages page)
    end
    (* "img w h address": a picture of a page, w by h, in the machine's
     * colours: the helper decodes it, the address's (with -net-out) or
     * a kept copy in dir *)
    else if String.length line > 4 && String.sub line 0 4 = "img " then begin
      let none = TinyMachinePeer.picture "" 0 0 "" in
      messages (match String.split_on_char ' ' (String.sub line 4 (String.length line - 4)) with
        | w :: h :: address when int_of_string_opt w <> None && int_of_string_opt h <> None ->
            let w = int_of_string w and h = int_of_string h and url = String.concat " " address in
            let decode source = match fetch caps [ "-picture"; string_of_int w; string_of_int h; source ] with
              | Ok pixels when String.length pixels = w * h -> Some (TinyMachinePeer.picture "" w h pixels)
              | _ -> None in
            let kept () = match TinyMachinePeer.www_picture_kept url with
              | Some name when Sys.file_exists (Filename.concat dir name) -> decode (Filename.concat dir name)
              | _ -> None in
            if w <= 0 || h <= 0 || w > TinyKernelNetwork.il_max then none
            else (match (if o.net_out then decode url else None) with Some l -> l | None -> (match kept () with Some l -> l | None -> none))
        | _ -> none)
    end
    else
    (* "wiki plan 9": dir's plan_9.wiki, a picture kept with its text *)
    if String.length line > 5 && String.sub line 0 5 = "wiki " then begin
      let words = String.sub line 5 (String.length line - 5) in
      let name = String.map (fun c -> if c = ' ' then '_' else Char.lowercase_ascii c) words ^ ".wiki" in
      messages (match Option.bind (file name) TinyMachinePeer.kept with
        | Some l -> l
        | None -> TinyMachinePeer.picture ("wiki: nothing on " ^ words ^ " (in a terminal, the pictures are " ^ dir ^ "'s)\n") 0 0 "")
    end
    else messages (match file line with Some text -> TinyMachinePeer.messages text | None -> [ "get: no " ^ line ^ "\n" ]) in
  (* -net-pcap: the packets that crossed, written at the halt *)
  let capture = Buffer.create 4096 in
  let said dir packet =
    said dir packet;
    if o.net_pcap <> None && dir <> "x" then
      Option.iter (fun (mc : TinyMachineDevices.machine) -> Buffer.add_string capture (pcap_packet mc.csr.(TinyMachineDevices.time) packet)) !machine in
  let peer = match o.net_loop, o.net with
    | None, Some dir ->
        let peer = TinyMachinePeer.create ~give ~said ~document:(document dir) ~outside:(if o.net_out then Some (outside caps) else None) in
        List.iter (TinyMachinePeer.lose peer) o.net_lose;
        Some peer
    | _ -> None in
  let send = match o.net_loop, peer with
    | Some after, _ -> Some (give after)
    | None, Some peer -> Some (TinyMachinePeer.send peer)
    | None, None -> None in
  (* -net-forward 8080:80: a helper waits for a connection to the
   * host's port 8080; when it says one is there, the peer dials the
   * machine's port 80 with it as the other side, and another helper
   * waits for the next. One that cannot listen is said and dropped *)
  let waiting = ref (List.map (fun (host, port) -> host, port, helper caps [ "listen"; string_of_int host ]) o.net_forward) in
  let forwards peer =
    waiting := List.filter_map (fun (host, port, pipes) ->
      match helper_said pipes 0. with
      | None -> Some (host, port, pipes)
      | Some (Some relay) -> TinyMachinePeer.dial peer port relay; Some (host, port, helper caps [ "listen"; string_of_int host ])
      | Some None -> Console.eprint caps (Printf.sprintf "tiny-machine: -net-forward: the host's port %d cannot be listened on\n" host); None)
      !waiting in
  let mc : TinyMachineDevices.machine = TinyMachineDevices.create ~put ~on_open:(console_open caps) ~send ~disk ~events image in
  machine := Some mc;
  let m = mc.cpu and c = mc.csr in
  let window = if o.window then Some (window_open caps) else None in
  let env = TinyMachineDevices.env mc in
  let halted n =
    (match disk_file with Some f when mc.disk.dirty -> FS.write caps (Fpath.v f) (Bytes.to_string mc.disk.image) | _ -> ());
    Option.iter (fun f -> FS.write caps (Fpath.v f) (ppm m)) o.screen_file;
    Option.iter (fun f -> FS.write caps (Fpath.v f) (pcap_header ^ Buffer.contents capture)) o.net_pcap;
    (* (the helpers that wait for a connection: their input's end is theirs) *)
    List.iter (fun (_, _, pipes) -> (helper_relay pipes "").shut ()) !waiting;
    n in
  try
    while true do
      (* the hosts' turns, by the time this instruction will be *)
      let t = c.(TinyMachineDevices.time) + 1 in
      if stdin_keys && t land 1023 = 0 then console_poll mc.cons;
      if t land (polled - 1) = 0 then Option.iter (fun w -> window_poll w m mc.mouse mc.cons) window;
      if t land (polled - 1) = 0 && !waiting <> [] then Option.iter forwards peer;
      (* old: TinyMachineDevices.tick mc env, an instruction a turn of this
       * loop; now the instructions to the next turn that does something *)
      TinyMachineDevices.ticks mc env (1024 - (t land 1023))
    done;
    0
  with TinyMachineDevices.Halt n -> halted n

let main (caps : < Cap.stdin; Cap.stdout; Cap.stderr; Cap.argv; Cap.open_in; Cap.open_out; Cap.fork; Cap.exec; .. >) =
  let args = List.tl (Array.to_list (CapSys.argv caps)) in
  TinyMachineCPU.memsize := TinyMachineDevices.memsize;
  let image files =
    if files = [] || (List.hd files).[0] = '-' then raise Exit;
    TinyMachineCPU.image ~ext:TinyMachineDevices.ext ~origin:0 (List.map (fun f -> f, FS.read caps (Fpath.v f)) files) in
  try
    match args with
    | ("-h" | "--help") :: _ -> Console.print caps help; 0
    | "-l" :: files -> Console.print caps (TinyMachineCPU.listing ~ext:TinyMachineDevices.ext ~origin:0 (image files)); 0
    | "-o" :: out :: files -> FS.write caps (Fpath.v out) (image files); 0
    | args ->
        let rec options o = function
          | "-d" :: f :: rest -> options { o with disk_file = Some f } rest
          | "-screen" :: f :: rest -> options { o with screen_file = Some f } rest
          | "-events" :: f :: rest -> options { o with events_file = Some f } rest
          | "-window" :: rest -> options { o with window = true } rest
          | "-rate" :: n :: rest when (match int_of_string_opt n with Some n -> n > 0 && n <= 1000 | None -> false) ->
              options { o with rate = Some (int_of_string n * 1_000_000) } rest
          | "-net" :: dir :: rest -> options { o with net = Some dir } rest
          | "-net-trace" :: rest -> options { o with net_trace = true } rest
          | "-net-lose" :: n :: rest when int_of_string_opt n <> None -> options { o with net_lose = int_of_string n :: o.net_lose } rest
          | "-net-out" :: rest -> options { o with net_out = true } rest
          | "-net-pcap" :: f :: rest -> options { o with net_pcap = Some f } rest
          | "-net-forward" :: ports :: rest
            when (match List.map int_of_string_opt (String.split_on_char ':' ports) with [ Some _; Some _ ] -> true | _ -> false) ->
              let ports = List.map int_of_string (String.split_on_char ':' ports) in
              options { o with net_forward = (List.hd ports, List.nth ports 1) :: o.net_forward } rest
          | "-net-loop" :: n :: rest when int_of_string_opt n <> None -> options { o with net_loop = int_of_string_opt n } rest
          | files -> run caps o (image files) in
        options { disk_file = None; screen_file = None; events_file = None; window = false; rate = None; net_loop = None; net = None; net_trace = false; net_lose = []; net_out = false; net_forward = []; net_pcap = None } args
  with
  | Exit -> Console.eprint caps (usage ^ "   (-h: how)\n"); 2
  | TinyMachineCPU.Error e | Sys_error e -> Console.eprint caps ("tiny-machine: " ^ e ^ "\n"); 1

let () = Cap.main (fun caps -> Logging.setup caps ~name:"tiny-machine"; CapStdlib.exit caps (main caps))
