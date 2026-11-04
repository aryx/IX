(* b9fea684^, lib_mime/Helpers.ml: if ... then (...) else a; match ...
 * makes the else the line a alone; the match, which starts the program
 * beside the caller, also ran after mini-rio had been asked for a new
 * window for it: the program started twice *)
let running : int list ref = ref []
let start (prog : string) : int = String.length prog

let run (in_window : bool) (command : string list) : unit =
  if in_window then (
    print_string "a new window")
  else
  running := List.filter (fun pid -> pid > 0) !running;
  match command with
  | prog :: _ -> running := start prog :: !running
  | [] -> ()

let () = run true [ "emacs" ]
