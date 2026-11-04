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

let () = print_string (contents "a"); maybe_close true stdin; print_int (size "b")
