(* packages: unix *)
(* Signals: Sys.signal's handlers, run where the program waits (a read
 * interrupted, then asked again), Sys.Break, and Unix's EINTR *)

let name (b : Sys.signal_behavior) = match b with Signal_default -> "default" | Signal_ignore -> "ignore" | Signal_handle _ -> "handle"
let got = ref []
let handler s = got := s :: !got
let show what =
  Printf.printf "%s: %s\n" what (String.concat " " (List.rev_map (fun s -> if s = Sys.sigusr1 then "usr1" else if s = Sys.sigusr2 then "usr2" else "other") !got));
  got := []

(* a child that signals its parent after a while, then writes to it *)
let child sg fd text =
  flush stdout;
  match Unix.fork () with
  | 0 ->
      Unix.sleepf 0.2;
      Unix.kill (Unix.getppid ()) sg;
      Unix.sleepf 0.2;
      ignore (Unix.write_substring fd text 0 (String.length text));
      exit 0
  | pid -> pid

let () =
  (* the behavior before, given back *)
  print_endline (name (Sys.signal Sys.sigusr1 (Sys.Signal_handle handler)));
  print_endline (name (Sys.signal Sys.sigusr1 Sys.Signal_ignore));
  print_endline (name (Sys.signal Sys.sigusr1 (Sys.Signal_handle handler)));
  Sys.set_signal Sys.sigusr2 (Sys.Signal_handle handler);

  (* to oneself *)
  Unix.kill (Unix.getpid ()) Sys.sigusr1;
  show "to oneself";
  Sys.set_signal Sys.sigusr1 Sys.Signal_ignore;
  Unix.kill (Unix.getpid ()) Sys.sigusr1;
  show "ignored";
  Sys.set_signal Sys.sigusr1 (Sys.Signal_handle handler);

  (* a line read through a signal: the handler run, the read asked again *)
  let r, w = Unix.pipe ~cloexec:false () in
  let ic = Unix.in_channel_of_descr r in
  let pid = child Sys.sigusr2 w "a line\n" in
  let l = input_line ic in
  show "while reading a line";
  print_endline l;
  ignore (Unix.waitpid [] pid);
  let pid = child Sys.sigusr1 w "x" in
  let c = input_char ic in
  show "while reading a char";
  Printf.printf "%c\n" c;
  ignore (Unix.waitpid [] pid);

  (* Unix's read says it: EINTR, the handler run *)
  let pid = child Sys.sigusr1 w "late\n" in
  let b = Bytes.create 8 in
  (match Unix.read r b 0 8 with
   | n -> Printf.printf "read %d\n" n
   | exception Unix.Unix_error (Unix.EINTR, fn, _) -> Printf.printf "%s: interrupted\n" fn);
  show "in a system call";
  print_endline (input_line ic);
  ignore (Unix.waitpid [] pid);

  (* Break: the handler raises, out of the read *)
  Sys.catch_break true;
  let pid = child Sys.sigint w "never read\n" in
  (match input_line ic with l -> print_endline l | exception Sys.Break -> print_endline "Break");
  Sys.catch_break false;
  ignore (Unix.waitpid [] pid);
  print_endline (name (Sys.signal Sys.sigint Sys.Signal_default))
