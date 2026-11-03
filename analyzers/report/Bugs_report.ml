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
  (* Main:try2@11: the try's line, its function, what may arrive *)
  let fn = Hashtbl.create 17 in
  List.iter (fun (t : string array) -> Hashtbl.replace fn t.(0) t.(1)) (tuples "try_in_function" 2);
  let errors = Hashtbl.create 17 in
  List.iter
    (fun (t : string array) ->
      let e = match C_report.prefix "caml_exn_" t.(1) with Some x -> x | None -> t.(1) in
      Hashtbl.replace errors t.(0) (e :: (match Hashtbl.find_opt errors t.(0) with Some l -> l | None -> [])))
    (tuples "swallowed" 2);
  let swallowed =
    Hashtbl.fold
      (fun (t : string) (es : string list) acc ->
        if not (own t) then acc
        else
          let line = match String.index_opt t '@' with Some i -> String.sub t (i + 1) (String.length t - i - 1) | None -> "?" in
          let f = match Hashtbl.find_opt fn t with Some f -> Ml_report.ml_function f | None -> "?" in
          Printf.sprintf "%s: swallowed: in %s, %s silenced, a constant answered" (site (unit_of t ^ ":" ^ line)) f
            (String.concat " or " (List.sort_uniq compare es))
          :: acc)
      errors [] in
  (* a program's own exception (Main.Error, not lib_core's Not_found)
   * caught by all, the handler raising another: a crash where it was
   * an error (exceptions.dl's ends_in) *)
  let raises = Hashtbl.create 17 in
  List.iter
    (fun (t : string array) ->
      let e = match C_report.prefix "caml_exn_" t.(1) with
        | Some x -> x
        | None -> t.(1) in
      let l = match Hashtbl.find_opt raises t.(0) with Some l -> l | None -> [] in
      Hashtbl.replace raises t.(0) (e :: l))
    (tuples "handler_raises" 2);
  let crash =
    List.filter_map
      (fun (t : string array) ->
        let tr = t.(0) and e = t.(1) in
        if not (own tr && Hashtbl.mem Ml_front.own (Exn_report.unit_of e)) then None
        else
          let f = match Hashtbl.find_opt fn tr with
            | Some f -> Ml_report.ml_function f
            | None -> "?" in
          let e2 = match Hashtbl.find_opt raises tr with
            | Some l -> String.concat " or " (List.sort_uniq compare l)
            | None -> "?" in
          Some (Printf.sprintf "%s: crash: in %s, %s caught by all, the handler raising %s"
                  (site (unit_of tr ^ ":" ^ Exn_report.try_line tr)) f e e2))
      (tuples "ends_in" 2) in
  let crash = List.sort_uniq compare crash in
  let all = List.sort_uniq compare (physeq @ stack @ swallowed @ crash) in
  List.iter (fun b -> Console.print caps ("bug? " ^ b ^ "\n")) all;
  Console.print caps
    (Printf.sprintf "%d bugs? (physeq %d, stack %d, swallowed %d, crash %d)\n"
       (List.length all) (List.length physeq) (List.length stack)
       (List.length swallowed) (List.length crash))

let raises_report (caps : < Cap.stdout; .. >) (p : D.t) : unit =
  let tuples r = List.map (fun (t : int array) -> Array.map (name p) t) (D.tuples (D.relation p r 3)) in
  let exn (e : string) : string = match C_report.prefix "caml_exn_" e with Some x -> x | None -> e in
  (* Sys.remove: Sys.ml, its unit's file *)
  let file (g : string) : string =
    let u = match String.index_opt g '.' with Some i -> String.sub g 0 i | None -> g in
    match Hashtbl.find_opt Ml_front.files u with Some f -> f | None -> u ^ ".ml" in
  let lines =
    List.map
      (fun (t : string array) ->
        Printf.sprintf "%s: raises: %s's C (%s) may raise %s, not said ([@@raise %s])" (file t.(0)) t.(0) t.(1)
          (exn t.(2)) (exn t.(2)))
      (tuples "undeclared")
    @ List.map
        (fun (t : string array) ->
          Printf.sprintf "%s: raises: %s says [@@raise %s], its C (%s) never raises it" (file t.(0)) t.(0)
            (exn t.(2)) t.(1))
        (tuples "overdeclared") in
  let lines = List.sort_uniq compare lines in
  List.iter (fun l -> Console.print caps ("bug? " ^ l ^ "\n")) lines;
  Console.print caps (Printf.sprintf "%d bugs? (raises %d)\n" (List.length lines) (List.length lines))
