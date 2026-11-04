(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Ml_flow.mli *)

let file ?(sites = false) (caps : < CLI.caps; .. >) (dirs : Fpath.t list)
    (file : Fpath.t) : (Ssa.func list, string) result =
  Lower.sites := sites;
  Fun.protect ~finally:(fun () -> Lower.sites := false) @@ fun () ->
  let f = Fpath.to_string file in
  match CLI.parse caps file with
  | Error m -> Error m
  | Ok (_, Ast.Signature _) -> Ok []
  | Ok (text, Ast.Structure items) -> (
      let base = Filename.remove_extension (Filename.basename f) in
      let name = String.capitalize_ascii base in
      let dirs = Fpath.parent file :: dirs in
      match CLI.classes caps dirs ~lenient:false f text items with
      | exception CLI.Rejected m -> Error m
      | _, _, items -> (
          match Typing.unit_ name items with
          | exception Typing.Error (l, m) ->
              Error (Printf.sprintf "%s:%d: %s" f l m)
          | _ -> (
              let objdir = Fpath.parent file in
              match CLI.lower caps ~unsafe:false Arm64 objdir dirs name items with
              | exception Failure m -> Error (f ^ ": " ^ m)
              | u -> Ok (List.map Ssa_build.func u.funcs))))
