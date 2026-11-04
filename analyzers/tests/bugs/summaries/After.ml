(* the same helpers used without a raise between, and a helper that
 * closes on one path only: no summary, nothing said *)
let close_quietly (ic : in_channel) : unit = close_in ic

let contents (f : string) : string =
  let ic = open_in f in
  close_quietly ic;
  f

let maybe_close (b : bool) (ic : in_channel) : unit = if b then close_in ic

let open_ro (f : string) : in_channel = open_in f

let size (f : string) : int =
  let ic = open_ro f in
  close_in ic;
  String.length f

(* a descriptor's channel closed, nothing raising between *)
let length_of (f : string) : int =
  let fd = Unix.openfile f [ Unix.O_RDONLY ] 0 in
  let ic = Unix.in_channel_of_descr fd in
  let n = in_channel_length ic in
  close_in ic;
  n

let () =
  print_string (contents "a"); maybe_close true stdin; print_int (size "b");
  print_int (length_of "c")
