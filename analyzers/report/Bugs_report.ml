(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Bugs_report.mli *)

module D = Datalog

let name = C_report.name

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
          Some (Printf.sprintf "%s: physeq: in %s, %s of %s made there: always %s" (Exn_report.site i)
                  (Ml_report.ml_function f) op what (if op = "==" then "false" else "true")))
      (tuples "always" 4) in
  let all = List.sort_uniq compare physeq in
  List.iter (fun b -> Console.print caps ("bug? " ^ b ^ "\n")) all;
  Console.print caps (Printf.sprintf "%d bugs? (physeq %d)\n" (List.length all) (List.length physeq))
