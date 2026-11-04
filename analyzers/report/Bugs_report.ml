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
  (* a cache's identity of a value changed in place: a line a comparison,
   * the first object (where it is made) *)
  let stale = Hashtbl.create 17 in
  List.iter
    (fun (t : string array) ->
      if Hashtbl.mem Ml_front.own (unit_of t.(0)) then begin
        let l = match Hashtbl.find_opt stale (t.(0), t.(1)) with Some l -> l | None -> [] in
        Hashtbl.replace stale (t.(0), t.(1)) (t.(2) :: l)
      end)
    (tuples "stale" 3);
  let physeq =
    physeq
    @ Hashtbl.fold
        (fun ((i, f) : string * string) (hs : string list) acc ->
          let h = List.hd (List.sort compare hs) in
          (* (Before:block1@11: made at line 11) *)
          let h =
            match String.index_opt h '@', String.index_opt h ':' with
            | Some a, Some c -> String.sub h 0 c ^ ":" ^ String.sub h (a + 1) (String.length h - a - 1)
            | _ -> h in
          Printf.sprintf
            "%s: physeq: in %s, a kept value compared by identity with one \
             changed in place (%s): its change not seen"
            (site i) (Ml_report.ml_function f) (site h)
          :: acc)
        stale [] in
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
  (* an int of 63 bits in code for the Pi 1 too (intwidth.dl): a line a
   * function, at its first, a table of constants one report *)
  let by_fun = Hashtbl.create 17 in
  List.iter
    (fun (t : string array) ->
      let s = t.(0) in
      if own s then begin
        let line = match String.split_on_char ':' s with _ :: l :: _ -> int_of_string l | _ -> 0 in
        let l = match Hashtbl.find_opt by_fun (t.(1), t.(2)) with Some l -> l | None -> [] in
        Hashtbl.replace by_fun (t.(1), t.(2)) ((line, s, t.(3)) :: l)
      end)
    (tuples "int31" 4);
  let int31 =
    Hashtbl.fold
      (fun ((u, f) : string * string) (l : (int * string * string) list) acc ->
        let l = List.sort_uniq compare l in
        let f = if Filename.check_suffix f ":init" then u ^ "'s toplevel" else Ml_report.ml_function f in
        let _, s, _ = List.hd l in
        (* (as written, each once) *)
        let ws =
          List.fold_left (fun acc ((_, _, w) : int * string * string) -> if List.mem w acc then acc else acc @ [ w ]) [] l in
        let n = List.length ws in
        let shown = String.concat "; " (List.filteri (fun k _ -> k < 3) ws) in
        let more = if n > 3 then Printf.sprintf " and %d more" (n - 3) else "" in
        Printf.sprintf "%s: int31: in %s, %s%s: not on the Pi 1's 31 bits" (site s) f shown more :: acc)
      by_fun [] in
  (* a table's order given to an output (order.dl): a line a walk, the
   * outputs it reaches; a Marshal sharing what the compiler shared *)
  let outs = Hashtbl.create 17 in
  List.iter
    (fun (t : string array) ->
      let l = match Hashtbl.find_opt outs t.(0) with Some l -> l | None -> [] in
      Hashtbl.replace outs t.(0) (t.(1) :: l))
    (tuples "order_out" 2);
  let walk_fn = Hashtbl.create 17 in
  List.iter (fun (t : string array) -> Hashtbl.replace walk_fn t.(0) t.(1))
    (tuples "in_function" 2);
  let fun_of (u : string) (f : string) : string =
    if Filename.check_suffix f ":init" then u ^ "'s toplevel"
    else Ml_report.ml_function f in
  let order =
    Hashtbl.fold
      (fun (s0 : string) (is : string list) acc ->
        if not (own s0) then acc
        else
          let f =
            (* (the closure's call, S0:call1, is in the walk's function) *)
            match Hashtbl.find_opt walk_fn (s0 ^ ":call1") with
            | Some f -> fun_of (unit_of s0) f
            | None -> "?" in
          let is = List.sort_uniq compare (List.map site is) in
          let n = List.length is in
          let shown = String.concat ", " (List.filteri (fun k _ -> k < 3) is) in
          let more = if n > 3 then Printf.sprintf " and %d more" (n - 3) else "" in
          Printf.sprintf "%s: order: in %s, a table's order reaches the output at %s%s"
            (site s0) f shown more
          :: acc)
      outs [] in
  let sharing =
    List.filter_map
      (fun (t : string array) ->
        if not (own t.(0)) then None
        else
          Some
            (Printf.sprintf "%s: sharing: in %s, Marshal without No_sharing: its bytes the compiler's"
               (site t.(0)) (fun_of (unit_of t.(0)) t.(1))))
      (tuples "shared" 2) in
  (* a start reading what a later one makes (init.dl): a line a pair of
   * units, the first global; two files of one unit's name *)
  let reads = Hashtbl.create 17 in
  List.iter
    (fun (t : string array) ->
      let i = t.(0) and j = t.(3) in
      if own i then begin
        let l = match Hashtbl.find_opt reads (i, j) with Some l -> l | None -> [] in
        Hashtbl.replace reads (i, j) ((t.(1), t.(2)) :: l)
      end)
    (tuples "early" 4);
  let init =
    Hashtbl.fold
      (fun ((i, j) : string * string) (l : (string * string) list) acc ->
        let u = unit_of i and v = unit_of j in
        let g, f = List.hd (List.sort compare l) in
        let n = List.length (List.sort_uniq compare (List.map fst l)) in
        let more = if n > 1 then Printf.sprintf " and %d more" (n - 1) else "" in
        let file =
          match Hashtbl.find_opt Ml_front.files u with Some f -> f | None -> u ^ ".ml" in
        Printf.sprintf "%s: init: %s's start reads %s%s (in %s), %s starting after it"
          file u g more (fun_of u f) v
        :: acc)
      reads [] in
  let link =
    List.filter_map
      (fun (t : string array) ->
        if t.(1) < t.(2) then
          Some
            (Printf.sprintf "%s: link: two units %s, %s and %s: which one is linked the build's"
               t.(1) t.(0) t.(1) t.(2))
        else None)
      (tuples "twice" 3) in
  (* a write of a root's racing another (races.dl): a line a function
   * of the root and a field, its first other writer; a wait not in a
   * loop. A function's line is its closure's (f' is f's) *)
  let lines = Hashtbl.create 17 in
  List.iter
    (fun (t : string array) -> Hashtbl.replace lines t.(0) (t.(1) ^ ":" ^ t.(2)))
    (tuples "closure" 3);
  let rec line_of (f : string) : string =
    match Hashtbl.find_opt lines f with
    | Some l -> site l
    | None ->
        let n = String.length f in
        if n > 0 && f.[n - 1] = '\'' then line_of (String.sub f 0 (n - 1))
        else unit_of f ^ ".ml" in
  let htypes = Hashtbl.create 17 in
  List.iter (fun (t : string array) -> Hashtbl.replace htypes t.(0) t.(1))
    (tuples "htype" 2);
  (* (a record's fields named, a ref, an array, a table by where made) *)
  let written (h : string) (flds : string list) : string =
    let labels = List.filter_map (C_report.prefix "fld:") flds in
    match flds with
    | [ "fld:contents" ] -> "the ref of " ^ site h
    | _ when labels <> [] && not (List.mem "contents" labels) ->
        let t =
          match Hashtbl.find_opt htypes h with Some t -> t | None -> "record" in
        Printf.sprintf "a %s's %s" t (String.concat " and " labels)
    | [ "arr:elt" ] -> "the array of " ^ site h
    | _ when List.for_all (fun f -> C_report.prefix "tbl:" f <> None) flds ->
        "the table of " ^ site h
    | _ -> Printf.sprintf "%s of %s" (String.concat " and " flds) (site h) in
  let writers = Hashtbl.create 17 in
  List.iter
    (fun (t : string array) ->
      let k = (t.(2), t.(3), t.(0)) in
      let l = match Hashtbl.find_opt writers k with Some l -> l | None -> [] in
      Hashtbl.replace writers k ((t.(1), t.(4)) :: l))
    (tuples "raced" 5);
  let race =
    Hashtbl.fold
      (fun ((f1, r, h) : string * string * string) (l : (string * string) list)
           acc ->
        let flds = List.sort_uniq compare (List.map fst l) in
        let fs = List.sort_uniq compare (List.map snd l) in
        let n = List.length fs in
        let shown = List.filteri (fun k _ -> k < 2) fs in
        let others =
          String.concat ", " (List.map (fun f -> fun_of (unit_of f) f) shown)
          ^ (if n > 2 then Printf.sprintf " and %d more" (n - 2) else "") in
        Printf.sprintf
          "%s: race: %s, run by a signal's handler (%s), writes %s, as %s does"
          (line_of f1) (fun_of (unit_of f1) f1) (line_of r) (written h flds)
          others
        :: acc)
      writers [] in
  let wait =
    List.map
      (fun (t : string array) ->
        Printf.sprintf
          "%s: wait: in %s, Condition.wait not in a while: woken for another, \
           it goes on"
          (site t.(0)) (fun_of (unit_of t.(0)) t.(1)))
      (tuples "wait_once" 2) in
  (* a resource not given back when a call between raises (pairs.dl): a
   * line a call taking it, its first such call and exception *)
  let leaks = Hashtbl.create 17 in
  List.iter
    (fun (t : string array) ->
      let l = match Hashtbl.find_opt leaks t.(0) with Some l -> l | None -> [] in
      Hashtbl.replace leaks t.(0) ((t.(1), t.(3), t.(2)) :: l))
    (tuples "leak" 4);
  let exn_name (e : string) : string =
    match C_report.prefix "caml_exn_" e with Some x -> x | None -> e in
  let leak =
    Hashtbl.fold
      (fun (a : string) (l : (string * string * string) list) acc ->
        if not (own a) then acc
        else
          let l = List.sort compare l in
          let c, e, r = List.hd l in
          let n = List.length (List.sort_uniq compare (List.map (fun (c, _, _) -> c) l)) in
          let more = if n > 1 then Printf.sprintf " (and %d more calls)" (n - 1) else "" in
          let f = match Hashtbl.find_opt walk_fn a with Some f -> fun_of (unit_of a) f | None -> "?" in
          Printf.sprintf "%s: leak: in %s, taken here, given back at %s, not when %s raises %s%s"
            (site a) f (site r) (site c) (exn_name e) more
          :: acc)
      leaks [] in
  (* a variable never read (unused.dl): Main:x/12, x *)
  let unused =
    List.filter_map
      (fun (t : string array) ->
        let f = t.(0) and v = t.(1) in
        (* (the variable's unit: Before:b/12; a function is Before.first) *)
        if not (own v) then None
        else
          let name =
            match String.index_opt v ':', String.rindex_opt v '/' with
            | Some a, Some z when z > a -> String.sub v (a + 1) (z - a - 1)
            | _ -> v in
          Some
            (Printf.sprintf "%s: unused: in %s, %s is never read (_%s if meant)"
               (line_of f) (fun_of (unit_of f) f) name name))
      (tuples "unused_var" 2) in
  let unused = List.sort_uniq compare unused in
  (* a statement laid out in an if's branch, run after it (layout.dl) *)
  let layout =
    List.filter_map
      (fun (t : string array) ->
        let u = unit_of t.(0) in
        if not (Hashtbl.mem Ml_front.own u) then None
        else
          Some
            (Printf.sprintf
               "%s: layout: in the column of the if's branch above, not in it: run whatever the test"
               (site (u ^ ":" ^ t.(3)))))
      (tuples "dangling" 4) in
  let layout = List.sort_uniq compare layout in
  (* inside a function that gives back its argument, a raise before it
   * does (pairs.dl's leak_in): a line a call *)
  let leak =
    leak
    @ List.filter_map
        (fun (t : string array) ->
          let f = t.(0) and c = t.(1) and r = t.(2) in
          if not (own c) then None
          else
            Some
              (Printf.sprintf "%s: leak: in %s, its argument given back at %s, not when this raises %s"
                 (site c) (fun_of (unit_of c) f) (site r) (exn_name t.(3))))
        (tuples "leak_in" 4) in
  let order = List.sort_uniq compare order in
  let sharing = List.sort_uniq compare sharing in
  let race = List.sort_uniq compare race and wait = List.sort_uniq compare wait in
  let all =
    List.sort_uniq compare
      (physeq @ stack @ swallowed @ crash @ int31 @ order @ sharing @ init @ link
       @ race @ wait @ leak @ unused @ layout) in
  List.iter (fun b -> Console.print caps ("bug? " ^ b ^ "\n")) all;
  (* (the analyses that report, by their number: within 80 columns) *)
  let counts =
    List.filter_map
      (fun ((k, l) : string * string list) ->
        if l = [] then None else Some (Printf.sprintf "%s %d" k (List.length l)))
      [ ("physeq", physeq); ("stack", stack); ("swallowed", swallowed);
        ("crash", crash); ("int31", int31); ("order", order);
        ("sharing", sharing); ("init", init); ("link", link); ("race", race);
        ("wait", wait); ("leak", leak); ("unused", unused);
        ("layout", layout) ] in
  Console.print caps
    (Printf.sprintf "%d bugs?%s\n" (List.length all)
       (if counts = [] then "" else " (" ^ String.concat ", " counts ^ ")"))

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
