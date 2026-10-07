(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Channel.mli *)

type shared = {
  contract : Contract.t;
  mutable state : int;
}

type endpoint = {
  side : Contract.side;
  channel : shared;
  mutable peer : endpoint option;
  queue : message Queue.t;
  mutable owner : int;
  mutable waiter : int;
}

and carried =
  | Nothing
  | Block of Exchange.block
  | Endpoint of endpoint

and message = {
  tag : int;
  value : int;
  carried : carried;
}

let wake : (int -> unit) ref = ref (fun (_ : int) -> ())

let create (contract : Contract.t) (owner : int) : endpoint * endpoint =
  let channel = { contract; state = 0 } in
  let imp = { side = Imp; channel; peer = None; queue = Queue.create (); owner; waiter = -1 } in
  let exp = { side = Exp; channel; peer = Some imp; queue = Queue.create (); owner; waiter = -1 } in
  imp.peer <- Some exp;
  (imp, exp)

let woken (e : endpoint) : unit =
  if e.waiter >= 0 then begin
    let w = e.waiter in
    e.waiter <- -1;
    !wake w
  end

type sent =
  | Sent
  | Closed_
  | Refused of string

(* the state after the message, or why the contract refuses it *)
let allowed (e : endpoint) (m : message) : (int, string) result =
  let c = e.channel.contract in
  if m.tag < 0 || m.tag >= Array.length c.messages then Error (Printf.sprintf "%s has no message %d" c.name m.tag)
  else begin
    let d = c.messages.(m.tag) in
    let what = c.name ^ "." ^ d.label in
    if d.from <> e.side then Error (what ^ " is the other end's to send")
    else
      match List.assoc_opt m.tag c.states.(e.channel.state) with
      | None -> Error (Printf.sprintf "%s is not allowed in state %d" what e.channel.state)
      | Some next -> (
          match d.carries, m.carried with
          | Nothing, Nothing | Block, Block _ -> Ok next
          | Endpoint (name, side), Endpoint x ->
              if x.channel.contract.name = name && x.side = side && x != e then Ok next
              else Error (what ^ " carries another endpoint than this one")
          | _ -> Error (what ^ " does not carry that"))
  end

let send (e : endpoint) (m : message) : sent =
  match e.peer with
  | None -> Closed_
  | Some other -> (
      match allowed e m with
      | Error why -> Refused why
      | Ok next ->
          e.channel.state <- next;
          (match m.carried with
           | Block b -> b.owner <- Exchange.in_message
           | Endpoint x -> x.owner <- Exchange.in_message
           | Nothing -> ());
          Queue.add m other.queue;
          woken other;
          Sent)

type received =
  | Message of message
  | Empty
  | Closed

let receive (e : endpoint) : received =
  if not (Queue.is_empty e.queue) then Message (Queue.take e.queue)
  else match e.peer with None -> Closed | Some _ -> Empty

let ready (e : endpoint) : bool =
  not (Queue.is_empty e.queue) || (match e.peer with None -> true | Some _ -> false)

let rec close (e : endpoint) : unit =
  (match e.peer with
   | Some other -> other.peer <- None; woken other
   | None -> ());
  e.peer <- None;
  (* (the queue emptied first: an endpoint in it may be this one's peer's) *)
  let left = ref [] in
  Queue.iter (fun (m : message) -> left := m :: !left) e.queue;
  Queue.clear e.queue;
  List.iter (fun (m : message) ->
    match m.carried with
    | Block b -> Exchange.free b
    | Endpoint x -> close x
    | Nothing -> ()) !left
