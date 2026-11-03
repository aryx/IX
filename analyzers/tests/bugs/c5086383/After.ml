(* c5086383: the exception said; and what a try may silence: the end of
 * a loop (End_of_file), a value not found (an Option) *)
let fork (f : unit -> int) : int =
  match Unix.fork () with
  | 0 ->
      let code = try f () with e -> prerr_endline ("rc: " ^ Printexc.to_string e); 1 in
      Unix._exit code
  | pid -> pid

let pipe (file : string) : int =
  fork (fun () -> let c = open_in file in print_string (input_line c); 0)

let lines (c : in_channel) : int =
  let n = ref 0 in
  (try while true do ignore (input_line c); incr n done with End_of_file -> ());
  !n

let find (k : string) (l : (string * int) list) : int option = try Some (List.assoc k l) with Not_found -> None

let () = ignore (pipe "/etc/passwd", lines stdin, find "a" [])
