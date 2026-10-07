(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Abi.mli *)

(* the call's word i, read and set; n bytes at the address its word i
 * is: a new string of them, or copied into bytes at an offset, or from
 * them (cross.c) *)
external arg : int -> int = "abi_arg"
external set : int -> int -> unit = "abi_set"
external bytes : int -> int -> string = "abi_bytes"
external get : int -> Bytes.t -> int -> int -> unit = "abi_get"
external put : int -> Bytes.t -> int -> int -> unit = "abi_put"

(* a name's bytes, at most; a select's endpoints *)
let max_name = 64
let max_select = 3

let refused = -1
let not_held = -2

let endpoint (h : int) : Channel.endpoint option = match Process.handle h with Endpoint e -> Some e | _ -> None
let block (h : int) : Exchange.block option = match Process.handle h with Block b -> Some b | _ -> None

let channel () : int =
  let a, b = Channel.create (Process.running ()) in
  let ha = Process.hold (Endpoint a) in
  let hb = if ha >= 0 then Process.hold (Endpoint b) else -1 in
  if hb < 0 then begin (if ha >= 0 then Process.drop ha); refused end
  else begin set 1 hb; ha end

let send (h : int) (tag : int) (value : int) (hb : int) : int =
  match endpoint h, (if hb < 0 then None else block hb) with
  | None, _ -> not_held
  | Some _, None when hb >= 0 -> not_held
  | Some e, b ->
      if tag < 0 then refused
      else if Channel.send e { tag; value; block = b } then begin (if hb >= 0 then Process.drop hb); 0 end
      else refused

let rec receive (h : int) : int =
  match endpoint h with
  | None -> not_held
  | Some e -> (
      match Channel.receive e with
      | Message m ->
          set 1 m.value;
          set 2 (match m.block with
                 | None -> -1
                 | Some b ->
                     let hb = Process.hold (Block b) in
                     if hb >= 0 then b.owner <- Process.running () else Exchange.free b;
                     hb);
          m.tag
      | Closed -> refused
      | Empty -> e.waiter <- Process.running (); Process.wait (); receive h)

let rec select (n : int) : int =
  if n < 1 || n > max_select then refused
  else begin
    let ends = List.init n (fun i -> endpoint (arg (2 + i))) in
    if List.mem None ends then not_held
    else begin
      let ends = List.filter_map (fun e -> e) ends in
      let rec first (i : int) (l : Channel.endpoint list) : int =
        match l with [] -> -1 | e :: rest -> if Channel.ready e then i else first (i + 1) rest in
      let i = first 0 ends in
      if i >= 0 then i
      else begin
        List.iter (fun (e : Channel.endpoint) -> e.waiter <- Process.running ()) ends;
        Process.wait ();
        select n
      end
    end
  end

let close (h : int) : int =
  match endpoint h with
  | None -> not_held
  | Some e -> Channel.close e; Process.drop h; 0

let alloc (n : int) : int =
  match Exchange.alloc (Process.running ()) n with
  | None -> refused
  | Some b ->
      let h = Process.hold (Block b) in
      if h < 0 then Exchange.free b;
      h

(* the block's bytes from an offset, copied to the caller's memory or from it *)
let copy (out : bool) (n : int) (h : int) (off : int) : int =
  match block h with
  | None -> not_held
  | Some b ->
      if off < 0 || n < 0 || off + n > Bytes.length b.data then refused
      else begin (if out then put 1 b.data off n else get 1 b.data off n); n end

(* the board's free-running counter, in microseconds, its low 30 bits (cross.c) *)
external time : unit -> int = "sip_time"

let call () : int =
  match arg 0 with
  | 0 -> Process.exit (arg 1); 0
  | 1 ->
      let len = arg 2 in
      Machine.print (bytes 1 len);
      len
  | 2 -> Process.yield (); 0
  | 3 -> if arg 2 < 0 || arg 2 > max_name then refused else Process.create true (bytes 1 (arg 2))
  | 4 -> Process.start true (arg 1)
  | 5 -> Process.join (arg 1)
  | 6 -> channel ()
  | 7 -> Process.give (arg 1) (arg 2)
  | 8 -> send (arg 1) (arg 2) (arg 3) (arg 4)
  | 9 -> receive (arg 1)
  | 10 -> select (arg 1)
  | 11 -> close (arg 1)
  | 12 -> alloc (arg 1)
  | 13 -> (match block (arg 1) with Some b -> Exchange.free b; Process.drop (arg 1); 0 | None -> not_held)
  | 14 -> (match block (arg 1) with Some b -> Bytes.length b.data | None -> not_held)
  | 15 -> copy true (arg 2) (arg 3) (arg 4)
  | 16 -> copy false (arg 2) (arg 3) (arg 4)
  | 17 -> time ()
  | _ -> refused

(* nothing the kernel raises reaches a process's code: it ends *)
let () =
  Callback.register "abi" (fun () ->
    try call () with e -> Machine.print ("mini-singularity: " ^ Printexc.to_string e ^ " in a call\n"); Process.exit 2; -1)
