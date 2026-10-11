(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Udp.mli: Plan 9's, for mini-9pi (docs/plans/plan_browser.md, stage
 * 10). A directory of /net/udp, as Tcp's of /net/tcp: once "connect
 * address!port" is written to its ctl, a write to its data is a packet
 * sent there and a read a packet come from there. No select: the read
 * waits. (Not done: giving up after [seconds].) *)

let ask (_caps : < Cap.network; .. >) ~(address : string) ~(port : int) (packet : string) (_seconds : float) : string option =
  let ctl = Unix.openfile "/net/udp/clone" [ Unix.O_RDWR ] 0 in
  Fun.protect
    ~finally:(fun () -> Unix.close ctl)
    (fun () ->
      let b = Bytes.create 32 in
      let n = Unix.read ctl b 0 32 in
      let number = String.trim (Bytes.sub_string b 0 n) in
      let order = Printf.sprintf "connect %s!%d" address port in
      ignore (Unix.write_substring ctl order 0 (String.length order));
      let data = Unix.openfile ("/net/udp/" ^ number ^ "/data") [ Unix.O_RDWR ] 0 in
      Fun.protect
        ~finally:(fun () -> Unix.close data)
        (fun () ->
          ignore (Unix.write_substring data packet 0 (String.length packet));
          let b = Bytes.create 1500 in
          let n = Unix.read data b 0 1500 in
          if n = 0 then None else Some (Bytes.sub_string b 0 n)))
