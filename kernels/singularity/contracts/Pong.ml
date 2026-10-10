(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Pong.mli *)

(* the messages' tags: their places below *)
let t_ready = 0
let t_ping = 1
let t_pong = 2
let t_text = 3
let t_thanks = 4
let t_lend = 5
let t_return = 6

let contract : Contract.t =
  Contract.make "Pong"
    [|
      Contract.message "Ready" Contract.Exp Contract.Nothing;
      Contract.message "Ping" Contract.Imp Contract.Nothing;
      Contract.message "Pong" Contract.Exp Contract.Nothing;
      Contract.message "Text" Contract.Imp Contract.Block;
      Contract.message "Thanks" Contract.Exp Contract.Nothing;
      Contract.message "Lend" Contract.Imp Contract.Block;
      Contract.message "Return" Contract.Exp Contract.Block;
    |]
    [|
      (* 0 *) ("Start", [ (t_ready, 1) ]);
      (* 1 *) ("Serve", [ (t_ping, 2); (t_text, 3); (t_lend, 4) ]);
      (* 2 *) ("Serve/Ping", [ (t_pong, 1) ]);
      (* 3 *) ("Serve/Text", [ (t_thanks, 1) ]);
      (* 4 *) ("Serve/Lend", [ (t_return, 1) ]);
    |]

type imp = Sip.endpoint
type exp = Sip.endpoint

type request =
  | Ping of int
  | Text of Sip.block * int
  | Lend of Sip.block
type reply =
  | Ready
  | Pong of int
  | Thanks
  | Return of Sip.block

let channel () : imp * exp = Sip.channel contract

(* (the kernel let the message through: it is one of the contract's,
 * carrying what the contract says) *)
let broken () = failwith "Pong: a message that is not the contract's"

module Imp = struct
  let of_endpoint (e : Sip.endpoint) : imp = if Sip.is e "Pong" Contract.Imp then e else failwith "not a Pong's importing end"
  let endpoint (e : imp) : Sip.endpoint = e
  let ping (e : imp) (n : int) : unit = Sip.send e t_ping n
  let text (e : imp) (b : Sip.block) (n : int) : unit = Sip.send_block e t_text n b
  let lend (e : imp) (b : Sip.block) : unit = Sip.send_block e t_lend 0 b
  let receive (e : imp) : reply =
    let m = Sip.receive e in
    match m.carried with
    | Nothing when m.tag = t_ready -> Ready
    | Nothing when m.tag = t_pong -> Pong m.value
    | Nothing when m.tag = t_thanks -> Thanks
    | Block b when m.tag = t_return -> Return b
    | _ -> broken ()
  let close (e : imp) : unit = Sip.close e
end

module Exp = struct
  let of_endpoint (e : Sip.endpoint) : exp = if Sip.is e "Pong" Contract.Exp then e else failwith "not a Pong's exporting end"
  let endpoint (e : exp) : Sip.endpoint = e
  let ready (e : exp) : unit = Sip.send e t_ready 0
  let pong (e : exp) (n : int) : unit = Sip.send e t_pong n
  let thanks (e : exp) : unit = Sip.send e t_thanks 0
  let return (e : exp) (b : Sip.block) : unit = Sip.send_block e t_return 0 b
  let receive (e : exp) : request =
    let m = Sip.receive e in
    match m.carried with
    | Nothing when m.tag = t_ping -> Ping m.value
    | Block b when m.tag = t_text -> Text (b, m.value)
    | Block b when m.tag = t_lend -> Lend b
    | _ -> broken ()
  let close (e : exp) : unit = Sip.close e
end
