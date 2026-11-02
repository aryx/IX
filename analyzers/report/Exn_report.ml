(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Exn_report.mli *)

module D = Datalog

let name = C_report.name
let prefix = C_report.prefix

(* an exception as written: Main.Empty, Not_found (caml_exn_Not_found) *)
let exn (e : string) : string =
  match prefix "caml_exn_" e with Some x -> x | None -> if e = "?" then "an exception not known" else e

(* Main:11:r6: Main.ml:11 *)
let site (r : string) : string =
  match String.split_on_char ':' r with
  | u :: l :: _ ->
      let file = match Hashtbl.find_opt Ml_front.files u with Some f -> Filename.basename f | None -> u ^ ".ml" in
      file ^ ":" ^ l
  | _ -> r

let exn_report (caps : < Cap.stdout; .. >) (p : D.t) : unit =
  let tuples r = List.map (fun (t : int array) -> Array.map (name p) t) (D.tuples (D.relation p r 2)) in
  let inside = Hashtbl.create 101 in
  List.iter (fun t -> Hashtbl.replace inside t.(0) t.(1)) (tuples "raise_in");
  let raised = tuples "raised" in
  let unit_of (f : string) : string = match String.index_opt f ':' with Some i -> String.sub f 0 i | None -> f in
  List.iter
    (fun t ->
      let f = t.(0) and e = t.(1) in
      let u = unit_of f in
      if Hashtbl.mem Ml_front.own u then begin
        let file = match Hashtbl.find_opt Ml_front.files u with Some x -> Filename.basename x | None -> u in
        let at =
          List.sort_uniq compare
            (List.filter_map
               (fun r ->
                 if r.(0) <> e then None
                 else
                   let g = match Hashtbl.find_opt inside r.(1) with Some g -> " (" ^ Ml_report.ml_function g ^ ")" | None -> "" in
                   Some (site r.(1) ^ g))
               raised) in
        let at = if at = [] then "" else ", raised at " ^ String.concat ", " at in
        Console.print caps (Printf.sprintf "%s: the toplevel may let %s escape%s\n" file (exn e) at)
      end)
    (List.sort_uniq compare (tuples "uncaught"))
