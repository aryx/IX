(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Summaries derived from a facts file (mini-analyze -facts -no-models),
 * each function of the units named: its arity and ops, or why not; with
 * -models, Models.ml's beside, for those it has; with -o file, the
 * summaries written there (mini-analyze -summaries file reads them).
 * usage: Derive.exe facts-file unit... [-models] [-o file] *)

let () =
  let args = List.tl (Array.to_list Sys.argv) in
  let models = List.mem "-models" args in
  let rec out = function "-o" :: f :: _ -> Some f | _ :: r -> out r | [] -> None in
  let o = out args in
  let rec plain = function "-o" :: _ :: r -> plain r | "-models" :: r -> plain r | x :: r -> x :: plain r | [] -> [] in
  match plain args with
  | file :: units ->
      let facts = Summaries.parse (In_channel.with_open_bin file In_channel.input_all) in
      let all = Summaries.derive ~units facts in
      Option.iter
        (fun (f : string) ->
          let ok = List.filter_map (function g, Ok s -> Some (g, s) | _, Error _ -> None) all in
          Out_channel.with_open_bin f (fun oc -> output_string oc (Summaries.to_text ok)))
        o;
      List.iter
        (fun ((f, r) : string * (int * Summaries.op list, string) result) ->
          (match r with
           | Ok (n, ops) ->
               Printf.printf "%s (%d): %d ops\n" f n (List.length ops);
               List.iter (fun o -> Printf.printf "    %s\n" (Summaries.show o)) ops
           | Error why -> Printf.printf "%s: not summarized, %s\n" f why);
          if models then
            match Models.find f with
            | Some (n, ops) ->
                Printf.printf "  Models (%d): %d ops\n" n (List.length ops);
                List.iter (fun o -> Printf.printf "    %s\n" (Summaries.show o)) ops
            | None -> ())
        (List.sort compare all)
  | [] -> prerr_endline "usage: Derive.exe facts-file unit... [-models]"; exit 2
