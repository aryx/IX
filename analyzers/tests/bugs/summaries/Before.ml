(* plan_analysis_summaries.md, step 1: a resource across a call. A helper
 * that closes its argument (gives_back), one that returns what it opens
 * (takes): a raise between the open and the helper's call, between the
 * helper's open and the close, now seen; and a raise inside the closing
 * helper before it closes. A descriptor given back by the close of the
 * channel made of it (ed's read and read_file) *)
let read_all (ic : in_channel) : string =
  let s = really_input_string ic (in_channel_length ic) in
  close_in ic;
  s

let first_line (f : string) : string =
  let ic = open_in f in
  let l = input_line ic in
  ignore (read_all ic);
  l

let open_log (f : string) : out_channel = open_out f

let log (f : string) (s : string) : unit =
  let oc = open_log f in
  output_string oc (String.sub s 0 (input_line stdin |> String.length));
  close_out oc

let read_fd (fd : Unix.file_descr) : string =
  let ic = Unix.in_channel_of_descr fd in
  let s = input_line ic in
  close_in ic;
  s

let read (f : string) : string =
  let fd = Unix.openfile f [ Unix.O_RDONLY ] 0 in
  if f = "" then failwith "no name";
  read_fd fd

let () = print_string (first_line "a"); log "b" "c"; print_string (read "d")
