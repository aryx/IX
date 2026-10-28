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

(* the bytes both ways, until one side ends: what is read on inp to
 * the connection, what comes from it to out *)
let relay inp out fd =
  let b = Bytes.create 4096 in
  let rec all to_ n at =
    if at < n then all to_ n (at + Unix.write to_ b at (n - at)) in
  let rec go () =
    let ready, _, _ = Unix.select [ inp; fd ] [] [] (-1.) in
    let pass from to_ =
      if List.mem from ready then (
        let n = Unix.read from b 0 4096 in
        if n = 0 then raise Exit;
        all to_ n 0) in
    pass inp fd;
    pass fd out;
    go () in
  try go () with Exit | Unix.Unix_error _ -> ()

let say s = ignore (Unix.write_substring Unix.stdout s 0 (String.length s))

(* SIGALRM's, which ends this, in s seconds (0.: none) *)
let timer s =
  ignore
    (Unix.setitimer Unix.ITIMER_REAL { it_interval = 0.; it_value = s })

(* a named pipe of its own *)
let fifo () =
  let f = Filename.temp_file "tiny-machine-socket" "" in
  Sys.remove f;
  Unix.mkfifo f 0o600;
  f

(* this machine's port (127.0.0.1's), listened on until the standard
 * input's end (who ran this is gone); each connection relayed by a
 * child on two named pipes, opened by the one who ran this (the child
 * waits ten seconds for it), their names said. old: the first
 * connection alone, its socket then closed, the next one's helper
 * started when this one's was seen: a connection between the two was
 * refused (make test on GitHub's runner, linux.py's GET /bin/ping) *)
let listen (_caps : < Cap.network; .. >) port =
  let l = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  match
    Unix.setsockopt l Unix.SO_REUSEADDR true;
    Unix.bind l (Unix.ADDR_INET (Unix.inet_addr_loopback, port));
    Unix.listen l 16
  with
  | exception Unix.Unix_error _ -> Unix.close l; say "-\n"
  | () ->
      say "+\n";
      Sys.set_signal Sys.sigchld Sys.Signal_ignore;
      let rec wait () =
        let ready, _, _ = Unix.select [ Unix.stdin; l ] [] [] (-1.) in
        if not (List.mem Unix.stdin ready) then begin
          (match Unix.accept l with
           | fd, _ ->
               let inp = fifo () and out = fifo () in
               (match Unix.fork () with
                | 0 ->
                    Unix.close l;
                    Unix.close Unix.stdout;
                    timer 10.;
                    let i = Unix.openfile inp [ Unix.O_RDONLY ] 0 in
                    let o = Unix.openfile out [ Unix.O_WRONLY ] 0 in
                    timer 0.;
                    Sys.remove inp;
                    Sys.remove out;
                    relay i o fd;
                    Unix._exit 0
                | _ -> Unix.close fd; say (inp ^ " " ^ out ^ "\n"))
           | exception Unix.Unix_error _ -> ());
          wait ()
        end in
      wait ()

let main (caps : < Cap.network; Cap.argv; Cap.stdout; .. >) =
  Sys.set_signal Sys.sigpipe Sys.Signal_ignore;
  (* (a terminal's ^C is for the kernel in the machine, which the one that
   * ran this gives it) *)
  Sys.set_signal Sys.sigint Sys.Signal_ignore;
  match List.tl (Array.to_list (CapSys.argv caps)) with
  | [ "dial"; host; port ] when int_of_string_opt port <> None ->
      let fd = dial caps host (int_of_string port) in
      say (if fd = None then "-" else "+");
      Option.iter (relay Unix.stdin Unix.stdout) fd;
      0
  | [ "listen"; port ] when int_of_string_opt port <> None ->
      listen caps (int_of_string port);
      0
  | [ "name"; host ] ->
      Option.iter
        (fun a -> Console.print caps (Unix.string_of_inet_addr a ^ "\n"))
        (address caps host);
      0
  | _ -> prerr_endline usage; 2

let () = Cap.main (fun caps -> CapStdlib.exit caps (main caps))
