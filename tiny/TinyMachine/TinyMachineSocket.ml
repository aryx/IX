(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMachineSocket.mli *)

let usage =
  "usage: tiny-machine-socket dial host port | listen port | name host"

(* a name's first address of the Internet's first kind (IPv4: the
 * machine's addresses are four bytes) *)
let address (_caps : < Cap.network; .. >) host =
  match
    List.filter
      (fun (a : Unix.addr_info) -> a.ai_family = Unix.PF_INET)
      (Unix.getaddrinfo host "" [ Unix.AI_SOCKTYPE Unix.SOCK_STREAM ])
  with
  | { ai_addr = Unix.ADDR_INET (a, _); _ } :: _ -> Some a
  | _ -> None

(* a connection there, if it is made in five seconds *)
let dial (caps : < Cap.network; .. >) host port =
  match address caps host with
  | None -> None
  | Some a ->
      let fd = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
      Unix.set_nonblock fd;
      let made =
        try Unix.connect fd (Unix.ADDR_INET (a, port)); true
        with
        | Unix.Unix_error ((Unix.EINPROGRESS | Unix.EINTR), _, _) -> (
            (* when it can be written the try is over; asked again, a
             * connection made says it is one, one refused says why *)
            match Unix.select [] [ fd ] [] 5. with
            | _, [ _ ], _ -> (
                try Unix.connect fd (Unix.ADDR_INET (a, port)); true
                with
                | Unix.Unix_error (Unix.EISCONN, _, _) -> true
                | Unix.Unix_error _ -> false)
            | _ -> false)
        | Unix.Unix_error _ -> false in
      if made then (Unix.clear_nonblock fd; Some fd) else (Unix.close fd; None)

(* the first connection made to this machine's port *)
let listen (_caps : < Cap.network; .. >) port =
  let l = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  try
    Unix.setsockopt l Unix.SO_REUSEADDR true;
    Unix.bind l (Unix.ADDR_INET (Unix.inet_addr_loopback, port));
    Unix.listen l 16;
    (* (or the standard input's end: who ran this is gone) *)
    let rec wait () =
      match Unix.select [ Unix.stdin; l ] [] [] (-1.) with
      | ready, _, _ ->
          if List.mem Unix.stdin ready then exit 0
          else if not (List.mem l ready) then wait () in
    wait ();
    let fd, _ = Unix.accept l in
    Unix.close l;
    Some fd
  with Unix.Unix_error _ -> Unix.close l; None

(* the bytes both ways, until one side ends *)
let relay fd =
  let b = Bytes.create 4096 in
  let rec all to_ n at =
    if at < n then all to_ n (at + Unix.write to_ b at (n - at)) in
  let rec go () =
    let ready, _, _ = Unix.select [ Unix.stdin; fd ] [] [] (-1.) in
    let pass from to_ =
      if List.mem from ready then (
        let n = Unix.read from b 0 4096 in
        if n = 0 then raise Exit;
        all to_ n 0) in
    pass Unix.stdin fd;
    pass fd Unix.stdout;
    go () in
  try go () with Exit | Unix.Unix_error _ -> ()

let main (caps : < Cap.network; Cap.argv; Cap.stdout; .. >) =
  Sys.set_signal Sys.sigpipe Sys.Signal_ignore;
  (* (a terminal's ^C is for the kernel in the machine, which the one that
   * ran this gives it) *)
  Sys.set_signal Sys.sigint Sys.Signal_ignore;
  let said fd =
    ignore
      (Unix.write_substring Unix.stdout (if fd = None then "-" else "+") 0 1);
    Option.iter relay fd;
    0 in
  match List.tl (Array.to_list (CapSys.argv caps)) with
  | [ "dial"; host; port ] when int_of_string_opt port <> None ->
      said (dial caps host (int_of_string port))
  | [ "listen"; port ] when int_of_string_opt port <> None ->
      said (listen caps (int_of_string port))
  | [ "name"; host ] ->
      Option.iter
        (fun a -> Console.print caps (Unix.string_of_inet_addr a ^ "\n"))
        (address caps host);
      0
  | _ -> prerr_endline usage; 2

let () = Cap.main (fun caps -> CapStdlib.exit caps (main caps))
