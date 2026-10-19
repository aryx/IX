(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyKernel.mli *)

(* what draws, and the rows of bytes it draws by (TinyKernel/TinyMemory.ml
 * here): the Makefile gives tiny-ml their files before this one, as
 * one program *)
open TinyMemory
open TinyKernelGraphics
(* and what speaks to the network, what makes the sounds, and what
 * keeps files on the disk *)
open TinyKernelNetwork
open TinyKernelAudio
open TinyKernelFS

(*****************************************************************************)
(* The machine: entry.tm's and runtime.c's functions *)
(*****************************************************************************)

external k_init : unit -> unit = "k_init"
external k_run : int -> int = "k_run"
external k_tval : unit -> int = "k_tval"
external k_timer : int -> unit = "k_timer"
external k_ie : int -> unit = "k_ie"
external k_clock : unit -> int = "k_clock"
external k_rate : unit -> int = "k_rate"
external k_window : int -> int -> unit = "k_window"
external k_copy : int -> int -> int -> unit = "k_copy"
external k_zero : int -> int -> unit = "k_zero"
external k_end : unit -> int = "k_end"
external peek : int -> int = "peek"
external poke : int -> int -> unit = "poke"
external k_string : int -> int -> string = "k_string"
external k_blit : string -> int -> int -> int -> unit = "k_blit"
external k_console : int -> int -> unit = "k_console"
external k_font : unit -> int = "k_font"

(* The memory. The first 16 MB are the kernel's (runtime.c says how they
 * are used): its image, the processes' frames, its heap, the images it
 * draws, the screen. The processes' memory is above, up to 64 KB below
 * the top of the machine's 128 MB. A process has a partition of the size
 * its program asks for (1 MB if it does not say), found when it starts.
 * There are at most [nslots] processes; a slot is a process's frame. *)
let part = 0x100000
let nslots = 8
let mem_low = 0x1000000
let mem_high = 0x7ff0000
let frame slot = 0x7c0000 + (slot * 68)
(* The devices are at the top of memory. Their addresses are written as
 * negative numbers, which the machine takes modulo its memory size, so
 * the kernel works whatever that size is (-16 is the last 16 bytes). *)
let cons_out = -16
let halt_dev = -12
let cons_in = -8
let mouse_dev = -4
(* the network's four words (an address, a length, a command, whether
 * there is a wire), and a packet's place in memory, below the heap *)
let net_dev = -48
let net_buf = 0x7f0000
(* the speaker's word (its ring's address written, the samples played
 * read), and its ring, in the megabytes nothing else uses *)
