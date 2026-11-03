(* 4f00134c^, lib_core/system/plan9/Unix.ml's execve: a variable not
 * written to /env (larger than /env takes) left out in silence, a
 * mkfile's recipe started with an empty list *)
let put (file : string) (v : string) : unit =
  let fd = Unix.openfile file [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC ] 0o644 in
  ignore (Unix.write_substring fd v 0 (String.length v));
  Unix.close fd

let set (name : string) (v : string) : unit = try put ("/env/" ^ name) v with Unix.Unix_error _ -> ()

let () = set "LOCAL" "a.ml b.ml"
