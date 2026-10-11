(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Tcp.mli: Plan 9's, for mini-9pi (docs/plans/plan_browser.md, stage
 * 10). No socket: a connection is a directory of /net/tcp, as libc's
 * dial makes it -- clone opened (it is the new connection's ctl, and
 * says its number), "connect address!port" written to it (which
 * returns once connected, or fails with the reason), its data file
 * opened: the stream. The ctl is then closed; the kernel hangs up at
 * the last close, the data's (mini-9pi's Devip). *)

let timeout = 30.

let is_address (host : string) : bool = host <> "" && String.for_all (fun c -> (c >= '0' && c <= '9') || c = '.') host

let dial (address : string) (port : int) : Unix.file_descr =
  let ctl = Unix.openfile "/net/tcp/clone" [ Unix.O_RDWR ] 0 in
  Fun.protect
    ~finally:(fun () -> Unix.close ctl)
    (fun () ->
      let b = Bytes.create 32 in
      let n = Unix.read ctl b 0 32 in
      let number = String.trim (Bytes.sub_string b 0 n) in
      let order = Printf.sprintf "connect %s!%d" address port in
      ignore (Unix.write_substring ctl order 0 (String.length order));
      Unix.openfile ("/net/tcp/" ^ number ^ "/data") [ Unix.O_RDWR ] 0)

let connect (caps : < Cap.network; Cap.open_in; .. >) ~(host : string) ~(port : int) : Unix.file_descr =
  let addresses = if is_address host then [ host ] else Dns.resolve caps host in
  if addresses = [] then failwith (Printf.sprintf "Tcp.connect: can't resolve %S" host);
  (* each address in turn, the last one's error raised *)
  let rec try_ (l : string list) : Unix.file_descr =
    match l with
    | [] -> assert false
    | a :: others -> ( try dial a port with Unix.Unix_error _ as e -> if others = [] then raise e else try_ others)
  in
  try_ addresses

let send_all (fd : Unix.file_descr) (s : string) : unit =
  let rec go pos = if pos < String.length s then go (pos + Unix.write_substring fd s pos (String.length s - pos)) in
  go 0

(* no select, and no read that does not wait: a read gives the first
 * bytes when they come, and the wait is its own. It gives up after
 * [timeout]: an alarm set before it (Unix.setitimer: Plan 9's note
 * "alarm", which the runtime goes on from), taken back after; the read
 * it interrupts fails, and the connection is said lost.
 * old: no alarm, and a server that said nothing held the program *)
let wait (_fd : Unix.file_descr) (_seconds : float) : unit = ()

let alarm (seconds : float) : unit = ignore (Unix.setitimer Unix.ITIMER_REAL { Unix.it_interval = 0.; it_value = seconds })

let arrived (fd : Unix.file_descr) : string option =
  let buf = Bytes.create 65536 in
  alarm timeout;
  let r =
    match Unix.read fd buf 0 (Bytes.length buf) with
    | 0 -> None
    | n -> Some (Bytes.sub_string buf 0 n)
    | exception Unix.Unix_error _ -> None
  in
  alarm 0.;
  r

let receive_all (fd : Unix.file_descr) : string =
  let b = Buffer.create 65536 in
  let rec go () = match arrived fd with None -> Buffer.contents b | Some s -> Buffer.add_string b s; go () in
  go ()

let exchange (caps : < Cap.network; Cap.open_in; .. >) ~(host : string) ~(port : int) (s : string) : string =
  let fd = connect caps ~host ~port in
  Fun.protect
    ~finally:(fun () -> Unix.close fd)
    (fun () ->
      send_all fd s;
      receive_all fd)
