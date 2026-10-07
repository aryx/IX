(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Process.mli *)

(* the image's programs (cross.c): a pristine copy's physical address
 * and bytes, the physical address it is linked at; the bytes it may
 * take there, and those it takes with its bss *)
external image_base : int -> int = "sip_image_base"
external image_size : int -> int = "sip_image_size"
external image_addr : int -> int = "sip_image_addr"
external image_slot : int -> int = "sip_image_slot"
external image_extent : int -> int = "sip_image_extent"
(* into the code at a physical address, on a stack whose top is at
 * another; back when the process has ended *)
external enter : int -> int -> unit = "sip_run"
external leave : unit -> unit = "sip_exit"

type state =
  | Created
  | Ready
  | Running
  | Waiting                     (* for another's end, or a message: woken, it looks again *)
  | Ended of int

type held =
  | Nothing
  | Child of int
  | Endpoint of Channel.endpoint
  | Block of Exchange.block

type t = {
  id : int;                     (* its slot, machine/runtime.c's *)
  program : int;
  parent : int;                 (* -1: none (the kernel's, or its parent ended) *)
  mutable state : state;
  handles : held array;
}

(* machine/runtime.c's NPROC; its slot of the boot's stack, the scheduler's *)
let nproc = 64
let scheduler = nproc
let nhandles = 16
(* the least a program's stack is given, after its bss *)
let min_stack = 1024 * 1024

let procs : t option array = Array.make nproc None

let get (id : int) : t = match procs.(id) with Some p -> p | None -> failwith "Process.get: no such process"
let current () : t = get (Machine.current ())

let index (f : int -> bool) (n : int) : int =
  let rec go i = if i = n then -1 else if f i then i else go (i + 1) in
  go 0

let free (p : t) : unit = procs.(p.id) <- None; Machine.proc_free p.id

let held (p : t) (h : int) : held = if h < 0 || h >= nhandles then Nothing else p.handles.(h)
let drop_in (p : t) (h : int) : unit = p.handles.(h) <- Nothing
let hold_in (p : t) (x : held) : int =
  let h = index (fun i -> match p.handles.(i) with Nothing -> true | _ -> false) nhandles in
  if h >= 0 then p.handles.(h) <- x;
  h

let create (by_process : bool) (name : string) : int =
  let program = index (fun i -> Programs.names.(i) = name) (Array.length Programs.names) in
  let id = index (fun i -> procs.(i) = None) nproc in
  let busy = index (fun i -> match procs.(i) with Some p -> p.program = program | None -> false) nproc >= 0 in
  if program < 0 || busy || id < 0 then -1
  else if not by_process then begin
    procs.(id) <- Some { id; program; parent = -1; state = Created; handles = Array.make nhandles Nothing };
    id
  end
  else begin
    let parent = current () in
    let h = hold_in parent (Child id) in
    if h >= 0 then procs.(id) <- Some { id; program; parent = parent.id; state = Created; handles = Array.make nhandles Nothing };
    h
  end

(* a handle's process, or -1 *)
let of_handle (p : t) (h : int) : int = match held p h with Child id -> id | _ -> -1

let start (by_process : bool) (h : int) : int =
  let id = if by_process then of_handle (current ()) h else h in
  if id < 0 then -2
  else begin
    let p = get id in
    if p.state = Created then begin Machine.proc_context id; p.state <- Ready end;
    0
  end

let sched () : unit = Machine.swtch scheduler

let yield () : unit = (current ()).state <- Ready; sched ()

let wait () : unit = (current ()).state <- Waiting; sched ()
let wake (id : int) : unit =
  match procs.(id) with
  | Some p -> if p.state = Waiting then p.state <- Ready
  | None -> ()
let () = Channel.wake := wake

let running () : int = Machine.current ()
let name () : string = Programs.names.((current ()).program)
let handle (h : int) : held = held (current ()) h
let hold (x : held) : int = hold_in (current ()) x
let drop (h : int) : unit = drop_in (current ()) h

let give (h : int) (e : int) : int =
  let p = current () in
  match held p h, held p e with
  | Child id, Endpoint ep ->
      let child = get id in
      if child.state <> Created then -1
      else begin
        let there = hold_in child (Endpoint ep) in
        if there >= 0 then begin ep.owner <- id; drop_in p e end;
        there
      end
  | _ -> -2

let rec join (h : int) : int =
  let p = current () in
  let id = of_handle p h in
  if id < 0 then -2
  else begin
    let child = get id in
    match child.state with
    | Ended status -> free child; drop_in p h; status
    | _ -> wait (); join h
  end

let exit (status : int) : unit =
  let p = current () in
  p.state <- Ended (status land 255);
  (* what it held: its channels closed, its blocks freed *)
  Array.iter (fun (x : held) ->
    match x with
    | Endpoint e -> Channel.close e
    | Block b -> Exchange.free b
    | _ -> ()) p.handles;
  if p.parent >= 0 then wake p.parent;
  Array.iter (fun (o : t option) ->
    match o with
    (* its children: nobody will wait for them *)
    | Some q when q.parent = p.id -> (match q.state with Ended _ -> free q | _ -> procs.(q.id) <- Some { q with parent = -1 })
    | _ -> ()) procs;
  leave ()

(* A process's first run, on its kernel stack (machine/runtime.c's
 * "process_start"): its program's copy at its address, entered; back
 * here when it has ended, and never run again. *)
let first_run (_ : int) : unit =
  let p = current () in
  let i = p.program in
  let addr = image_addr i in
  if image_extent i + min_stack > image_slot i then
    Machine.panic (Printf.sprintf "%s takes %d bytes, too many for its slot" Programs.names.(i) (image_extent i));
  Machine.Phys.copy addr (image_base i) (image_size i);
  (* code was written: the Pi 4's flushes the instruction cache with
   * the user's table, which stays the empty one *)
  Machine.mmu_switch 0;
  enter addr (addr + image_slot i - 16);
  sched ()

let () = Callback.register "process_start" first_run

let schedule () : unit =
  let last = ref (nproc - 1) in
  let rec loop () =
    let next = index (fun k -> match procs.((!last + 1 + k) mod nproc) with Some p -> p.state = Ready | None -> false) nproc in
    if next >= 0 then begin
      let p = get ((!last + 1 + next) mod nproc) in
      last := p.id;
      p.state <- Running;
      Machine.swtch p.id;
      (* it has switched back: its kernel stack is no longer run if it ended *)
      let p = get p.id in
      (match p.state with
       | Ended status when p.parent < 0 ->
           Machine.print (Printf.sprintf "mini-singularity: %s ended, status %d.\n" Programs.names.(p.program) status);
           free p
       | _ -> ());
      loop ()
    end
  in
  loop ();
  let waiting = ref 0 in
  Array.iter (fun (o : t option) -> match o with Some _ -> incr waiting | None -> ()) procs;
  if !waiting > 0 then Machine.print (Printf.sprintf "mini-singularity: %d processes wait for ever.\n" !waiting)
