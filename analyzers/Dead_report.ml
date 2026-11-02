(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Dead_report.mli *)

module D = Datalog

let name = C_report.name
let prefix = C_report.prefix
let where = C_report.where
let ml_function = Ml_report.ml_function

(* -dead: what dead.dl finds, each with where it is written *)
let dead_report (caps : < Cap.stdout; .. >) (p : D.t) (ml : bool) : unit =
  let tuples r n = List.map (fun (t : int array) -> Array.map (name p) t) (D.tuples (D.relation p r n)) in
  let unit_of (f : string) : string =
    let stop c = match String.index_opt f c with Some i -> i | None -> String.length f in
    String.sub f 0 (min (stop ':') (stop '.')) in
  let is_own (f : string) : bool = (not ml) || Hashtbl.mem Ml_front.own (unit_of f) in
  let file_of u = match Hashtbl.find_opt Ml_front.files u with Some f -> f | None -> u in
  let shown (f : string) : string = if ml then ml_function f else f in
  let lines = Hashtbl.create 101 in
  List.iter (fun t -> Hashtbl.replace lines t.(0) (file_of t.(1), int_of_string t.(2))) (tuples "closure" 3);
  List.iter
    (fun t ->
      let f = t.(0) in
      Hashtbl.replace lines f (match where f (int_of_string t.(1)) with (file, _) when t.(1) = "0" -> (file, 0) | w -> w))
    (tuples "defined" 2);
  let at (f : string) : string * int =
    match Hashtbl.find_opt lines f with
    | Some w -> w
    | None -> ((if ml then file_of (unit_of f) else match Hashtbl.find_opt C_front.owner f with Some x -> x | None -> "?"), 0) in
  let one (f, l, msg) =
    if f = "?" then msg else if l > 0 then Printf.sprintf "%s:%d: %s" f l msg else Printf.sprintf "%s: %s" f msg in
  let names r n f = List.sort_uniq compare (List.filter_map (fun t -> if t.(0) = f then Some (shown t.(1)) else None) (tuples r n)) in
  let unnamed = List.map (fun t -> t.(0)) (tuples "never_named" 1) in
  let dead = List.filter is_own (List.map (fun t -> t.(0)) (tuples "dead" 1)) in
  let functions =
    List.map
      (fun f ->
        let file, l = at f in
        let why =
          if List.mem f unnamed then "nothing names it"
          else match names "named_in_live" 2 f with
            | [] -> "named only by dead code: " ^ String.concat ", " (names "named_in_dead" 2 f)
            | g -> "in " ^ String.concat ", " g ^ " but no call goes through the pointer" in
        (file, l, Printf.sprintf "dead: %s, %s" (shown f) why))
      dead in
  let globals =
    List.filter_map
      (fun t ->
        let g = t.(0) in
        if not (is_own g) then None else
        let file, l = at g in
        Some (file, l, Printf.sprintf "dead global: %s, nothing live names it" (shown g)))
      (tuples "dead_global" 1) in
  let stmts =
    List.map
      (fun t ->
        let file, l = where t.(0) (int_of_string t.(1)) in
        (file, l, Printf.sprintf "dead code: in %s, after a jump" t.(0)))
      (tuples "dead_stmt" 2) in
  let field (f : string) : string option =
    match prefix "_fld__" f, prefix "fld:" f with Some x, _ | _, Some x -> Some x | None, None -> None in
  (* a field or a constructor once, at its first place *)
  let by_function (r : string) (msg : string -> string -> string) keep =
    let seen = Hashtbl.create 17 in
    List.filter_map
      (fun t ->
        if is_own t.(1) && keep t.(0) && not (Hashtbl.mem seen t.(0)) then begin
          Hashtbl.add seen t.(0) ();
          let file, l = at t.(1) in
          Some (file, l, msg t.(0) (shown t.(1)))
        end
        else None)
      (List.sort compare (tuples r 2)) in
  let fields =
    by_function "dead_field"
      (fun f g -> Printf.sprintf "dead field: %s stored in %s, nothing live reads it" (Option.get (field f)) g)
      (fun f -> field f <> None) in
  let constructors =
    by_function "never_built"
      (fun c g -> Printf.sprintf "never built: %s, matched in %s" (match prefix "con:" c with Some x -> x | None -> c) g)
      (fun c -> prefix "con:" c <> None) in
  let all = functions @ globals @ stmts @ fields @ constructors in
  List.iter (fun x -> Console.print caps (one x ^ "\n")) (List.sort_uniq compare all);
  Console.print caps
    (Printf.sprintf "%d functions dead (%d nothing names), %d only through a pointer; %d globals, %d fields, %d constructors, %d statements\n"
       (List.length dead) (List.length (List.filter is_own unnamed)) (List.length (tuples "through_pointer" 1))
       (List.length globals) (List.length fields) (List.length constructors) (List.length stmts))
