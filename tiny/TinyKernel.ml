(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyKernel.mli *)

(* what draws, and the rows of bytes it draws by (TinyKernel/memory.ml
 * here): the Makefile gives tiny-ml their files before this one, as
 * one program *)
open TinyMemory
open TinyGraphics
(* and what speaks to the network *)
open TinyNetwork

(*****************************************************************************)
(* The machine: entry.tm's and runtime.c's functions *)
(*****************************************************************************)

external k_init : unit -> unit = "k_init"
external k_run : int -> int = "k_run"
external k_tval : unit -> int = "k_tval"
external k_timer : int -> unit = "k_timer"
external k_ie : int -> unit = "k_ie"
external k_clock : unit -> int = "k_clock"
external k_window : int -> int -> unit = "k_window"
external k_copy : int -> int -> int -> unit = "k_copy"
external k_zero : int -> int -> unit = "k_zero"
external k_end : unit -> int = "k_end"
external peek : int -> int = "peek"
external poke : int -> int -> unit = "poke"
external peekb : int -> int = "peekb"
external pokeb : int -> int -> unit = "pokeb"
external k_string : int -> int -> string = "k_string"
external k_blit : string -> int -> int -> int -> unit = "k_blit"
external k_console : int -> int -> unit = "k_console"
external k_font : unit -> int = "k_font"

(* the memory (runtime.c's): the frames below the heap, then the
 * partitions, the images, the screen; the devices at the top *)
let part = 0x100000
let nslots = 8
let base slot = 0x500000 + (slot * part)
let frame slot = 0x1c0000 + (slot * 68)
let cons_out = 0xfffff0
let halt_dev = 0xfffff4
let cons_in = 0xfffff8
let mouse_dev = 0xfffffc
(* the network's four words (an address, a length, a command, whether
 * there is a wire), and a packet's place in memory, below the heap *)
let net_dev = 0xffffd0
let net_buf = 0x1f0000

(* a trap's causes (TinyMachine.ml's), the timer's period *)
let c_sys = 1
let c_intr = 4
let tick = 20000

let puts s = for i = 0 to String.length s - 1 do pokeb cons_out (Char.code s.[i]) done
let halt status = poke halt_dev status

(*****************************************************************************)
(* The files: a tree of ML values *)
(*****************************************************************************)

(* a directory is a list of names in the order they were made; the
 * console is a node too, /console, and the screen and the mouse, /draw
 * and /mouse. A file of the image is read where the image has it (its
 * address, its size) until it is written: the programs, a megabyte of
 * them, are then not the collector's to copy at each collection (old:
 * each a string, Data; a collection was 3 million instructions) *)
type node = Dir of (string * node) list ref | Data of string ref | Rom of int * int | Tty | Screen | Pointer

(* a pipe: the bytes written not yet read (512 at most), its readers'
 * and its writers' descriptors (a read of an empty pipe with no writer
 * left is its end) *)
type pipe = { mutable buf : string; mutable readers : int; mutable writers : int }

