(* c5086383^, shell/Process.ml's fork: the child ran f in a try whose
 * every case is a constant, a pipe's open that failed (a Sys_error)
 * ending it in silence, exit 1 and no word *)
let fork (f : unit -> int) : int =
  match Unix.fork () with
  | 0 ->
      let code = try f () with _ -> 1 in
      Unix._exit code
  | pid -> pid

let pipe (file : string) : int =
  fork (fun () -> let c = open_in file in print_string (input_line c); 0)

let () = ignore (pipe "/nonexistent")
