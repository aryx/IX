(* packages: unix *)
(* Unix, the rest: sockets, select, a terminal's settings, a timer;
 * mini-ml's own against OCaml's *)

let errors f = try ignore (f ()); "no error" with Unix.Unix_error (e, fn, _) -> Printf.sprintf "%s: %s" fn (Unix.error_message e)
let send fd s = ignore (Unix.write_substring fd s 0 (String.length s))
let recv fd = let b = Bytes.create 64 in let n = Unix.read fd b 0 64 in Bytes.sub_string b 0 n
let count (r, w, e) = Printf.sprintf "%d %d %d" (List.length r) (List.length w) (List.length e)

let () =
  (* a pair: both ways; select before and after something to read; a shutdown read as the end *)
  let a, b = Unix.socketpair Unix.PF_UNIX Unix.SOCK_STREAM 0 in
  print_endline (count (Unix.select [ a; b ] [ a ] [] 0.0));
  send a "ping";
  print_endline (count (Unix.select [ a; b ] [] [] 0.5));
  let got = recv b in
  send b "pong";
  Printf.printf "%s %s %s\n" got (recv a) (count (Unix.select [ a; b ] [] [] 0.01));
  Unix.shutdown a Unix.SHUTDOWN_SEND;
  Printf.printf "%d %s\n" (String.length (recv b)) (count (Unix.select [ b ] [] [] (-1.0)));
  Unix.close a; Unix.close b;

  (* a server on a path, a client in a child *)
  let path = "/tmp/mini-ml-unix-test.sock" in
  (try Unix.unlink path with Unix.Unix_error _ -> ());
  let server = Unix.socket Unix.PF_UNIX Unix.SOCK_STREAM 0 in
  Unix.bind server (Unix.ADDR_UNIX path);
  Unix.listen server 4;
  print_endline (errors (fun () -> Unix.bind (Unix.socket Unix.PF_UNIX Unix.SOCK_STREAM 0) (Unix.ADDR_UNIX path)));
  flush stdout;
  (match Unix.fork () with
   | 0 ->
       let c = Unix.socket Unix.PF_UNIX Unix.SOCK_STREAM 0 in
       Unix.connect c (Unix.ADDR_UNIX path);
       send c "hello, server";
       let answer = recv c in
       Unix._exit (String.length answer)
   | pid ->
       let c, peer = Unix.accept server in
       let msg = recv c in
       send c "welcome";
       let _, st = Unix.waitpid [] pid in
       Printf.printf "%s %s %s\n" msg (match peer with Unix.ADDR_UNIX p -> "unix[" ^ p ^ "]" | Unix.ADDR_INET _ -> "inet")
         (match st with Unix.WEXITED n -> string_of_int n | _ -> "?");
       Unix.close c);
  Unix.close server;
  Unix.unlink path;
  print_endline (errors (fun () -> Unix.connect (Unix.socket Unix.PF_UNIX Unix.SOCK_STREAM 0) (Unix.ADDR_UNIX path)));

  (* addresses; a port nobody listens on *)
  Printf.printf "%s %s %s %b\n" (Unix.string_of_inet_addr Unix.inet_addr_loopback) (Unix.string_of_inet_addr Unix.inet_addr_any)
    (Unix.string_of_inet_addr (Unix.inet_addr_of_string "192.168.1.20")) (try ignore (Unix.inet_addr_of_string "1.2.3"); false with Failure _ -> true);
  List.iter (fun (host, port) ->
    List.iter (fun (a : Unix.addr_info) ->
      match a.ai_addr with
      | Unix.ADDR_INET (ip, p) -> Printf.printf "%s:%d %b\n" (Unix.string_of_inet_addr ip) p (a.ai_family = Unix.PF_INET && a.ai_socktype = Unix.SOCK_STREAM)
      | Unix.ADDR_UNIX _ -> ()) (List.filter (fun (a : Unix.addr_info) -> a.ai_family = Unix.PF_INET)
        (Unix.getaddrinfo host port [ Unix.AI_SOCKTYPE Unix.SOCK_STREAM; Unix.AI_FAMILY Unix.PF_INET ])))
    [ "127.0.0.1", "80"; "10.1.2.3", "9418" ];
  let s = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  print_endline (errors (fun () -> Unix.connect s (Unix.ADDR_INET (Unix.inet_addr_loopback, 1))));
  Unix.close s;

  (* not a terminal; a timer set and taken back *)
  let fd = Unix.openfile "/dev/null" [ Unix.O_RDWR ] 0 in
  Printf.printf "%b %s\n" (Unix.isatty fd) (errors (fun () -> Unix.tcgetattr fd));
  Unix.close fd;
  let old = Unix.setitimer Unix.ITIMER_REAL { Unix.it_interval = 0.0; it_value = 30.0 } in
  let was = Unix.setitimer Unix.ITIMER_REAL { Unix.it_interval = 0.0; it_value = 0.0 } in
  Printf.printf "%.1f %.1f %b\n" old.it_value old.it_interval (was.it_value > 29.0 && was.it_value <= 30.0)