(* an open file: a node (its offset, whether it is written), a pipe's
 * end, the console, a connection to the screen, a box's end. The
 * collector frees them; only pipes count their ends, as a reader must
 * learn that no writer is left, and a connection its descriptors, as
 * its images are not the collector's *)
type file = Open of opened | Reader of pipe | Writer of pipe | Console | Draw of drawing | Peek of box | Post of box | Link of link | Call of call
and opened = { node : node; mutable off : int; writes : bool }
and drawing = { conn : conn; mutable refs : int }

(* a box: a pipe that keeps only what was last written, and whether it
 * was read since (the mouse is a place, not its history: a reader that
 * is late finds where it is, and a writer never waits). Peek reads it,
 * Post writes it; the kernel's own is the mouse, a window system's are
 * its windows' mice *)
and box = { mutable last : string; mutable fresh : bool; mutable posters : int }

(* a link to another machine (plan_tiny_network.md): so far an echo's.
 * What is written is sent there as a question, and a read gives an
 * answer's bytes, whole, in the order they came; a link has a number,
 * which its questions carry and their answers bring back *)
and link = { peer : string; lid : int; mutable asked : int; mutable heard : string list; mutable holders : int }

(* a connection to a program of another machine (TinyNetwork.ml's IL):
 * a write is a message, which arrives once and in order or is sent
 * again; a read gives one whole, 0 when the other end is done; and its
 * descriptors, the last one's close saying the end *)
and call = { il : il; mutable callers : int }

let root = Dir (ref [])

let rec assoc_opt x l = match l with [] -> None | (k, v) :: r -> if k = x then Some v else assoc_opt x r

(* a path's names from the root: the current directory's first unless
 * it starts with /, "." dropped, ".." the name before it removed (by
 * the text, as Plan 9's cleanname: no ".." in a directory) *)
let names cwd path =
  let rec split i j acc =
    if j = String.length path then List.rev (String.sub path i (j - i) :: acc)
    else if path.[j] = '/' then split (j + 1) (j + 1) (String.sub path i (j - i) :: acc)
    else split i (j + 1) acc in
  let start = if String.length path > 0 && path.[0] = '/' then [] else List.rev cwd in
  List.rev (List.fold_left (fun acc n ->
    if n = "" || n = "." then acc else if n = ".." then (match acc with [] -> [] | _ :: r -> r) else n :: acc)
    start (split 0 0 []))

let rec walk node ns =
  match ns, node with
  | [], _ -> Some node
  | n :: rest, Dir d -> (match assoc_opt n !d with Some c -> walk c rest | None -> None)
  | _ -> None

(* the directory a path's last name is in, and that name *)
let dir_of ns =
  match List.rev ns with
  | [] -> None
  | last :: r -> (match walk root (List.rev r) with Some (Dir d) -> Some (d, last) | _ -> None)

(* a directory read as a file: an entry of 32 bytes per name, t6's (its
 * name in 20, its type, a first block of 0, its size), which ls reads *)
let word n =
  String.make 1 (Char.chr (n land 255)) ^ String.make 1 (Char.chr ((n lsr 8) land 255))
  ^ String.make 1 (Char.chr ((n lsr 16) land 255)) ^ String.make 1 (Char.chr ((n lsr 24) land 255))

let contents node =
  match node with
  | Data d -> !d
  | Rom (at, n) -> k_string at n
  | Tty | Screen | Pointer -> ""
  | Dir d ->
      List.fold_left (fun acc (name, n) ->
        let t, size = match n with Dir _ -> 1, 0 | Data d -> 2, String.length !d | Rom (_, n) -> 2, n | _ -> 3, 0 in
        acc ^ name ^ String.make (20 - String.length name) '\000' ^ word t ^ word 0 ^ word size) "" !d

(* the files the image carries after the kernel (TinyKernel/Makefile's): a
 * name, a line; its size, a line; its bytes; an empty name at the end *)
let rec load a =
  let rec line a acc = let c = peekb a in if c = 10 then acc, a + 1 else line (a + 1) (acc ^ String.make 1 (Char.chr c)) in
  let name, a = line a "" in
  if name <> "" then begin
    let size, a = line a "" in
    let n = ref 0 in
    for i = 0 to String.length size - 1 do n := (!n * 10) + Char.code size.[i] - 48 done;
    (match root with Dir d -> d := !d @ [ name, Rom (a, !n) ] | _ -> ());
    load (a + !n)
  end

(*****************************************************************************)
(* Processes *)
(*****************************************************************************)

(* ready to run; waiting, the rest of its system call (true when it
 * could finish); ended, its status kept for its parent's wait *)
type state = Ready | Waiting of (unit -> bool) | Zombie of int

(* its slot (its partition and its frame), its pid, its state, its
 * parent's pid (0: none), its descriptors, its current directory; and,
 * waiting for a child's end, how many processes had ended when it last
 * looked (-1: it waits for something else) *)
type proc = {
  slot : int; pid : int; mutable state : state; mutable parent : int; mutable fds : (int * file) list; mutable cwd : string list;
  mutable since : int;
}

(* the processes, in the order the scheduler goes through them; how
 * many have ended *)
let procs = ref []
let next_pid = ref 1
let deaths = ref 0

(* a register of its frame (r1..r15, the pc as 16), as entry.tm saved it *)
let reg p k = peek (frame p.slot + (4 * k))
let set_reg p k v = poke (frame p.slot + (4 * k)) v

(* a user's address, n bytes long, as the kernel reaches it; Bad if it
 * leaves the partition *)
exception Bad
let user p va n = if va < 0 || n < 0 || va + n > part then raise Bad else base p.slot + va

(* a string of the user's, 64 bytes at most *)
let ustr p va =
  let rec go i acc = if i >= 64 then raise Bad else let c = peekb (user p (va + i) 1) in if c = 0 then acc else go (i + 1) (acc ^ String.make 1 (Char.chr c)) in
  go 0 ""

let free_slot () =
  let rec go s = if s >= nslots then raise Bad else if List.exists (fun p -> p.slot = s) !procs then go (s + 1) else s in
  go 0

(* a descriptor's file; the lowest free descriptor (32 a process: a
 * window system has four a window), given f *)
let fd p k = match assoc_opt k p.fds with Some f -> f | None -> raise Bad
let fdalloc p f =
  let rec go k = if k >= 32 then raise Bad else if List.exists (fun (j, _) -> j = k) p.fds then go (k + 1) else k in
  let k = go 0 in
  p.fds <- p.fds @ [ k, f ];
  k

(* a file's one more or one less descriptor (a pipe's ends count; a
 * connection's last one frees its images) *)
let share f =
  match f with
  | Reader pi -> pi.readers <- pi.readers + 1
  | Writer pi -> pi.writers <- pi.writers + 1
  | Draw d -> d.refs <- d.refs + 1
  | Post b -> b.posters <- b.posters + 1
  | Link l -> l.holders <- l.holders + 1
  | Call c -> c.callers <- c.callers + 1
  | _ -> ()

let links = ref []
let next_link = ref 1

(* the machine's connections: TinyNetwork.ml's, at its address *)
let net = net_stack net_machine 1000

let drop f =
  match f with
  | Link l -> l.holders <- l.holders - 1; if l.holders = 0 then links := List.filter (fun m -> m.lid <> l.lid) !links
  | Call c -> c.callers <- c.callers - 1; if c.callers = 0 then il_done c.il
  | Reader pi -> pi.readers <- pi.readers - 1
  | Writer pi -> pi.writers <- pi.writers - 1
  | Draw d -> d.refs <- d.refs - 1; if d.refs = 0 then disconnect d.conn
  | Post b -> b.posters <- b.posters - 1
  | _ -> ()

(*****************************************************************************)
(* The screen and the mouse (TinyGraphics.ml draws) *)
(*****************************************************************************)

(* The screen is tiny-machine's 640 by 480 bytes; the images' memory is
 * the two megabytes below it, which were two partitions, and what the
 * screen leaves of its own megabyte. The font is the machine's
 * (font.tm, in the image), made a mask at the boot. A program opens
 * /draw for a connection, whose image 0 is the screen, and writes
 * messages; no pixel is in its partition. *)
let screen = { r = rect 0 0 640 480; at = 0xf00000; repl = false }
let font = arena 0xd00000 0x200000; free 0xf4b000 0xb4000; font_mask (k_font ()) (alloc 16384)

(* the mouse: a box the kernel writes (x, y, the buttons, a word each)
 * when the machine's word changed; the clock: the timer's interrupts
 * counted *)
let mouse = { last = ""; fresh = false; posters = 1 }
let ticks = ref 0

(* the earliest time a waiting process asked to be told of (0: none) *)
let alarm = ref 0

(* the machine's time (k_clock's 30 bits) at the last tick counted *)
let counted = ref 0

(*****************************************************************************)
(* Reads and writes: Some n done, None must wait *)
(*****************************************************************************)

(* the console's input, typed and not yet read, and its end *)
let typed = ref ""
let typed_end = ref false

let read f a n =
  match f with
  | Link l ->
      (match l.heard with
       | [] -> None
       | m :: rest -> let k = min n (String.length m) in k_blit m 0 a k; l.heard <- rest; Some k)
  (* a message, whole (what is over n bytes is lost); the end *)
  | Call c ->
      (match il_hear c.il with
       | Some m -> let k = min n (String.length m) in k_blit m 0 a k; Some k
       | None -> if il_over c.il then Some 0 else None)
  | Console ->
      let t = !typed in
      if t = "" then (if !typed_end then Some 0 else None)
      else begin
        (* up to a line's end *)
        let rec upto i = if i >= String.length t || i >= n then i else if t.[i] = '\n' then i + 1 else upto (i + 1) in
        let k = upto 0 in
        k_blit t 0 a k;
        typed := String.sub t k (String.length t - k);
        Some k
      end
  | Reader pi ->
      if pi.buf = "" then (if pi.writers = 0 then Some 0 else None)
      else begin
        let k = min n (String.length pi.buf) in
        k_blit pi.buf 0 a k;
        pi.buf <- String.sub pi.buf k (String.length pi.buf - k);
        Some k
      end
  | Writer _ | Draw _ | Post _ -> Some (-1)
  (* what was last written, once; its end when no writer is left *)
  | Peek b ->
      if b.fresh then (let k = min n (String.length b.last) in b.fresh <- false; k_blit b.last 0 a k; Some k)
      else if b.posters = 0 then Some 0
      else None
  | Open o -> (
      match o.node with
      | Rom (at, size) ->
          let k = max 0 (min n (size - o.off)) in
          row_copy a (at + o.off) k;
          o.off <- o.off + k;
          Some k
      | _ ->
          let s = contents o.node in
          let k = max 0 (min n (String.length s - o.off)) in
          k_blit s o.off a k;
          o.off <- o.off + k;
          Some k)

(* a packet to the wire: at the buffer, then the device's send *)
let net_send packet =
  let n = String.length packet in
  k_blit packet 0 net_buf n;
  poke net_dev net_buf;
  poke (net_dev + 4) n;
  poke (net_dev + 8) 1

let write f a n =
  match f with
  | Link l ->
      if n > 1024 then Some (-1)
      else begin
        l.asked <- l.asked + 1;
        net_send (ip_packet ip_icmp net_machine l.peer (icmp_message icmp_ask l.lid l.asked (k_string a n)));
        Some n
      end
  (* a message: now, or when the other end has acknowledged enough of
   * those before *)
  | Call c ->
      if n > il_max || il_over c.il then Some (-1)
      else if n = 0 then Some 0
      else if il_room c.il then (net_send (il_write c.il (k_string a n) !ticks); Some n)
      else None
  | Console -> k_console a n; Some n
  | Writer pi ->
      if pi.readers = 0 then Some (-1)
      else if String.length pi.buf = 512 then None
      else (let k = min n (512 - String.length pi.buf) in pi.buf <- pi.buf ^ k_string a k; Some k)
  | Open o -> (
      match o.node with
      | Data d when o.writes ->
          let old = !d in
          let at = min o.off (String.length old) in
          let rest = if at + n < String.length old then String.sub old (at + n) (String.length old - at - n) else "" in
          d := String.sub old 0 at ^ k_string a n ^ rest;
          o.off <- at + n;
          Some n
      | _ -> Some (-1))
  (* messages, whole; a bad one is said on the console, the write -1 *)
  | Draw d -> (try messages d.conn (k_string a n); Some n with Graphics why -> puts ("draw: " ^ why ^ "\n"); Some (-1))
  | Post b -> b.last <- k_string a n; b.fresh <- true; Some n
  | Reader _ | Peek _ -> Some (-1)

(* whether a read would not wait *)
let readable f =
  match f with
  | Console -> !typed <> "" || !typed_end
  | Reader pi -> pi.buf <> "" || pi.writers = 0
  | Peek b -> b.fresh || b.posters = 0
  | Link l -> (match l.heard with [] -> false | _ -> true)
  | Call c -> il_readable c.il
  | _ -> true

(*****************************************************************************)
(* The system calls *)
(*****************************************************************************)

(* a call that may wait: tried now, and until it finishes by the
 * scheduler, the process Waiting meanwhile *)
let block p attempt = if not (attempt ()) then (p.state <- Waiting attempt; p.since <- -1)

let result p v = set_reg p 1 v

let sys_rw p rw =
  let f = fd p (reg p 1) and n = reg p 3 in
  let a = user p (reg p 2) n in
  block p (fun () -> match rw f a n with Some k -> result p k; true | None -> false)

(* its descriptors closed, its children orphans (their zombies freed);
 * its status for its parent, or its slot free. The first process's
 * end is the machine's *)
let rec exit_proc p status =
  incr deaths;
  List.iter (fun (_, f) -> drop f) p.fds;
  p.fds <- [];
  List.iter (fun q ->
    if q.parent = p.pid then begin
      q.parent <- 0;
      match q.state with Zombie _ -> release q | _ -> ()
    end) !procs;
  if p.pid = 1 then halt status;
  if p.parent = 0 then release p else p.state <- Zombie status

and release q = procs := List.filter (fun r -> r.pid <> q.pid) !procs

(* fork: a new slot, the partition and the frame copied (the child's r1
 * 0), the descriptors shared *)
let sys_fork p =
  let s = free_slot () in
  let q = { slot = s; pid = !next_pid; state = Ready; parent = p.pid; fds = p.fds; cwd = p.cwd; since = -1 } in
  incr next_pid;
  k_copy (base s) (base p.slot) part;
  k_copy (frame s) (frame p.slot) 68;
  List.iter (fun (_, f) -> share f) p.fds;
  procs := !procs @ [ q ];
  set_reg q 1 0;
  result p q.pid

(* a file's program in p's partition, from 0; its arguments as tiny-cpu
 * leaves them (the strings at the top, then argc, argv and argv's
 * pointers: start.tm's); every register 0 but sp. Bad if it is no
 * program, or one that leaves no room for a stack *)
let load_prog p node argv =
  let b = base p.slot in
  let size = match node with Some (Data d) -> String.length !d | Some (Rom (_, n)) -> n | _ -> raise Bad in
  if size > part - 0x10000 then raise Bad;
  k_zero b part;
  (match node with Some (Data d) -> k_blit !d 0 b size | Some (Rom (at, _)) -> row_copy b at size | _ -> ());
  let top = ref part and ptrs = ref [] in
  List.iter (fun s ->
    top := (!top - String.length s - 1) land lnot 3;
    k_blit s 0 (b + !top) (String.length s);
    ptrs := !ptrs @ [ !top ]) argv;
  let sp = (!top - ((List.length argv + 3) * 4)) land lnot 7 in
  poke (b + sp) (List.length argv);
  poke (b + sp + 4) (sp + 8);
  ignore (List.fold_left (fun at a -> poke at a; at + 4) (b + sp + 8) !ptrs);
  k_zero (frame p.slot) 68;
  set_reg p 14 sp

(* exec(path, argv): its program's text, its arguments (16 at most),
 * all read before the partition is changed, so a failed exec returns *)
let sys_exec p =
  let node = walk root (names p.cwd (ustr p (reg p 1))) in
  let rec args i acc =
    if i >= 16 then raise Bad
    else let a = peek (user p (reg p 2 + (4 * i)) 4) in if a = 0 then List.rev acc else args (i + 1) (ustr p a :: acc) in
  load_prog p node (args 0 [])

(* wait(&status): a child's end, the child freed; -1 without children *)
let sys_wait p =
  let a = reg p 1 in
  if a <> 0 then ignore (user p a 4);
  block p (fun () ->
    let kids = List.filter (fun q -> q.parent = p.pid) !procs in
    match kids, List.filter (fun q -> match q.state with Zombie _ -> true | _ -> false) kids with
    | [], _ -> result p (-1); true
    | _, [] -> false
    | _, q :: _ ->
        (match q.state with Zombie s -> if a <> 0 then poke (user p a 4) s | _ -> ());
        release q;
        result p q.pid;
        true);
  (* (a shell waits most of its life: its call is retried when a process ended, not at each turn) *)
  (match p.state with Waiting _ -> p.since <- !deaths | _ -> ())

let o_create = 0x200
let o_trunc = 0x400

let sys_open p =
  let ns = names p.cwd (ustr p (reg p 1)) and mode = reg p 2 in
  let writes = mode land 3 <> 0 in
  let node =
    match walk root ns, dir_of ns with
    | Some n, _ -> n
    | None, Some (d, last) when mode land o_create <> 0 && String.length last < 20 ->
        let n = Data (ref "") in d := !d @ [ last, n ]; n
    | _ -> raise Bad in
  (* (a file of the image opened to be written is a string from now on) *)
  let node =
    match node, dir_of ns with
    | Rom (at, n), Some (d, last) when writes ->
        let made = Data (ref (if mode land o_trunc <> 0 then "" else k_string at n)) in
        d := List.map (fun (name, old) -> if name = last then name, made else name, old) !d;
        made
    | _ -> node in
  (match node with Dir _ when writes -> raise Bad | Data d when mode land o_trunc <> 0 -> d := "" | _ -> ());
  result p (fdalloc p (match node with
    | Tty -> Console
    | Screen -> Draw { conn = connect screen font; refs = 1 }
    | Pointer -> Peek mouse
    | _ -> Open { node = node; off = 0; writes = writes }))

let sys_close p =
  let k = reg p 1 in
  drop (fd p k);
  p.fds <- List.filter (fun (j, _) -> j <> k) p.fds;
  result p 0

let sys_pipe p =
  let a = user p (reg p 1) 8 in
  let pi = { buf = ""; readers = 1; writers = 1 } in
  let r = fdalloc p (Reader pi) in
  let w = fdalloc p (Writer pi) in
  poke a r;
  poke (a + 4) w;
  result p 0

(* box(fds): a box, its reading end and its writing end *)
let sys_box p =
  let a = user p (reg p 1) 8 in
  let b = { last = ""; fresh = false; posters = 1 } in
  let r = fdalloc p (Peek b) in
  let w = fdalloc p (Post b) in
  poke a r;
  poke (a + 4) w;
  result p 0

(* dial(address, port): a descriptor on a connection to the program
 * that listens on that port of the machine at that address
 * ("10.0.0.1"), when it has agreed; -1 when nothing does or nothing
 * answers. Port 0 is the echo: a link, made at once *)
let sys_dial p =
  let to_ = net_address (ustr p (reg p 1)) and port = reg p 2 in
  if to_ = "" || port < 0 || port > 0xffff || peek (net_dev + 12) = 0 then raise Bad;
  if port = 0 then begin
    let l = { peer = to_; lid = !next_link; asked = 0; heard = []; holders = 1 } in
    incr next_link;
    links := l :: !links;
    result p (fdalloc p (Link l))
  end
  else begin
    let c, sync = net_dial net to_ port !ticks in
    net_send sync;
    block p (fun () ->
      match c.il_at with
      | Il_established -> (try result p (fdalloc p (Call { il = c; callers = 1 })) with Bad -> il_done c; result p (-1)); true
      | Il_closed -> result p (-1); true
      | _ -> false)
  end

(* listen(port): a descriptor on the next connection another machine
 * makes to that port of this one, which is listened on from the first
 * call (and stays so: a server is this call in a loop) *)
let sys_listen p =
  let port = reg p 1 in
  if port <= 0 || port > 0xffff || peek (net_dev + 12) = 0 then raise Bad;
  if not (List.mem port net.ns_ports) then net.ns_ports <- port :: net.ns_ports;
  block p (fun () ->
    match List.filter (fun c -> c.il_lport = port) net.ns_fresh with
    | c :: _ ->
        net.ns_fresh <- List.filter (fun d -> d.il_lport <> port || d.il_rport <> c.il_rport || d.il_peer <> c.il_peer) net.ns_fresh;
        (try result p (fdalloc p (Call { il = c; callers = 1 })) with Bad -> il_done c; result p (-1));
        true
    | [] -> false)

let sys_dup p = let f = fd p (reg p 1) in share f; result p (fdalloc p f)

let sys_mkdir p =
  let ns = names p.cwd (ustr p (reg p 1)) in
  match walk root ns, dir_of ns with
  | None, Some (d, last) when String.length last < 20 -> d := !d @ [ last, Dir (ref []) ]; result p 0
  | _ -> raise Bad

(* a name removed; a directory only if empty *)
let sys_unlink p =
  match dir_of (names p.cwd (ustr p (reg p 1))) with
  | Some (d, last) ->
      (match assoc_opt last !d with
       | Some (Dir e) when !e <> [] -> raise Bad
       | Some _ -> d := List.filter (fun (n, _) -> n <> last) !d; result p 0
       | None -> raise Bad)
  | None -> raise Bad

(* kill(pid): its process ended as a fault ends one, its status -1 *)
let kill q = match q.state with Zombie _ -> () | _ -> exit_proc q (-1)
let sys_kill p =
  match List.filter (fun q -> q.pid = reg p 1) !procs with [ q ] -> kill q; result p 0 | _ -> raise Bad

let sys_chdir p =
  let ns = names p.cwd (ustr p (reg p 1)) in
  match walk root ns with Some (Dir _) -> p.cwd <- ns; result p 0 | _ -> raise Bad

(* ready(fds, n, until): the first of n descriptors (32 at most) that a
 * read would not wait on; -1 when the clock reaches until (0: no
 * limit; with no descriptor, a sleep). What a program with a mouse, a
 * keyboard and a picture to move waits on: one closure, as any wait *)
let sys_ready p =
  let n = reg p 2 and until = reg p 3 in
  if n < 0 || n > 32 then raise Bad;
  let a = user p (reg p 1) (4 * n) in
  let rec list i = if i >= n then [] else (let k = peek (a + (4 * i)) in k, fd p k) :: list (i + 1) in
  let l = list 0 in
  block p (fun () ->
    match List.filter (fun (_, f) -> readable f) l with
    | (k, _) :: _ -> result p k; true
    | [] ->
        if until > 0 && !ticks >= until then (result p (-1); true)
        else (if until > 0 && (!alarm = 0 || until < !alarm) then alarm := until; false))

(* by their numbers, the machine's sys n: exit, write and read first,
 * tiny-cpu's own (libc's) *)
let syscall p =
  try
    match k_tval () with
    | 0 -> exit_proc p (reg p 1)
    | 1 -> sys_rw p write
    | 2 -> sys_rw p read
    | 3 -> sys_fork p
    | 4 -> sys_exec p
    | 5 -> sys_wait p
    | 6 -> result p p.pid
    | 7 -> sys_open p
    | 8 -> sys_close p
    | 9 -> sys_pipe p
    | 10 -> sys_dup p
    | 11 -> sys_mkdir p
    | 12 -> sys_unlink p
    | 13 -> sys_chdir p
    | 14 -> sys_kill p
    | 15 -> sys_ready p
    | 16 -> result p !ticks
    | 17 -> sys_box p
    | 18 -> sys_dial p
    | 19 -> sys_listen p
    | _ -> result p (-1)
  with Bad -> result p (-1)

(*****************************************************************************)
(* The scheduler: round robin, preemptive *)
(*****************************************************************************)

(* the interrupts' sources: the timer re-armed (its time is up) and
 * counted, the console's bytes taken, ^C (3) killing the foreground,
 * every process but the shell (the first: no background here), the
 * mouse's word read, the network's packets taken, each given to
 * TinyNetwork.ml (what it says to send back sent, an echo's answer
 * kept for the link that asked; a connection's messages are in it,
 * where its descriptor's read finds them); whether the timer's *)
let net_news = ref false

(* whether a program has messages it has not read; the tick at which
 * the network's interrupt is taken again all the same *)
let net_behind () = List.exists (fun c -> match c.il_r.il_heard with [] -> false | _ -> true) net.ns_conns
let net_open = ref 0

(* the tick of the connections' next look at the time *)
let net_next = ref 0

let net_take () =
  let n = peek (net_dev + 4) in
  if n > 0 then begin
    poke net_dev net_buf;
    poke (net_dev + 4) n;
    poke (net_dev + 8) 2;
    (match net_input net !ticks (k_string net_buf n) with
     | back, answer ->
         List.iter net_send back;
         (match answer with
          | Some (from, id, _, data) -> List.iter (fun l -> if l.lid = id && l.peer = from then l.heard <- l.heard @ [ data ]) !links
          | None -> ()))
    (* (one packet a call: the interrupt stays while another waits, and
     * the timer's is seen between two, so a burst does not stop the
     * clock, nor the acknowledgements, which go at its ticks. old: a
     * loop here, 230 ms without a tick for seven packets of 1 KB) *);
    (* When a program has messages to read, the packets that wait are
     * left for a while (the timer's interrupt says when: one more is
     * taken every 20 ms): the network's interrupt is not taken until
     * then, and the programs run. A burst of 20 rows was taken before
     * its reader read one, 280 ms in which nothing was acknowledged,
     * and the other end asked where it was. *)
    if net_behind () then k_ie 11
  end

let interrupts sources =
  if sources land 16 <> 0 then net_take ();
  if sources land 8 <> 0 then begin
    (* the machine's word: x in 12 bits, y in the next 12, the buttons above *)
    let m = peek mouse_dev in
    mouse.last <- word (m land 0xfff) ^ word ((m lsr 12) land 0xfff) ^ word (m lsr 24);
    mouse.fresh <- true
  end;
  if sources land 2 <> 0 then begin
    let rec take () =
      let c = peek cons_in in
      if c = -2 then typed_end := true
      else if c = 3 then (typed := ""; List.iter (fun q -> if q.pid <> 1 then kill q) !procs; puts "\n"; take ())
      else if c <> -1 then (typed := !typed ^ String.make 1 (Char.chr c); take ()) in
    take ()
  end;
  (* the ticks since the last one counted, by the machine's time: the
   * timer's interrupt waits while the kernel works, and a long call
   * is several ticks (old: one counted at each interrupt, the timer
   * set a tick from then; a game's second was two under a window) *)
  if sources land 1 <> 0 then begin
    let passed = (k_clock () - !counted) land 0x3fffffff in
    ticks := !ticks + (passed / tick);
    counted := (!counted + (passed / tick * tick)) land 0x3fffffff;
    k_timer (tick - (passed mod tick));
    if !ticks >= !net_open || not (net_behind ()) then (net_open := !ticks + 8; k_ie 27);
    (* the connections' time: what they send when nothing came, and one
     * that gave up is news for who waits on it *)
    (* (every fourth tick, 10 ms: a pass over the connections is 3,400
     * instructions with one of them, which at each tick was 4 ms of a
     * picture's row; IL's waits are 40 ticks and more) *)
    (match net.ns_conns with
     | [] -> ()
     | conns ->
         if !ticks >= !net_next then begin
           net_next := !ticks + 4;
           List.iter net_send (net_tick net !ticks);
           if List.length net.ns_conns < List.length conns then net_news := true
         end);
    true
  end
  else false

(* the first process that can run: ready, or waiting and its call now
 * finished *)
let rec runnable l =
  match l with
  | [] -> None
  | p :: rest ->
      (match p.state with
       | Ready -> Some p
       | Waiting attempt ->
           if p.since = !deaths then runnable rest
           else if attempt () then (p.state <- Ready; Some p)
           else (if p.since >= 0 then p.since <- !deaths; runnable rest)
       | Zombie _ -> runnable rest)

(* the loop: a process run until it traps, the trap handled; the same
 * process again unless its time is up or it cannot go on (then it goes
 * last); none to run, an interrupt waited for *)
let rec schedule () =
  match runnable !procs with
  | Some p -> run p
  | None -> idle ()

(* Every process waits. What they wait for changes only by a key, the
 * mouse, or a time one of them asked for (the alarm, which the calls
 * still waiting set again when retried): the clock's other ticks are
 * counted and nothing is retried. (old: schedule () after each
 * interrupt, every closure at each tick: a quarter of the instructions
 * of a machine where nothing happened) *)
and idle () =
  ignore (k_run 0);
  let sources = k_tval () in
  ignore (interrupts sources);
  if sources land 26 <> 0 || !net_news || (!alarm > 0 && !ticks >= !alarm) then (alarm := 0; net_news := false; schedule ()) else idle ()

and run p =
  k_window (base p.slot) part;
  let cause = k_run (frame p.slot) in
  let timer =
    if cause = c_sys then (syscall p; false)
    else if cause = c_intr then interrupts (k_tval ())
    else begin
      puts ("ml: " ^ string_of_int p.pid ^ ": trap " ^ string_of_int cause ^ " at " ^ string_of_int (reg p 16) ^ ", "
            ^ string_of_int (k_tval ()) ^ ": killed\n");
      exit_proc p (-1);
      false
    end in
  let alive = List.exists (fun q -> q.pid = p.pid) !procs in
  if alive && (not timer) && (match p.state with Ready -> true | _ -> false) then run p
  else begin
    (* last in the round *)
    if alive then procs := List.filter (fun q -> q.pid <> p.pid) !procs @ [ p ];
    schedule ()
  end

(*****************************************************************************)
(* The boot *)
(*****************************************************************************)

let () =
  k_init ();
  counted := k_clock ();
  k_timer tick;
  load (k_end ());
  (match root with Dir d -> d := !d @ [ "console", Tty; "draw", Screen; "mouse", Pointer ] | _ -> ());
  puts ("tiny-kernel: TinyKernel.ml, " ^ string_of_int nslots ^ " partitions of " ^ string_of_int (part / 1024) ^ " KB\n");
  (* the first process: /sh, the console its 0, 1 and 2; and for the
   * programs it runs, which inherit them, the screen its 3 (a
   * connection) and the mouse its 4: a window system gives a window's
   * programs the same five, so a program draws in what it was given
   * and does not ask where *)
  let fds = [ 0, Console; 1, Console; 2, Console; 3, Draw { conn = connect screen font; refs = 1 }; 4, Peek mouse ] in
  let p = { slot = 0; pid = 1; state = Ready; parent = 0; fds = fds; cwd = []; since = -1 } in
  incr next_pid;
  procs := [ p ];
  (try load_prog p (walk root [ "sh" ]) [ "sh" ] with Bad -> puts "no /sh\n"; halt 1);
  schedule ()
