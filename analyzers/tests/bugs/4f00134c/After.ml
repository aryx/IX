(* 4f00134c: the variable not passed said *)
let put (file : string) (v : string) : unit =
  let fd = Unix.openfile file [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC ] 0o644 in
  ignore (Unix.write_substring fd v 0 (String.length v));
  Unix.close fd

let set (name : string) (v : string) : unit =
  try put ("/env/" ^ name) v
  with Unix.Unix_error (e, _, _) -> prerr_endline ("execve: $" ^ name ^ " not passed: " ^ Unix.error_message e)

let () = set "LOCAL" "a.ml b.ml"

(* not reported: a close and a remove, best effort; an error chosen *)
let tidy (fd : Unix.file_descr) (file : string) : unit =
  (try Unix.close fd with Unix.Unix_error _ -> ());
  (try Sys.remove file with Sys_error _ -> ());
  try Unix.sleepf 0.1 with Unix.Unix_error (Unix.EINTR, _, _) -> ()

let () = tidy Unix.stdin "/tmp/none"
