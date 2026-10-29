(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyKernelProcs.mli *)
open TinyMemory
open TinyKernelGraphics
open TinyKernelNetwork
open TinyKernelMemory
open TinyKernelMachine
open TinyKernelFiles

(*****************************************************************************)
(* Processes *)
(*****************************************************************************)

(* ready to run; waiting, the rest of its system call (true when it
 * could finish); stopped for its tracer, until the tracer resumes it *)
type state = Ready | Waiting of (unit -> bool) | Stopped

(* A process: its slot (where its frame is), its memory, its pid, its
 * state, its parent's pid (0: none), its
 * descriptors, its current directory; while it waits for a child's
 * end, how many processes had ended when it last looked (-1: it waits
 * for something else); and its trace, when it is traced. The core it
 * runs on (-1: none; 0 while core 0 runs it or handles its trap), and
 * whether it was killed there, its end then at its next trap. Its
 * command line and its memory, for /dev/ps: its program's (exec's
 * arguments, the bytes it asked for), or its parent's when it was
 * forked. *)
type proc = {
  slot : int; mem : space; pid : int;
  mutable state : state; mutable parent : int;
  mutable fds : (int * file) list; mutable cwd : string list;
  mutable since : int; mutable traced : trace option;
  mutable core : int; mutable doomed : bool;
  mutable cmd : string; mutable memory : int;
}

(* the processes, in the order the scheduler goes through them; how
 * many have ended *)
let procs = ref []
let next_pid = ref 1
let deaths = ref 0

(* the children ended, not waited for: parent, pid, status *)
let ended = ref []

(* /dev/ps: a line a process, in the scheduler's order; running is on a
 * core now (the reader itself, on core 0 for its call) *)
let () =
  ps_hook := (fun () ->
    String.concat "" (List.map (fun p ->
      let state = match p.state with
        | Ready when p.core >= 0 -> "running"
        | Ready -> "ready"
        | Waiting _ -> "waiting"
        | Stopped -> "stopped" in
      string_of_int p.pid ^ " " ^ string_of_int p.parent ^ " " ^ state ^ " "
      ^ string_of_int (p.memory / 1024) ^ " " ^ p.cmd ^ "\n") !procs))

(* a register of its frame (r1..r15, the pc as 16), as entry.tm saved it *)
let reg p k = peek (frame p.slot + (4 * k))
let set_reg p k v = poke (frame p.slot + (4 * k)) v

(* a user's address, n bytes long, as the kernel reaches it; Bad if it
 * leaves the partition *)
exception Bad
let user p va n =
  let a = mem_address p.mem va n in
  if a < 0 then raise Bad else a

(* the same, n bytes the kernel writes for the user (a read's, a call's
 * result): Bad in its text too, read only with segments *)
let user_out p va n =
  if mem_writable p.mem va n then user p va n else raise Bad

(* A user's buffer, n bytes at va, piece by piece: f a off k for each
 * piece, at the kernel's address a, off bytes into the buffer, k bytes
 * long; Bad if it leaves the process's memory. A partition gives one
 * piece; pages would give one a page, not together in the machine
 * (TinyKernelMemory.mli) *)
let user_iter p va n f =
  match mem_pieces p.mem va n with
  | Some l -> ignore (List.fold_left (fun off (a, k) -> f a off k; off + k) 0 l)
  | None -> raise Bad

(* a string of the kernel's written in the user's memory at va *)
let user_write p va s =
  if not (mem_writable p.mem va (String.length s)) then raise Bad;
  user_iter p va (String.length s) (fun a off k -> k_blit s off a k)

(* a string of the user's, a path: 1024 bytes at most (old: 64, a path
 * of a few names, when a name had 20) *)
let ustr p va =
  let b = Buffer.create 64 in
  let rec go i =
    if i >= 1024 then raise Bad
    else
      let c = peekb (user p (va + i) 1) in
      if c = 0 then Buffer.contents b
      else (Buffer.add_char b (Char.chr c); go (i + 1)) in
  go 0

(* a slot: none free now is No_room, as for a partition (with_room,
 * below, waits for one) *)
let free_slot () =
  let rec go s =
    if s >= nslots then raise No_room
    else if List.exists (fun p -> p.slot = s) !procs then go (s + 1)
    else s in
  go 0

(* a descriptor's file; the lowest free descriptor (32 a process: a
 * window system has four a window), given f *)
let fd p k =
  match List.assoc_opt k p.fds with Some f -> f | None -> raise Bad
let fdalloc p f =
  let rec go k =
    if k >= 32 then raise Bad
    else if List.exists (fun (j, _) -> j = k) p.fds then go (k + 1)
    else k in
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
  | [ q ] -> Some q
  | _ -> None

(* the trace ended (its tracer's last descriptor closed, or the tracer
 * ended): the words under the breakpoints put back, the process run
 * again if it was stopped; one stopped before a call goes back to its
 * sys, to make the call (its registers are as they were) *)
let detach t =
  match traced_proc t with
  | Some q ->
      List.iter (fun (a, w) -> mem_store q.mem a w) t.stops;
      if t.call >= 0 then set_reg q 16 (reg q 16 - 4);
      t.stops <- [];
      q.traced <- None;
      (match q.state with Stopped -> q.state <- Ready | _ -> ())
  | None -> ()

let drop f =
  match f with
  | Trace t -> t.watchers <- t.watchers - 1; if t.watchers = 0 then detach t
  | Link l ->
      l.holders <- l.holders - 1;
      if l.holders = 0 then
        links := List.filter (fun m -> m.lid <> l.lid) !links
  | Call c -> c.callers <- c.callers - 1; if c.callers = 0 then il_done c.il
  | Reader pi -> pi.readers <- pi.readers - 1
  | Writer pi -> pi.writers <- pi.writers - 1
  | Draw d -> d.refs <- d.refs - 1; if d.refs = 0 then disconnect d.conn
  | Post b -> b.posters <- b.posters - 1
  | _ -> ()
