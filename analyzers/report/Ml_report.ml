(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Ml_report.mli *)

module D = Datalog

let name (p : D.t) (i : int) : string = match p.terms.(i) with Prolog.Atom s -> s | Prolog.Int n -> string_of_int n | _ -> "?"

(* (not String.ends_with: mini-ml knows another unit's labels only by
 * its type given) *)
let ends_with (suffix : string) (s : string) : bool =
  let n = String.length suffix and m = String.length s in
  m >= n && String.sub s (m - n) n = suffix

let prefix (pre : string) (s : string) : string option =
  let n = String.length pre in
  if String.length s > n && String.sub s 0 n = pre then Some (String.sub s n (String.length s - n)) else None

(* an ML function as said: Use.f, a local Use:go/3 as go, a lambda
 * Use:fun1@11 as "Use:fun at line 11", an external prim:name *)
let rec ml_function (f : string) : string =
  (* (f' is f given its first argument: f for the reader) *)
  if String.length f > 1 && f.[String.length f - 1] = '\'' then ml_function (String.sub f 0 (String.length f - 1)) else
  match prefix "prim:" f with
  | Some x -> x ^ " (external)"
  | None -> (
      match String.index_opt f ':' with
      | None -> f
      | Some i -> (
          let u = String.sub f 0 i and rest = String.sub f (i + 1) (String.length f - i - 1) in
          match String.index_opt rest '@', String.index_opt rest '/' with
          | Some j, _ when prefix "fun" rest <> None -> Printf.sprintf "%s:fun at line %s" u (String.sub rest (j + 1) (String.length rest - j - 1))
          | _, Some j -> String.sub rest 0 j
          | _ -> rest))

(* the ML part: each call through a variable of the program's own
 * units, its targets; the program's functions its toplevel does not
 * reach (calls.dl's unreached) *)
let ml_report (caps : < Cap.stdout; .. >) (p : D.t) : unit =
  let tuples r = D.tuples (D.relation p r 2) in
  let edges = Hashtbl.create 101 and inside = Hashtbl.create 101 in
  List.iter (fun (t : int array) -> Hashtbl.add edges (name p t.(0)) (name p t.(1))) (tuples "call_edge");
  List.iter (fun (t : int array) -> Hashtbl.replace inside (name p t.(0)) (name p t.(1))) (tuples "in_function");
  let file u = match Hashtbl.find_opt Ml_front.files u with Some f -> f | None -> u in
  (* a temporary loaded from a field: h.on_key *)
  let loads = Hashtbl.create 101 in
  List.iter
    (fun (t : int array) ->
      let fld = name p t.(2) in
      Hashtbl.replace loads (name p t.(0)) (name p t.(1), match prefix "fld:" fld with Some x -> x | None -> fld))
    (D.tuples (D.relation p "assign_load_field" 3));
  let through v =
    match Hashtbl.find_opt loads v with
    | Some (x, fld) when String.contains x '/' -> Some (ml_function x ^ "." ^ fld)
    | Some _ -> None
    | None -> if String.contains v '/' then Some (ml_function v) else None in
  (* Use:11:c3: the unit and the line; a variable Use:h/4 *)
  let calls =
    List.filter_map
      (fun (t : int array) ->
        let i = name p t.(0) and v = name p t.(1) in
        match String.split_on_char ':' i, String.split_on_char ':' v with
        | [ u; line; _ ], [ _; _ ] when Hashtbl.mem Ml_front.own u -> (
            match through v with
            | Some v -> (
                let line = int_of_string line in
                let f = match Hashtbl.find_opt inside i with Some f -> ml_function f | None -> "?" in
                match List.sort_uniq compare (List.map ml_function (Hashtbl.find_all edges i)) with
                (* (a let rec's call of itself, its name a local) *)
                | [ t ] when t = v || ends_with ("." ^ v) t -> None
                | targets -> Some (file u, line, f, v, targets))
            | None -> None)
        | _ -> None)
      (tuples "call_indirect") in
  let calls = List.sort_uniq compare calls in
  List.iter
    (fun (file, line, f, v, targets) ->
      Console.print caps
        (Printf.sprintf "%s:%d: in %s, through %s: %s\n" file line f v
           (if targets = [] then "nothing found" else String.concat ", " targets)))
    calls;
  let lines = Hashtbl.create 101 in
  List.iter (fun (t : int array) -> Hashtbl.replace lines (name p t.(0)) (name p t.(1), name p t.(2))) (D.tuples (D.relation p "closure" 3));
  let unreached =
    List.filter_map
      (fun (t : int array) ->
        let f = name p t.(0) in
        match Hashtbl.find_opt lines f with
        | Some (u, l) when Hashtbl.mem Ml_front.own u -> Some (Printf.sprintf "never reached: %s (%s:%s)" (ml_function f) (file u) l)
        | _ -> None)
      (D.tuples (D.relation p "unreached" 1)) in
  List.iter (fun l -> Console.print caps (l ^ "\n")) (List.sort_uniq compare unreached);
  Console.print caps
    (Printf.sprintf "%d units (%d the program's), %d calls through a variable, %d functions never reached\n"
       (Hashtbl.length Ml_front.files) (Hashtbl.length Ml_front.own) (List.length calls) (List.length unreached))
