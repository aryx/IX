(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Abi.mli *)

(* the call's word i, read and set; set to the address a physical one
 * is for a process; n bytes at the address its word i is, a new string
 * of them (cross.c) *)
external arg : int -> int = "abi_arg"
external set : int -> int -> unit = "abi_set"
external set_addr : int -> int -> unit = "abi_set_addr"
external bytes : int -> int -> string = "abi_bytes"

(* a name's bytes, at most; a select's endpoints *)
let max_name = 64
let max_select = 3
let max_contract = 4096

let refused = -1
let not_held = -2

let endpoint (h : int) : Channel.endpoint option = match Process.handle h with Endpoint e -> Some e | _ -> None
let block (h : int) : Exchange.block option = match Process.handle h with Block b -> Some b | _ -> None

(* a block's address and bytes, for its new owner: words i and i + 1 *)
let tell (i : int) (b : Exchange.block) : unit = set_addr i b.addr; set (i + 1) b.size

(* a channel of the contract the caller describes (Contract.encode's bytes) *)
let channel (n : int) : int =
  match (if n < 0 || n > max_contract then None else Contract.decode (bytes 1 n)) with
  | None -> refused
  | Some contract ->
      let a, b = Channel.create contract (Process.running ()) in
      let ha = Process.hold (Endpoint a) in
      let hb = if ha >= 0 then Process.hold (Endpoint b) else -1 in
      if hb < 0 then begin (if ha >= 0 then Process.drop ha); refused end
      else begin set 1 hb; ha end

(* a message, with what the caller's handle hc is (-1: nothing). One
 * the contract refuses is the sender's end: the other end sees the
 * channel closed, and the system goes on. *)
let send (h : int) (tag : int) (value : int) (hc : int) : int =
  let carried : Channel.carried option =
    if hc < 0 then Some Nothing
    else match Process.handle hc with
      | Block b -> Some (Block b)
      | Endpoint x -> Some (Endpoint x)
      | _ -> None
  in
  match endpoint h, carried with
  | None, _ | _, None -> not_held
  | Some e, Some carried -> (
      match Channel.send e { tag; value; carried } with
      | Sent -> (if hc >= 0 then Process.drop hc); 0
      | Closed_ -> refused
      | Refused why ->
          Machine.print (Printf.sprintf "mini-singularity: %s ended: %s.\n" (Process.name ()) why);
          Process.exit 255;
          refused)

let rec receive (h : int) : int =
  match endpoint h with
  | None -> not_held
  | Some e -> (
      match Channel.receive e with
      | Message m ->
          set 1 m.value;
          (* what it carries is the receiver's: its handle in word 2, its kind in word 5 *)
          (match m.carried with
           | Nothing -> set 2 (-1); set 5 0
           | Block b ->
               let hb = Process.hold (Block b) in
               if hb >= 0 then begin b.owner <- Process.running (); tell 3 b end else Exchange.free b;
               set 2 hb; set 5 1
           | Endpoint x ->
               let hx = Process.hold (Endpoint x) in
               if hx >= 0 then x.owner <- Process.running () else Channel.close x;
               set 2 hx; set 5 2);
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
      if h < 0 then Exchange.free b else tell 1 b;
      h

(* the board's free-running counter, in microseconds, its low 30 bits (cross.c) *)
external time : unit -> int = "sip_time"

(* a device's register, a word at an offset of the peripherals', read
 * (its low 30 bits) and written (cross.c) *)
external io_read : int -> int = "sip_io_read"
external io_write : int -> int -> unit = "sip_io_write"

(* a register of a device the caller was given: read (out) or written *)
let register (out : bool) (h : int) (off : int) (v : int) : int =
  match Process.handle h with
  | Registers (at, bytes) ->
      if off < 0 || off land 3 <> 0 || off + 4 > bytes then refused
      else if out then io_read (at + off)
      else begin io_write (at + off) v; 0 end
  | _ -> not_held

(* the processes, or the programs, as text in a block of the caller's: the bytes written *)
let info (h : int) (programs : bool) : int =
  match block h with
  | None -> not_held
  | Some b ->
      let s = Process.listing programs in
      let n = min (String.length s) b.size in
      Machine.Phys.write_sub b.addr s 0 n;
      n

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
  | 6 -> channel (arg 2)
  | 7 -> Process.give (arg 1) (arg 2)
  | 8 -> send (arg 1) (arg 2) (arg 3) (arg 4)
  | 9 -> receive (arg 1)
  | 10 -> select (arg 1)
  | 11 -> close (arg 1)
  | 12 -> alloc (arg 1)
  | 13 -> (match block (arg 1) with Some b -> Exchange.free b; Process.drop (arg 1); 0 | None -> not_held)
  | 14 -> time ()
  | 15 -> (
      (* is the endpoint of that contract (its name's bytes), that end (0 the importing)? *)
      match endpoint (arg 3) with
      | None -> not_held
      | Some e ->
          if arg 2 < 0 || arg 2 > max_name then refused
          else if e.channel.contract.name = bytes 1 (arg 2) && (e.side = Imp) = (arg 4 = 0) then 0
          else refused)
  | 16 -> register true (arg 1) (arg 2) 0
  | 17 -> register false (arg 1) (arg 2) (arg 3)
  | 18 -> (match Process.handle (arg 1) with Interrupt _ -> Process.sleep (); 0 | _ -> not_held)
  | 19 -> info (arg 1) (arg 2 <> 0)
  | 20 -> Process.stop (arg 1)
  | _ -> refused

(* nothing the kernel raises reaches a process's code: it ends *)
let () =
  Callback.register "abi" (fun () ->
    try call () with e -> Machine.print ("mini-singularity: " ^ Printexc.to_string e ^ " in a call\n"); Process.exit 2; -1)
