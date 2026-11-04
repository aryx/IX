(* b9fea684: begin ... end; and the layouts that say what OCaml does:
 * the else's branch on its line, the next statement in the if's column *)
let running : int list ref = ref []
let start (prog : string) : int = String.length prog

let run (in_window : bool) (command : string list) : unit =
  if in_window then (
    print_string "a new window")
  else begin
    running := List.filter (fun pid -> pid > 0) !running;
    match command with
    | prog :: _ -> running := start prog :: !running
    | [] -> ()
  end

let log (verbose : bool) (s : string) : unit =
  if verbose then print_string s else print_string ".";
  print_newline ()

let count (on : bool) : unit =
  if on then
    incr (ref 0);
  print_string "counted"

let () = run true [ "emacs" ]; log true "x"; count true
