(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Bugs_report.mli *)

module D = Datalog

let name = C_report.name

(* Main:11:c6: its file as given, and the line (Exn_report.site's, the
 * file's name alone: two Opti.ml in ix) *)
let site (r : string) : string =
  match String.split_on_char ':' r with
  | u :: l :: _ -> (match Hashtbl.find_opt Ml_front.files u with Some f -> f | None -> u ^ ".ml") ^ ":" ^ l
  | _ -> r

let bugs_report (caps : < Cap.stdout; .. >) (p : D.t) : unit =
  let tuples r n = List.map (fun (t : int array) -> Array.map (name p) t) (D.tuples (D.relation p r n)) in
  let unit_of (s : string) : string = match String.index_opt s ':' with Some i -> String.sub s 0 i | None -> s in
  let physeq =
    List.filter_map
      (fun (t : string array) ->
        let i = t.(0) and f = t.(1) and op = t.(2) and what = t.(3) in
        if not (Hashtbl.mem Ml_front.own (unit_of i)) then None
        else
          let what = if what.[0] >= 'A' && what.[0] <= 'Z' then "a " ^ what else what in
          Some (Printf.sprintf "%s: physeq: in %s, %s of %s made there: always %s" (site i)
                  (Ml_report.ml_function f) op what (if op = "==" then "false" else "true")))
      (tuples "always" 4) in
  let handlers = Hashtbl.create 17 in
  List.iter (fun (t : string array) -> Hashtbl.replace handlers t.(0) ()) (tuples "in_handler" 2);
  let own (i : string) : bool = Hashtbl.mem Ml_front.own (unit_of i) in
  let in_try =
    List.filter_map
      (fun (t : string array) ->
        let i = t.(0) and f = Ml_report.ml_function t.(1) in
        if not (own i) then None
        else
          Some (Printf.sprintf "%s: stack: %s calls itself in a try's %s: no tail call by mini-ml" (site i)
                  f (if Hashtbl.mem handlers i then "handler" else "body")))
      (tuples "in_try_rec" 3) in
  let on_list =
    List.filter_map
      (fun (t : string array) ->
        let i = t.(0) and f = Ml_report.ml_function t.(1) in
        if not (own i) then None
        else Some (Printf.sprintf "%s: stack: %s calls itself, not a tail call, over a list" (site i) f))
      (tuples "on_list" 2) in
  let stack = List.sort_uniq compare (in_try @ on_list) in
  let all = List.sort_uniq compare (physeq @ stack) in
  List.iter (fun b -> Console.print caps ("bug? " ^ b ^ "\n")) all;
  Console.print caps
    (Printf.sprintf "%d bugs? (physeq %d, stack %d)\n" (List.length all) (List.length physeq) (List.length stack))
