(* Filename.basename and dirname, a name with slashes at its end too:
 * OCaml 4.14's answers (lib_core's were OCaml Light's: bugs/ix.md) *)
let () = List.iter (fun s -> Printf.printf "%S: %S %S\n" s (Filename.basename s) (Filename.dirname s))
  [ ""; "/"; "//"; "a"; "a/"; "a//"; "/a"; "/a/"; "a/b"; "a/b/"; "a//b"; "/a/b"; "d/sub/"; "./x"; "../"; "a/b/c.ml" ]