let speaker_dev = -52
let ring_at = 0xc00000
(* the disk's four words: a block, an address, a command, a status; the
 * first, read, is the disk's size in blocks (0: no disk) *)
let disk_dev = -32

(* a trap's causes (TinyMachine.ml's), the timer's period *)
let c_sys = 1
let c_illegal = 2
let c_fault = 3
let c_intr = 4
(* The timer's period is 2.5 ms of the machine's time, whatever its
 * speed: 20,000 instructions at 8 million a second. The programs count
 * time in these ticks (a game's frames, IL's waits, ping), so they run
 * at the same pace on a faster machine. *)
let tick = let r = k_rate () in if r < 400 then 20000 else r / 400

let puts s = for i = 0 to String.length s - 1 do pokeb cons_out (Char.code s.[i]) done
(* (what the disk has not been told yet is told first) *)
let halt status = fs_commit (); poke halt_dev status

(*****************************************************************************)
(* The files: a tree of ML values *)
(*****************************************************************************)

(* a directory is a list of names in the order they were made; the
 * console is a node too, /dev/console, and the screen, the mouse and
 * the speaker, /dev/draw, /dev/mouse and /dev/audio (the programs are
 * in /bin, examples to look at in /examples). A file of the image is read where the image has it (its
 * address, its size) until it is written: the programs, a megabyte of
 * them, are then not the collector's to copy at each collection (old:
 * each a string, Data; a collection was 3 million instructions).
 * A file or a directory on the disk (TinyKernelFS.ml) is a tree and an
 * inode's number: tree 0 is the live one, the others are the snapshots.
 * A union is several directories seen as one, as Plan 9's bind -a makes:
 * a name is looked up in each in turn, and what is made goes in the
 * first. A file written in memory is its bytes and its size, the bytes
 * doubled when a write goes past them (old: a string, made again at
 * each write: a database that grows by appends took a second for each
 * statement, tiny-db's) *)
type node = Dir of (string * node) list ref | Data of data | Rom of int * int | Tty | Screen | Pointer | Speaker | Disk of int * int | Union of node list
and data = { mutable dbytes : bytes; mutable dsize : int }

let data s = let b = Bytes.make (String.length s) ' ' in Bytes.blit_string s 0 b 0 (String.length s); { dbytes = b; dsize = String.length s }
let text d = Bytes.sub_string d.dbytes 0 d.dsize

(* a pipe: the bytes written not yet read (512 at most), its readers'
 * and its writers' descriptors (a read of an empty pipe with no writer
 * left is its end) *)
type pipe = { mutable buf : string; mutable readers : int; mutable writers : int }

(* an open file: a node (its offset, whether it is written), a pipe's
 * end, the console, a connection to the screen, a box's end. The
 * collector frees them; only pipes count their ends, as a reader must
 * learn that no writer is left, and a connection its descriptors, as
 * its images are not the collector's *)
type file = Open of opened | Reader of pipe | Writer of pipe | Console | Draw of drawing | Peek of box | Post of box | Link of link | Call of call | Voice of voice | Trace of trace
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

(* a connection to a program of another machine (TinyKernelNetwork.ml's IL):
 * a write is a message, which arrives once and in order or is sent
 * again; a read gives one whole, 0 when the other end is done; and its
 * descriptors, the last one's close saying the end *)
and call = { il : il; mutable callers : int }

(* a voice of the speaker (an open of /dev/audio): where in the samples its
 * next one goes *)
and voice = { mutable ahead : int }

(* a process traced by another, its tracer (debug: plan_tiny_debugger.md):
 * their pids, the breakpoints (an address and the word that was there),
 * what is said to the tracer and not yet read, and the tracer's
 * descriptors on it *)
and trace = { tpid : int; tracer : int; mutable stops : (int * int) list; mutable said : string list; mutable watchers : int }

(* The image's files (and /dev), and the tree a path starts from. They
 * are the same when there is no disk. With a disk, the boot makes the
 * top a union, Plan 9's way: the disk's root first, then /boot (the
 * image's files alone) and /dump, then the image's files again, so
 * that /bin is the disk's /bin and /boot/bin together *)
let root = Dir (ref [])
let top = ref root

(* a path's names from the root: the current directory's first unless
 * it starts with /, "." dropped, ".." the name before it removed (by
 * the text, as Plan 9's cleanname: no ".." in a directory) *)
let names cwd path =
  let start = if String.length path > 0 && path.[0] = '/' then [] else List.rev cwd in
  List.rev (List.fold_left (fun acc n ->
    if n = "" || n = "." then acc else if n = ".." then (match acc with [] -> [] | _ :: r -> r) else n :: acc)
    start (String.split_on_char '/' path))

let is_dir node = match node with Dir _ | Union _ -> true | Disk (r, i) -> fs_is_dir r i | _ -> false

(* In a union, the name is looked up in each directory. The first one
 * found is the answer, unless it is a directory found in several: then
 * the answer is their union (/bin, in the disk and in the image) *)
let rec walk node ns =
  match ns, node with
  | [], _ -> Some node
  | n :: rest, Dir d -> (match List.assoc_opt n !d with Some c -> walk c rest | None -> None)
  | n :: rest, Disk (r, i) when fs_is_dir r i -> (match fs_lookup r i n with 0 -> None | j -> walk (Disk (r, j)) rest)
  | n :: rest, Union l ->
      (match List.fold_left (fun acc m -> match walk m [ n ] with Some c -> acc @ [ c ] | None -> acc) [] l with
       | [] -> None
       | [ c ] -> walk c rest
       | c :: more -> walk (if is_dir c then Union (List.filter is_dir (c :: more)) else c) rest)
  | _ -> None

(* a directory's names and what they are (in a union, a name once: the
 * first) *)
let rec children node =
  match node with
  | Dir d -> !d
  | Disk (r, i) -> List.map (fun (name, j) -> name, Disk (r, j)) (fs_entries r i)
  | Union l -> List.fold_left (fun acc m -> acc @ List.filter (fun (name, _) -> not (List.exists (fun (k, _) -> k = name) acc)) (children m)) [] l
  | _ -> []

(* where a directory's new names go: a union's first *)
let rec home node = match node with Union (m :: _) -> home m | _ -> node

(* the directory a path's last name is in (where it would be made: a
 * Dir, or a directory on the disk), and that name *)
let dir_of ns =
  match List.rev ns with
  | [] -> None
  | last :: r -> (match walk !top (List.rev r) with Some n when is_dir n -> Some (home n, last) | _ -> None)

(* a directory read as a file: an entry of 32 bytes per name, t6's (its
 * name in 20, its type, a first block, its size), which ls reads. The
 * first block, which this kernel has no use for, says the file's links
 * instead: how many names it has *)
let word n =
  String.make 1 (Char.chr (n land 255)) ^ String.make 1 (Char.chr ((n lsr 8) land 255))
  ^ String.make 1 (Char.chr ((n lsr 16) land 255)) ^ String.make 1 (Char.chr ((n lsr 24) land 255))

(* a node's names: the entries in the whole tree that hold the same
 * value (==), the file itself and not a copy of it *)
let links node =
  let rec count d = List.fold_left (fun acc (_, n) -> acc + (if n == node then 1 else 0) + (match n with Dir e -> count e | _ -> 0)) 0 !d in
  match root with Dir d -> count d | _ -> 0

(* an entry: a name, a type, the links, a size; a disk's file says its
 * own (its type is 1 or 2 as here) *)
let entry name n =
  let t, size, l = match n with
    | Dir _ -> 1, 0, links n | Data d -> 2, d.dsize, links n | Rom (_, k) -> 2, k, links n
    | Disk (r, i) -> fs_kind r i | Union _ -> 1, 0, 1 | _ -> 3, 0, links n in
  name ^ String.make (20 - String.length name) '\000' ^ word t ^ word l ^ word size

let contents node =
  match node with
  | Data d -> text d
  | Rom (at, n) -> k_string at n
  | Tty | Screen | Pointer | Speaker -> ""
  | Disk (r, i) when not (fs_is_dir r i) -> fs_contents r i
  | _ -> List.fold_left (fun acc (name, n) -> acc ^ entry name n) "" (children node)

(* [place d name node]: node under name in d; a name with a slash,
 * examples/wc.c, in its directory, which is made the first time *)
let rec place d name node =
  match String.index_opt name '/' with
  | None -> d := !d @ [ name, node ]
  | Some i ->
      let dir = String.sub name 0 i and rest = String.sub name (i + 1) (String.length name - i - 1) in
      (match List.assoc_opt dir !d with
       | Some (Dir sub) -> place sub rest node
       | _ -> let sub = ref [] in d := !d @ [ dir, Dir sub ]; place sub rest node)

(* the files the image carries after the kernel (TinyKernel/Makefile's): a
 * path, a line; its size, a line; its bytes; an empty path at the end.
 * A line "link" and another file's path, in place of the size, makes a
 * hard link, as link() does: the same node under a second name, with
 * no bytes (bin/utils, under the name of each of its utilities:
 * bin/cat, bin/ls...) *)
let rec load a =
  let rec line a acc = let c = peekb a in if c = 10 then acc, a + 1 else line (a + 1) (acc ^ String.make 1 (Char.chr c)) in
  let name, a = line a "" in
  if name <> "" then begin
    let size, a = line a "" in
    match root with
    | Dir d when String.length size > 5 && String.sub size 0 5 = "link " ->
        (match walk root (names [] (String.sub size 5 (String.length size - 5))) with Some node -> place d name node | None -> ());
        load a
    | Dir d ->
        let n = Option.get (int_of_string_opt size) in
        place d name (Rom (a, n));
        load (a + n)
    | _ -> ()
  end

(*****************************************************************************)
(* Processes *)
(*****************************************************************************)

(* ready to run; waiting, the rest of its system call (true when it
 * could finish); ended, its status kept for its parent's wait; stopped
 * for its tracer, until the tracer resumes it *)
type state = Ready | Waiting of (unit -> bool) | Zombie of int | Stopped

(* A process: its slot (where its frame is), where its partition starts
 * and how big it is, its pid, its state, its parent's pid (0: none), its
 * descriptors, its current directory; while it waits for a child's
 * end, how many processes had ended when it last looked (-1: it waits
 * for something else); and its trace, when it is traced. *)
type proc = {
  slot : int; mutable base : int; mutable size : int; pid : int; mutable state : state; mutable parent : int;
  mutable fds : (int * file) list; mutable cwd : string list; mutable since : int; mutable traced : trace option;
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
let user p va n = if va < 0 || n < 0 || va + n > p.size then raise Bad else p.base + va

(* a string of the user's, 64 bytes at most *)
let ustr p va =
  let rec go i acc = if i >= 64 then raise Bad else let c = peekb (user p (va + i) 1) in if c = 0 then acc else go (i + 1) (acc ^ String.make 1 (Char.chr c)) in
  go 0 ""

let free_slot () =
  let rec go s = if s >= nslots then raise Bad else if List.exists (fun p -> p.slot = s) !procs then go (s + 1) else s in
  go 0

(* Finds room for a partition of [size] bytes: the first gap that is big
 * enough between the partitions of the other processes, ordered by
 * address. [except] is a process whose partition does not count (exec
 * replaces it). Bad if there is no room. *)
let room size except =
  let used = List.filter (fun q -> q.pid <> except && q.size > 0) !procs in
  let rec insert q = function [] -> [ q ] | r :: rest -> if q.base <= r.base then q :: r :: rest else r :: insert q rest in
  let sorted = List.fold_left (fun l q -> insert q l) [] used in
  let rec go at = function
    | [] -> if at + size <= mem_high then at else raise Bad
    | q :: rest -> if at + size <= q.base then at else go (max at (q.base + q.size)) rest in
  go mem_low sorted

(* a descriptor's file; the lowest free descriptor (32 a process: a
 * window system has four a window), given f *)
let fd p k = match List.assoc_opt k p.fds with Some f -> f | None -> raise Bad
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
  | Trace t -> t.watchers <- t.watchers + 1
  | _ -> ()

let links = ref []
let next_link = ref 1

(* the machine's connections: TinyKernelNetwork.ml's, at its address *)
let net = net_stack net_machine 1000

(* the process a trace is of, while it has not ended *)
let traced_proc t =
  match List.filter (fun q -> q.pid = t.tpid) !procs with
  | [ q ] -> (match q.state with Zombie _ -> None | _ -> Some q)
  | _ -> None

(* the trace ended (its tracer's last descriptor closed, or the tracer
 * ended): the words under the breakpoints put back, the process run
 * again if it was stopped *)
let detach t =
  match traced_proc t with
  | Some q ->
      List.iter (fun (a, w) -> poke (q.base + a) w) t.stops;
      t.stops <- [];
      q.traced <- None;
      (match q.state with Stopped -> q.state <- Ready | _ -> ())
  | None -> ()

let drop f =
  match f with
  | Trace t -> t.watchers <- t.watchers - 1; if t.watchers = 0 then detach t
  | Link l -> l.holders <- l.holders - 1; if l.holders = 0 then links := List.filter (fun m -> m.lid <> l.lid) !links
  | Call c -> c.callers <- c.callers - 1; if c.callers = 0 then il_done c.il
  | Reader pi -> pi.readers <- pi.readers - 1
  | Writer pi -> pi.writers <- pi.writers - 1
  | Draw d -> d.refs <- d.refs - 1; if d.refs = 0 then disconnect d.conn
  | Post b -> b.posters <- b.posters - 1
  | _ -> ()

(*****************************************************************************)
(* The screen and the mouse (TinyKernelGraphics.ml draws) *)
(*****************************************************************************)

(* The screen is tiny-machine's 640 by 480 bytes. The images live in the
 * two megabytes below it, and in what the screen leaves of its own
 * megabyte. (Most of the 3 MB below those, from 10 MB, is unused; it could be
 * the images' too. Trying it once changed the recorded paint session's
 * screen, which was taken for a bug: it was paint's ball, which moves
 * with the clock, ending elsewhere because the kernel's work took
 * another time.) The font is the machine's
 * (font.tm, in the image), made a mask at the boot. A program opens
 * /dev/draw for a connection, whose image 0 is the screen, and writes
 * messages; no pixel is in its partition. *)
let screen = { r = rect 0 0 640 480; at = 0xf00000; repl = false }
(* the mouse's look a program asks for (www, over a link) is written to
 * the machine's mouse word, which the host shows *)
let () = cursor_hook := (fun kind -> poke mouse_dev kind)
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

(* The speaker (plan_tiny_audio.md): tiny-machine plays the ring, 8,192
 * samples, 8,000 a second, and silences what it played. Each open of
 * /dev/audio is a voice: a program writes messages, each a sound or
 * samples (TinyKernelAudio.mli), which the kernel makes into the ring, added to
 * what is there already, so two programs are heard at once and neither
 * waits for the other. A voice's sounds follow one another: the next
 * one goes where the last ended, or, when the speaker passed it, a
 * little ahead of the speaker ([lead], 5 ms, more than a write takes to
 * start); a write waits until all its sounds fit, a ring (a second)
 * ahead of the speaker at most. *)
let ring = 8192
let lead = 40
let played () = peek speaker_dev
let speak v sounds =
  let now = played () in
  if (v.ahead - now) land 0x3fffffff > ring then v.ahead <- (now + lead) land 0x3fffffff;
  let total = List.fold_left (fun acc snd -> acc + sound_length snd) 0 sounds in
  if total > ring - ((v.ahead - now) land 0x3fffffff) then false
  else begin
    List.iter (fun snd -> mix_sound ring_at ring v.ahead snd; v.ahead <- (v.ahead + sound_length snd) land 0x3fffffff) sounds;
    true
  end

(*****************************************************************************)
(* Reads and writes: Some n done, None must wait *)
(*****************************************************************************)

(* the console's input, typed and not yet read, and its end *)
let typed = ref ""
let typed_end = ref false

(* the process that has the console raw (rawcons), or 0: its ^C is a
 * byte typed, not the kill of every process *)
let raw = ref 0
let raw_on () = List.exists (fun q -> q.pid = !raw && (match q.state with Zombie _ -> false | _ -> true)) !procs

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
      let eot = not (raw_on ()) in
      if t = "" then (if !typed_end then Some 0 else None)
      (* ^D, but at a raw console: the read's end, nothing read, as
       * Plan 9's (old: a byte, and only the input's end ended a read) *)
      else if eot && t.[0] = '\004' then (typed := String.sub t 1 (String.length t - 1); Some 0)
      else begin
        (* up to a line's end, or a ^D *)
        let rec upto i = if i >= String.length t || i >= n then i else if t.[i] = '\n' then i + 1 else if eot && t.[i] = '\004' then i else upto (i + 1) in
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
  | Writer _ | Draw _ | Post _ | Voice _ -> Some (-1)
  (* what the trace said, a line at a time; its end when the process ended *)
  | Trace t ->
      (match t.said with
       | m :: rest -> let k = min n (String.length m) in k_blit m 0 a k; t.said <- rest; Some k
       | [] -> (match traced_proc t with Some _ -> None | None -> Some 0))
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
      (* a disk's file, from its blocks to the program's memory *)
      | Disk (r, i) when not (fs_is_dir r i) ->
          let k = fs_read_at r i o.off a n in
          o.off <- o.off + k;
          Some k
      | Data d ->
          let k = max 0 (min n (d.dsize - o.off)) in
          k_blit (Bytes.sub_string d.dbytes o.off k) 0 a k;
          o.off <- o.off + k;
          Some k
      | _ ->
          let s = contents o.node in
          let k = max 0 (min n (String.length s - o.off)) in
          k_blit s o.off a k;
          o.off <- o.off + k;
          Some k)

(* the network device's command (1 send, 2 take) on n bytes at the buffer *)
let net_command n cmd = poke net_dev net_buf; poke (net_dev + 4) n; poke (net_dev + 8) cmd

(* a packet to the wire: at the buffer, then the device's send *)
let net_send packet =
  let n = String.length packet in
  k_blit packet 0 net_buf n;
  net_command n 1

(* A traced process stopped, and why said to its tracer: where it is
 * (its pc), then break (a breakpoint's word), illegal and the word,
 * fault and the address, or exec (its new program's first instruction) *)
let traced p = match p.traced with Some _ -> true | None -> false
let stop p why =
  p.state <- Stopped;
  match p.traced with
  | Some t -> t.said <- t.said @ [ "stopped " ^ string_of_int (reg p 16) ^ " " ^ why ^ "\n" ]
  | None -> ()

(* A tracer's command (plan_tiny_debugger.md), the numbers in decimal:
 * b addr, a breakpoint, the word there kept and 0 written in its place
 * (no instruction is 0: the process traps there, c_illegal); d addr,
 * the breakpoint removed, its word put back; r, the registers (r1 to
 * r15, then the pc); c, the stopped process resumed. A breakpoint is
 * used once: c from it puts its word back and removes it. Bad if the
 * command is none of these, or its address not one of the process's
 * words. *)
let command t q words =
  let addr s = match int_of_string_opt s with Some a when a land 3 = 0 -> ignore (user q a 4); a | _ -> raise Bad in
  let say m = t.said <- t.said @ [ m ^ "\n" ] in
  let unset a = (match List.assoc_opt a t.stops with Some w -> poke (q.base + a) w | None -> ()); t.stops <- List.filter (fun (b, _) -> b <> a) t.stops in
  match words, q.state with
  | [ "b"; s ], _ ->
      let a = addr s in
      if not (List.exists (fun (b, _) -> b = a) t.stops) then (t.stops <- t.stops @ [ a, peek (q.base + a) ]; poke (q.base + a) 0);
      say "ok"
  | [ "d"; s ], _ -> unset (addr s); say "ok"
  | [ "r" ], _ -> say (String.concat " " (List.init 16 (fun k -> (if k = 15 then "pc" else "r" ^ string_of_int (k + 1)) ^ " " ^ string_of_int (reg q (k + 1)))))
  | [ "c" ], Stopped -> unset (reg q 16); q.state <- Ready
  | _ -> raise Bad

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
          let at = min o.off d.dsize in
          if at + n > Bytes.length d.dbytes then begin
            let b = Bytes.make (max (at + n) (2 * Bytes.length d.dbytes)) ' ' in
            Bytes.blit d.dbytes 0 b 0 d.dsize;
            d.dbytes <- b
          end;
          Bytes.blit_string (k_string a n) 0 d.dbytes at n;
          d.dsize <- max d.dsize (at + n);
          o.off <- at + n;
          Some n
      | Disk (0, i) when o.writes -> (try fs_write_at i o.off a n; o.off <- o.off + n; Some n with Disk_full -> Some (-1))
      | _ -> Some (-1))
  (* messages, whole; a bad one is said on the console, the write -1 *)
  | Draw d -> (try messages d.conn (k_string a n); Some n with Graphics why -> puts ("draw: " ^ why ^ "\n"); Some (-1))
  | Post b -> b.last <- k_string a n; b.fresh <- true; Some n
  (* sounds, whole, when they fit in the ring (else a look again in 10
   * ms); a bad one, or more than a ring, -1 *)
  | Voice v ->
      (match (try Some (sounds (k_string a n)) with Bad_sound -> None) with
       | Some l when List.fold_left (fun acc snd -> acc + sound_length snd) 0 l <= ring ->
           if speak v l then Some n else (if !alarm = 0 || !ticks + 4 < !alarm then alarm := !ticks + 4; None)
       | _ -> Some (-1))
  (* a command to the traced process, each answered by a line but c,
   * which its next stop answers *)
  | Trace t -> (match traced_proc t with Some q -> (try command t q (String.split_on_char ' ' (String.trim (k_string a n))); Some n with Bad -> Some (-1)) | None -> Some (-1))
  | Reader _ | Peek _ -> Some (-1)

(* whether a read would not wait *)
let readable f =
  match f with
  | Console -> !typed <> "" || !typed_end
  | Reader pi -> pi.buf <> "" || pi.writers = 0
  | Peek b -> b.fresh || b.posters = 0
  | Link l -> (match l.heard with [] -> false | _ -> true)
  | Call c -> il_readable c.il
  | Trace t -> t.said <> [] || (match traced_proc t with Some _ -> false | None -> true)
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

(* its descriptors closed, its children orphans (their zombies freed),
 * the processes it traces let go, its end said to its tracer;
 * its status for its parent, or its slot free. The first process's
 * end is the machine's *)
let rec exit_proc p status =
  incr deaths;
  List.iter (fun (_, f) -> drop f) p.fds;
  p.fds <- [];
  List.iter (fun q -> match q.traced with Some t when t.tracer = p.pid -> detach t | _ -> ()) !procs;
  (match p.traced with Some t -> t.said <- t.said @ [ "exited " ^ string_of_int status ^ "\n" ] | None -> ());
  List.iter (fun q ->
    if q.parent = p.pid then begin
      q.parent <- 0;
      match q.state with Zombie _ -> release q | _ -> ()
    end) !procs;
  if p.pid = 1 then halt status;
  if p.parent = 0 then release p else p.state <- Zombie status

and release q = procs := List.filter (fun r -> r.pid <> q.pid) !procs

(* fork: a new slot and a partition of the parent's size, the partition
 * and the frame copied (the child's r1 0), the descriptors shared; the
 * child is not traced, so the words under its parent's breakpoints are
 * put back in its copy *)
let sys_fork p =
  let s = free_slot () in
  let b = room p.size (-1) in
  let q = { slot = s; base = b; size = p.size; pid = !next_pid; state = Ready; parent = p.pid; fds = p.fds; cwd = p.cwd; since = -1; traced = None } in
  incr next_pid;
  k_copy b p.base p.size;
  k_copy (frame s) (frame p.slot) 68;
  (match p.traced with Some t -> List.iter (fun (a, w) -> poke (b + a) w) t.stops | None -> ());
  List.iter (fun (_, f) -> share f) p.fds;
  procs := !procs @ [ q ];
  set_reg q 1 0;
  result p q.pid

(* A program's file is either a raw image, run in 1 MB, or an a.out: a
 * header of three words (a magic number, the image's size, the memory
 * the program asks for), then the image (tiny-linker -a). This returns
 * where the image starts in the file, its size, and the memory. *)
let aout_magic = 0x7a0ce5
let header bytes =
  let word i = Char.code bytes.[i] + (Char.code bytes.[i + 1] lsl 8) + (Char.code bytes.[i + 2] lsl 16) + (Char.code bytes.[i + 3] lsl 24) in
  if String.length bytes >= 12 && word 0 = aout_magic then Some (word 4, word 8) else None

(* Loads a file's program into p, in a partition of the size it asks for
 * (rounded up to whole megabytes), from address 0. Its arguments are put
 * as tiny-cpu leaves them (the strings at the top, then argc, argv and
 * argv's pointers: start.tm's); every register is 0 but sp. Bad if it is
 * no program, or one that leaves no room for a stack, or if there is no
 * room for its partition; in that case p is left as it was. *)
let load_prog p node argv =
  let node = match node with Some (Disk (r, i)) -> Some (Data (data (fs_contents r i))) | _ -> node in
  let n = match node with Some (Data d) -> d.dsize | Some (Rom (_, n)) -> n | _ -> raise Bad in
  let first = match node with Some (Data d) -> Bytes.sub_string d.dbytes 0 (min n 12) | Some (Rom (at, _)) -> k_string at (min n 12) | _ -> "" in
  let skip, size, memory = match header first with
    | Some (size, memory) when size = n - 12 -> 12, size, (memory + part - 1) / part * part
    | _ -> 0, n, part in
  if size > memory - 0x10000 || memory > mem_high - mem_low then raise Bad;
  let b = if memory = p.size then p.base else room memory p.pid in
  p.base <- b;
  p.size <- memory;
  k_zero b memory;
  (match node with Some (Data d) -> k_blit (Bytes.sub_string d.dbytes skip size) 0 b size | Some (Rom (at, _)) -> row_copy b (at + skip) size | _ -> ());
  let top = ref memory and ptrs = ref [] in
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
 * all read before the partition is changed, so a failed exec returns.
 * A traced process stops at its new program's first instruction, its
 * breakpoints gone with the old one *)
let sys_exec p =
  let node = walk !top (names p.cwd (ustr p (reg p 1))) in
  let rec args i acc =
    if i >= 16 then raise Bad
    else let a = peek (user p (reg p 2 + (4 * i)) 4) in if a = 0 then List.rev acc else args (i + 1) (ustr p a :: acc) in
  load_prog p node (args 0 []);
  match p.traced with Some t -> t.stops <- []; stop p "exec" | None -> ()

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
    match walk !top ns, dir_of ns with
    | Some n, _ -> n
    | None, Some (Dir d, last) when mode land o_create <> 0 && String.length last < 20 ->
        let n = Data (data "") in d := !d @ [ last, n ]; n
    | None, Some (Disk (0, i), last) when mode land o_create <> 0 && String.length last < 20 -> Disk (0, fs_create i last 2)
    | _ -> raise Bad in
  (* (a file of the image opened to be written is in memory from now on;
   * or a file of the disk, when its directory is there too: /bin's) *)
  let node =
    match node, dir_of ns with
    | Rom (at, n), Some (Disk (0, i), last) when writes ->
        let j = fs_create i last 2 in
        if mode land o_trunc = 0 then fs_write_at j 0 at n;
        Disk (0, j)
    | Rom (at, n), Some (Dir d, last) when writes ->
        let made = Data (data (if mode land o_trunc <> 0 then "" else k_string at n)) in
        d := List.map (fun (name, old) -> if name = last then name, made else name, old) !d;
        made
    | _ -> node in
  (* (a snapshot is read only) *)
  (match node with
   | Dir _ when writes -> raise Bad
   | Disk (r, i) when writes && (r <> 0 || fs_is_dir r i) -> raise Bad
   | Data d when mode land o_trunc <> 0 -> d.dbytes <- Bytes.make 0 ' '; d.dsize <- 0
   | Disk (_, i) when writes && mode land o_trunc <> 0 -> fs_truncate i
   | _ -> ());
  result p (fdalloc p (match node with
    | Tty -> Console
    | Screen -> Draw { conn = connect screen font; refs = 1 }
    | Pointer -> Peek mouse
    | Speaker -> Voice { ahead = (played () + lead) land 0x3fffffff }
    | _ -> Open { node = node; off = 0; writes = writes }))

let sys_close p =
  let k = reg p 1 in
  drop (fd p k);
  p.fds <- List.filter (fun (j, _) -> j <> k) p.fds;
  result p 0

(* pipe(fds) and box(fds): the two ends, a descriptor each, put in fds *)
let ends p r w =
  let a = user p (reg p 1) 8 in
  let r = fdalloc p r in
  let w = fdalloc p w in
  poke a r;
  poke (a + 4) w;
  result p 0

let sys_pipe p = let pi = { buf = ""; readers = 1; writers = 1 } in ends p (Reader pi) (Writer pi)

(* a box, its reading end and its writing end *)
let sys_box p = let b = { last = ""; fresh = false; posters = 1 } in ends p (Peek b) (Post b)

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
  match walk !top ns, dir_of ns with
  | None, Some (Dir d, last) when String.length last < 20 -> d := !d @ [ last, Dir (ref []) ]; result p 0
  | None, Some (Disk (0, i), last) when String.length last < 20 -> ignore (fs_create i last 1); result p 0
  | _ -> raise Bad

(* a name removed; a directory only if empty *)
let sys_unlink p =
  match dir_of (names p.cwd (ustr p (reg p 1))) with
  | Some (Dir d, last) ->
      (match List.assoc_opt last !d with
       | Some (Dir e) when !e <> [] -> raise Bad
       | Some (Disk _) -> raise Bad
       | Some _ -> d := List.filter (fun (n, _) -> n <> last) !d; result p 0
       | None -> raise Bad)
  | Some (Disk (0, i), last) ->
      (match fs_lookup 0 i last with
       | 0 -> raise Bad
       | j when fs_is_dir 0 j && fs_entries 0 j <> [] -> raise Bad
       | _ -> fs_unlink i last; result p 0)
  | _ -> raise Bad

(* link(old, new): a second name for a file, in the directory new is in:
 * the same node, so a write by either name is seen by the other (a file
 * of the image, Rom, is copied when it is first written, under the name
 * it is written by: then the names part). Not for a directory, as on
 * Unix: a directory with two parents would make the tree a graph *)
let sys_link p =
  let old = walk !top (names p.cwd (ustr p (reg p 1))) and ns = names p.cwd (ustr p (reg p 2)) in
  match old, walk !top ns, dir_of ns with
  | Some n, _, _ when is_dir n -> raise Bad
  | Some (Disk (0, j)), None, Some (Disk (0, i), last) when String.length last < 20 -> fs_link i last j; result p 0
  | Some (Disk _), _, _ -> raise Bad
  | Some node, None, Some (Dir d, last) when String.length last < 20 -> d := !d @ [ last, node ]; result p 0
  | _ -> raise Bad

(* getcwd(buf, n): the current directory's path, ended by a 0, in the n
 * bytes at buf; its length, -1 when it does not fit *)
let sys_getcwd p =
  let path = if p.cwd = [] then "/" else List.fold_left (fun acc n -> acc ^ "/" ^ n) "" p.cwd in
  let n = String.length path in
  let a = user p (reg p 1) (reg p 2) in
  if n + 1 > reg p 2 then raise Bad;
  for i = 0 to n - 1 do pokeb (a + i) (Char.code path.[i]) done;
  pokeb (a + n) 0;
  result p n

(* rawcons(on): the console raw for this process, while it lives (on
 * 1), or not (on 0). An editor's C-x C-c: ^C a key like the others.
 * Plan 9's rawon, written to /dev/consctl (which also stops the echo
 * and the line editing: tiny-kernel's console has neither) *)
let sys_rawcons p = raw := (if reg p 1 <> 0 then p.pid else 0); result p 0

(* kill(pid): its process ended as a fault ends one, its status -1 *)
let kill q = match q.state with Zombie _ -> () | _ -> exit_proc q (-1)
let sys_kill p =
  match List.filter (fun q -> q.pid = reg p 1) !procs with [ q ] -> kill q; result p 0 | _ -> raise Bad

(* trace(pid): a descriptor on a process, for its tracer (debug): what is
 * written to it a command, what is read the answers and the process's
 * stops (command, stop). trace(0): the caller traced by its parent from
 * now on, so that it stops at its next exec, the way a debugger starts
 * a program; the parent's trace(pid) gives the descriptor, before or
 * after. Not for the first process, the caller itself, or a process
 * another one traces *)
let sys_trace p =
  let make q tracer = let t = { tpid = q.pid; tracer = tracer; stops = []; said = []; watchers = 0 } in q.traced <- Some t; t in
  if reg p 1 = 0 then begin
    (match p.traced with
     | Some t -> if t.tracer <> p.parent then raise Bad
     | None -> if p.parent = 0 then raise Bad else ignore (make p p.parent));
    result p 0
  end
  else
    match List.filter (fun q -> q.pid = reg p 1 && q.pid <> p.pid && q.pid <> 1) !procs with
    | [ q ] ->
        (match q.state with Zombie _ -> raise Bad | _ -> ());
        let t = match q.traced with Some t when t.tracer = p.pid -> t | None -> make q p.pid | _ -> raise Bad in
        let k = fdalloc p (Trace t) in
        t.watchers <- t.watchers + 1;
        result p k
    | _ -> raise Bad

(* seek(fd, n, whence): a file's offset at n from its start (0), from
 * where it is (1) or from its end (2), as Plan 9's; the new offset *)
let sys_seek p =
  match fd p (reg p 1) with
  | Open o ->
      let size = match o.node with Rom (_, n) -> n | Data d -> d.dsize | Disk (r, i) -> let _, n, _ = fs_kind r i in n | n -> String.length (contents n) in
      let off = reg p 2 + (match reg p 3 with 0 -> 0 | 1 -> o.off | 2 -> size | _ -> raise Bad) in
      if off < 0 then raise Bad;
      o.off <- off;
      result p off
  | _ -> raise Bad

let sys_chdir p =
  let ns = names p.cwd (ustr p (reg p 1)) in
  match walk !top ns with Some n when is_dir n -> p.cwd <- ns; result p 0 | _ -> raise Bad

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
 * tiny-cpu's own (libc's). A call that changed the disk is committed
 * when it ends, but a write: a file's writes are committed by the next
 * call that is not one, its close at the latest (TinyKernelFS.mli) *)
let syscall p =
  let n = k_tval () in
  (try
    match n with
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
    | 20 -> sys_getcwd p
    | 21 -> sys_link p
    | 22 -> sys_rawcons p
    | 23 -> sys_trace p
    | 24 -> sys_seek p
    | _ -> result p (-1)
  with Bad -> result p (-1) | Disk_full -> result p (-1));
  if n <> 1 then fs_commit ()

(*****************************************************************************)
(* The scheduler: round robin, preemptive *)
(*****************************************************************************)

(* the interrupts' sources: the timer re-armed (its time is up) and
 * counted, the console's bytes taken, ^C (3) killing the foreground,
 * every process but the shell (the first: no background here), the
 * mouse's word read, the network's packets taken, each given to
 * TinyKernelNetwork.ml (what it says to send back sent, an echo's answer
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
    net_command n 2;
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
      else if c = 3 && not (raw_on ()) then
        (typed := ""; List.iter (fun q -> if q.pid <> 1 then kill q) !procs; puts "\n"; take ())
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
       | Zombie _ -> runnable rest
       | Stopped -> runnable rest)

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
  k_window p.base p.size;
  let cause = k_run (frame p.slot) in
  let timer =
    if cause = c_sys then (syscall p; false)
    else if cause = c_intr then interrupts (k_tval ())
    else if cause = c_illegal && traced p then (stop p (if k_tval () = 0 then "break" else "illegal " ^ string_of_int (k_tval ())); false)
    else if cause = c_fault && traced p then (stop p ("fault " ^ string_of_int (k_tval ())); false)
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
  (match root with Dir d -> d := !d @ [ "dev", Dir (ref [ "console", Tty; "draw", Screen; "mouse", Pointer; "audio", Speaker ]) ] | _ -> ());
  k_zero ring_at ring;
  poke speaker_dev ring_at;
  puts ("tiny-kernel: TinyKernel.ml, " ^ string_of_int ((mem_high - mem_low) / part) ^ " MB for " ^ string_of_int nslots ^ " processes\n");
  (* The disk, when there is one, is the root: the top becomes a union
   * of the disk's root, of /boot and /dump, and of the image's files.
   * Its snapshots are in /dump, each under the number of the boot that
   * left it. Its /bin and /usr/glenda are made at its first boot, and the
   * first shell starts in /usr/glenda. *)
  let blocks = peek disk_dev in
  if blocks > 0 then begin
    fs_io := (fun b a cmd -> poke disk_dev b; poke (disk_dev + 4) a; poke (disk_dev + 8) cmd; poke (disk_dev + 12) 0);
    fs_mount blocks;
    let made d name = match fs_lookup 0 d name with 0 -> fs_create d name 1 | j -> j in
    ignore (made 1 "bin");
    ignore (made (made 1 "usr") "glenda");
    fs_commit ();
    let dumps = List.map (fun (r, boot) -> string_of_int boot, Disk (r, 1)) (fs_snapshots ()) in
    top := Union [ Disk (0, 1); Dir (ref [ "boot", root; "dump", Dir (ref dumps) ]); root ];
    puts ("tiny-kernel: / on a disk of " ^ string_of_int blocks ^ " KB, " ^ string_of_int (fs_free ()) ^ " KB free; "
          ^ string_of_int (List.length dumps) ^ " snapshots in /dump\n")
  end;
  (* the first process: /bin/sh, the console its 0, 1 and 2; and for the
   * programs it runs, which inherit them, the screen its 3 (a
   * connection) and the mouse its 4: a window system gives a window's
   * programs the same five, so a program draws in what it was given
   * and does not ask where *)
  let fds = [ 0, Console; 1, Console; 2, Console; 3, Draw { conn = connect screen font; refs = 1 }; 4, Peek mouse ] in
  let p = { slot = 0; base = mem_low; size = 0; pid = 1; state = Ready; parent = 0; fds = fds; cwd = (if blocks > 0 then [ "usr"; "glenda" ] else []); since = -1; traced = None } in
  incr next_pid;
  procs := [ p ];
  (try load_prog p (walk !top [ "bin"; "sh" ]) [ "sh" ] with Bad -> puts "no /bin/sh\n"; halt 1);
  schedule ()
