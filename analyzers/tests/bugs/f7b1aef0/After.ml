(* f7b1aef0: Files.read, the close in Fun.protect's finally; a close
 * before a raise, and one in the handler that raises again, are no
 * leaks either *)
let read (file : string) : string =
  let ic = open_in_bin file in
  Fun.protect ~finally:(fun () -> close_in ic)
    (fun () -> really_input_string ic (in_channel_length ic))

let first_line (file : string) : string =
  let ic = open_in file in
  if in_channel_length ic = 0 then (close_in ic; failwith "empty")
  else begin
    let l = try input_line ic with e -> close_in ic; raise e in
    close_in ic;
    l
  end

let () = print_string (read "mkfile" ^ first_line "mkfile")
