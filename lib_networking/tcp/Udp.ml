(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Udp.mli *)

let ask (_caps : < Cap.network; .. >) ~(address : string) ~(port : int) (packet : string) (seconds : float) : string option =
  let fd = Unix.socket Unix.PF_INET Unix.SOCK_DGRAM 0 in
  Fun.protect ~finally:(fun () -> Unix.close fd) (fun () ->
    Unix.connect fd (Unix.ADDR_INET (Unix.inet_addr_of_string address, port));
    ignore (Unix.write_substring fd packet 0 (String.length packet));
    match Unix.select [ fd ] [] [] seconds with
    | [], _, _ -> None
    | _ ->
        let b = Bytes.create 1500 in
        let n = Unix.read fd b 0 1500 in
        Some (Bytes.sub_string b 0 n))
