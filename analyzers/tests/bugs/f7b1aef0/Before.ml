(* f7b1aef0^, builder/CLI.ml: read_file closed its channel only when the
 * read succeeded; a read that raised (Sys_error, End_of_file) left it
 * open, and mini-mk reads many files *)
let read_file (file : string) : string option =
  if not (Sys.file_exists file) then None
  else
    let ic = open_in file in
    let s = really_input_string ic (in_channel_length ic) in
    close_in ic;
    Some s

let () = ignore (read_file "mkfile")
