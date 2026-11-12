(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMachineSocket.mli *)

let usage =
  "usage: tiny-machine-socket dial host port | listen port | name host"

(* The first IPv4 address of a name: the machine's addresses are four
 * bytes. *)
let address (caps : < Cap.network; .. >) host =
  match
    List.filter
      (fun (a : Unix.addr_info) -> a.ai_family = Unix.PF_INET)
      (CapUnix.getaddrinfo caps host "" [ Unix.AI_SOCKTYPE Unix.SOCK_STREAM ])
  with
  | { ai_addr = Unix.ADDR_INET (a, _); _ } :: _ -> Some a
  | _ -> None

let dial (caps : < Cap.network; .. >) host port =
  match address caps host with
  | None -> None
  | Some a ->
      let fd = CapUnix.socket caps Unix.PF_INET Unix.SOCK_STREAM 0 in
      Unix.set_nonblock fd;
      let made =
        try CapUnix.connect caps fd (Unix.ADDR_INET (a, port)); true
        with
        | Unix.Unix_error ((Unix.EINPROGRESS | Unix.EINTR), _, _) -> (
            (* when it can be written the try is over; asked again, a
             * connection made says it is one, one refused says why *)
            match Unix.select [] [ fd ] [] 5. with
            | _, [ _ ], _ -> (
                try CapUnix.connect caps fd (Unix.ADDR_INET (a, port)); true
                with
                | Unix.Unix_error (Unix.EISCONN, _, _) -> true
                | Unix.Unix_error _ -> false)
            | _ -> false)
        | Unix.Unix_error _ -> false in
      if made then (Unix.clear_nonblock fd; Some fd) else (Unix.close fd; None)

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

let say (caps : < Cap.stdout; .. >) s =
  ignore (Unix.write_substring (Console.stdout_fd caps) s 0 (String.length s))

(* Arms SIGALRM, which ends this program, in s seconds; 0. disarms it. *)
let timer (caps : < Cap.signal; .. >) s =
  ignore
    (CapUnix.setitimer caps Unix.ITIMER_REAL
       { it_interval = 0.; it_value = s })

(* Not Filename.temp_file, which reaches the system with no capability. *)
let fifos = ref 0
let fifo (caps : < Cap.open_out; Cap.env; .. >) =
  let rec made () =
    incr fifos;
    let f =
      Printf.sprintf "/tmp/tiny-machine-socket-%d-%d" (CapUnix.getpid caps ())
        !fifos in
    match CapUnix.mkfifo caps f 0o600 with
    | () -> f
    | exception Unix.Unix_error (Unix.EEXIST, _, _) -> made () in
  made ()

(* Listens until the standard input ends (whoever ran this is gone).
 * Each connection is relayed by a child on two named pipes, which the
 * one who ran this must open within ten seconds. The socket stays open
 * for the next connection: closing it after the first refused one that
 * came before the next listen (linux.py's GET /bin/ping on GitHub). *)
let listen
    (caps : < Cap.network; Cap.stdin; Cap.stdout; Cap.fork; Cap.signal;
             Cap.open_in; Cap.open_out; Cap.env; Cap.exit; .. >) port =
  let l = CapUnix.socket caps Unix.PF_INET Unix.SOCK_STREAM 0 in
  match
    Unix.setsockopt l Unix.SO_REUSEADDR true;
    CapUnix.bind caps l (Unix.ADDR_INET (Unix.inet_addr_loopback, port));
    CapUnix.listen caps l 16
  with
  | exception Unix.Unix_error _ -> Unix.close l; say caps "-\n"
  | () ->
      say caps "+\n";
      CapSys.set_signal caps Sys.sigchld Sys.Signal_ignore;
      let rec wait () =
        let ready, _, _ = Unix.select [ Console.stdin_fd caps; l ] [] [] (-1.) in
        if not (List.mem (Console.stdin_fd caps) ready) then begin
          (match CapUnix.accept caps l with
           | fd, _ ->
               let inp = fifo caps and out = fifo caps in
               (match CapUnix.fork caps () with
                | 0 ->
                    Unix.close l;
                    Unix.close (Console.stdout_fd caps);
                    timer caps 10.;
                    let i = FS.open_in_fd caps inp in
                    let o = FS.open_device_fd caps out in
                    timer caps 0.;
                    CapSys.remove caps inp;
                    CapSys.remove caps out;
                    relay i o fd;
                    CapUnix._exit caps 0
                | _ -> Unix.close fd; say caps (inp ^ " " ^ out ^ "\n"))
           | exception Unix.Unix_error _ -> ());
          wait ()
        end in
      wait ()

let main
    (caps : < Cap.network; Cap.stdin; Cap.stdout; Cap.stderr; Cap.fork;
             Cap.signal; Cap.open_in; Cap.open_out; Cap.env; Cap.exit; .. >)
    (argv : string array) : Exit.t =
  CapSys.set_signal caps Sys.sigpipe Sys.Signal_ignore;
  (* (a terminal's ^C is for the kernel in the machine, which the one that
   * ran this gives it) *)
  CapSys.set_signal caps Sys.sigint Sys.Signal_ignore;
  match List.tl (Array.to_list argv) with
  | [ "dial"; host; port ] when int_of_string_opt port <> None ->
      let fd = dial caps host (int_of_string port) in
      say caps (if fd = None then "-" else "+");
      Option.iter (relay (Console.stdin_fd caps) (Console.stdout_fd caps)) fd;
      Exit.OK
  | [ "listen"; port ] when int_of_string_opt port <> None ->
      listen caps (int_of_string port);
      Exit.OK
  | [ "name"; host ] ->
      Option.iter
        (fun a -> Console.print caps (Unix.string_of_inet_addr a ^ "\n"))
        (address caps host);
      Exit.OK
  | _ -> Console.eprint caps (usage ^ "\n"); Exit.Code 2

let () = TinyLibSystem.main "tiny-machine-socket" main
