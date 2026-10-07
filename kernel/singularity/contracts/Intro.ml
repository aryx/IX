(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Intro.mli *)

let t_meet = 0

let contract : Contract.t =
  Contract.make "Intro"
    [| Contract.message "Meet" Contract.Imp (Contract.Endpoint ("Pong", Contract.Imp)) |]
    [|
      (* 0 Start *) [ (t_meet, 1) ];
      (* 1 Done *) [];
    |]

type imp = Sip.endpoint
type exp = Sip.endpoint

let channel () : imp * exp = Sip.channel contract

module Imp = struct
  let endpoint (e : imp) : Sip.endpoint = e
  let meet (e : imp) (p : Pong.imp) : unit = Sip.send_endpoint e t_meet 0 (Pong.Imp.endpoint p)
end

module Exp = struct
  let of_endpoint (e : Sip.endpoint) : exp = if Sip.is e "Intro" Contract.Exp then e else failwith "not an Intro's exporting end"
  let endpoint (e : exp) : Sip.endpoint = e
  let receive (e : exp) : Pong.imp =
    match (Sip.receive e).carried with
    (* (the kernel checked: a Pong's importing end) *)
    | Endpoint p -> Pong.Imp.of_endpoint p
    | _ -> failwith "Intro: a message that is not the contract's"
end
