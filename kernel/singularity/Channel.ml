(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Channel.mli *)

type message = {
  tag : int;
  value : int;
  block : Exchange.block option;
}

type endpoint = {
  mutable peer : endpoint option;
  queue : message Queue.t;
  mutable owner : int;
  mutable waiter : int;
}

let wake : (int -> unit) ref = ref (fun (_ : int) -> ())

let create (owner : int) : endpoint * endpoint =
  let a = { peer = None; queue = Queue.create (); owner; waiter = -1 } in
  let b = { peer = Some a; queue = Queue.create (); owner; waiter = -1 } in
  a.peer <- Some b;
  (a, b)

let woken (e : endpoint) : unit =
  if e.waiter >= 0 then begin
    let w = e.waiter in
    e.waiter <- -1;
    !wake w
  end

let send (e : endpoint) (m : message) : bool =
  match e.peer with
  | None -> false
  | Some other ->
      (match m.block with Some b -> b.owner <- Exchange.in_message | None -> ());
      Queue.add m other.queue;
      woken other;
      true

type received =
  | Message of message
  | Empty
  | Closed

let receive (e : endpoint) : received =
  if not (Queue.is_empty e.queue) then Message (Queue.take e.queue)
  else match e.peer with None -> Closed | Some _ -> Empty

let ready (e : endpoint) : bool =
  not (Queue.is_empty e.queue) || (match e.peer with None -> true | Some _ -> false)

let close (e : endpoint) : unit =
  (match e.peer with
   | Some other -> other.peer <- None; woken other
   | None -> ());
  e.peer <- None;
  Queue.iter (fun (m : message) -> match m.block with Some b -> Exchange.free b | None -> ()) e.queue;
  Queue.clear e.queue
