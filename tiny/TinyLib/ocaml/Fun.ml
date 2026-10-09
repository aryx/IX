(* The OCaml programmers
 * OCaml. Copyright 2018 INRIA. LGPL 2.1, with the linking exception of OCaml's LICENSE. *)

external id : 'a -> 'a = "%identity"

let protect ~finally work =
  let result = (try work () with e -> finally (); raise e) in
  finally ();
  result
