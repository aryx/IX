(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Analyze.mli *)

module D = Datalog

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

let usage = "usage: mini-analyze [-r rules-dir] [-Idir] [-Dname=value] [-L lib] [-facts] [-dead] [-caps] [-root f]... file.c|file.ml...   (-h: how)"

let help = {|usage: mini-analyze [-r rules-dir] [-Idir] [-Dname=value] [-L lib] [-facts] [-dead] [-caps] [-root f]... file.c|file.ml...
The C files read as one program, each call through a pointer said with the
functions it may reach, by an analysis of where each pointer may point
(points_to/'s: Andersen's first pass, then a context file, -context):
  mini-analyze -r lib_code/datalog -I include prog/*.c
  walk.c:56: in walk, through f: hide, show
  main.c:76: in main, through table[]: show
and the bugs the same answers show (bugs.dl), each a "may":
  bug? bugs.c:65: in main, free may be given a string (line 64), not the heap's
  bug? bugs.c: scratch may return the address of tmp[], a local of scratch
The ML files the same, with the library's units they name (lib_core's, by
-L): each call of a function held in a variable, which functions it may
reach (Andersen's, by object: a closure is a pointer to a function), and the
program's functions that its toplevel never reaches (calls.dl):
  mini-analyze tests/ml/handlers/*.ml
  Events.ml:15: in Events:fun at line 15, through h.on_key: Events.beep, Main:fun at line 4
  Events.ml:17: in Events.twice, through f: Events.log
  never reached: Events.unused (Events.ml:19)
-dead: instead, what no run can reach (dead.dl), from main and the toplevels:
  dead.c:12: dead: unused, nothing names it
  dead.c:18: dead: hide, named only by dead code: unused
  dead.c:24: dead: orphan, in main but no call goes through the pointer
  dead.c:31: dead code: in main, after a return
-caps: instead, whether ML's own functions hold the capabilities they need
(capabilities.dl), from their types' < Cap.x; .. > and what they reach:
  Log.ml:5: Log.log: no capability, needs Cap.stdout (Pervasives.print_string)
  Fs.ml:9: Fs.get: has < Cap.stdout >, needs Cap.open_in|Cap.open_out (Unix.openfile)
  Run.ml:3: Run.go: has < Cap.fork; Cap.stdout >, may not need Cap.fork
-root f: f is also entered from where the facts do not go (assembly)
-context file: C's, of points_to/ (call1_heap1); the sharper, the longer
-library: every function may be called from outside, not main alone: a runtime
  ML calls, a library; without it what main does not reach is not looked at
-r: the directory of points_to/, bugs.dl, calls.dl, dead.dl (lib_code/datalog)
-I, -D: as mini-cc's; -L: lib_core's directory (lib_core); -facts: the facts
made, not the analysis|}

module C = Ix_analyze_c

(* An included file's lines take global lines: the file's own line is
 * the global one less where it began and less the lines of the files
 * it included before it. A stack of the files open at that point:
 * (name, its first global line, the lines its includes took) *)
let locate (hist : (string option * int) list) (l : int) : (string * int) option =
  let rec go stack = function
    | (Some f, at) :: rest when at <= l -> go ((f, at, 0) :: stack) rest
    | (None, at) :: rest when at <= l -> (
        match stack with
        | (_, s, _) :: (p, ps, pk) :: up -> go ((p, ps, pk + (at - s)) :: up) rest
        | _ -> go [] rest)
    | _ -> (match stack with (f, s, k) :: _ -> Some (f, l - s - k + 1) | [] -> None) in
  go [] hist

(* _in_walk_line_56_1: the function and the global line *)
let site (s : string) : (string * int) option =
  let rec last i = if i < 0 then None else if i + 6 <= String.length s && String.sub s i 6 = "_line_" then Some i else last (i - 1) in
  match last (String.length s - 6) with
  | Some i when String.length s > 4 && String.sub s 0 4 = "_in_" -> (
      let f = String.sub s 4 (i - 4) in
      let rest = String.sub s (i + 6) (String.length s - i - 6) in
      match String.index_opt rest '_' with
      | Some j -> Option.map (fun n -> (f, n)) (int_of_string_opt (String.sub rest 0 j))
      | None -> None)
  | _ -> None

(* walk__f: f; a temporary loaded from a member or an array, d->read or
 * devtab[] (the facts' assign_load_field and assign_array_elt, by the
 * temporary: what it was loaded from, what is said after it); another,
 * what the call computes *)
let rec through (loads : (string, string * string) Hashtbl.t) (f : string) (v : string) : string =
  let pre = f ^ "__" in
  let strip pre s = if String.length s > String.length pre && String.sub s 0 (String.length pre) = pre then Some (String.sub s (String.length pre) (String.length s - String.length pre)) else None in
  match Hashtbl.find_opt loads v, strip pre v with
  | Some (x, after), _ -> (match through loads f x with "a computed pointer" -> "(...)" | x -> x) ^ after
  | None, Some x when String.length x > 1 && x.[0] = 't' && String.for_all (fun c -> c >= '0' && c <= '9') (String.sub x 1 (String.length x - 1)) -> "a computed pointer"
  | None, Some x -> x
  | None, None -> v

let name (p : D.t) (i : int) : string = match p.terms.(i) with Prolog.Atom s -> s | Prolog.Int n -> string_of_int n | _ -> "?"

let prefix (pre : string) (s : string) : string option =
  let n = String.length pre in
  if String.length s > n && String.sub s 0 n = pre then Some (String.sub s n (String.length s - n)) else None

(* a place's kind, by Facts's names: an allocator's ('_malloc_in_f_line_N'),
 * a string's ('_str_in_...'), a function's own (f__x, its local or
 * parameter; '_array_elt_f__x', its local array's elements), and the
 * function; None: a global's *)
type place = Heap | Literal | Local of string * string | Global

let place (s : string) : place =
  (* f__x: the longest f that is a function read *)
  let local v =
    let rec go i =
      if i < 1 then None
      else if String.sub v i 2 = "__" && Hashtbl.mem C.C_front.owner (String.sub v 0 i) then
        Some (String.sub v 0 i, String.sub v (i + 2) (String.length v - i - 2))
      else go (i - 1) in
    go (String.length v - 3) in
  match prefix "_malloc_in_" s, prefix "_str_in_" s, prefix "_array_elt_" s with
  | _ when s = ".string" -> Literal
  | Some _, _, _ -> Heap
  | _, Some _, _ -> Literal
  | _, _, Some v -> (match local v with Some (f, x) -> Local (f, x ^ "[]") | None -> Global)
  | _ -> (match local s with Some (f, x) -> Local (f, x) | None -> Global)

(* the facts as Facts finds them, each a tuple of the relation, its
 * names Datalog's symbols: no text between them
 * (old: Facts.text () given to D.load, the text parsed again); and
 * bugs.dl's heap, local and literal of each name seen *)
let rec given (p : D.t) (relation : string) (args : C.Facts.arg list) : unit =
  let r = D.relation p relation (List.length args) in
  let value = function C.Facts.Sym s -> D.symbol p (Prolog.Atom s) | C.Facts.Num n -> D.symbol p (Prolog.Int n) in
  if D.add r (Array.of_list (List.map value args)) then begin
    r.given <- r.given + 1;
    List.iter
      (function
        | C.Facts.Sym s when relation <> "heap" && relation <> "local" && relation <> "literal" -> (
            match place s with
            | Heap -> given p "heap" [ Sym s ]
            | Literal -> given p "literal" [ Sym s ]
            | Local (f, _) -> given p "local" [ Sym s; Sym f ]
            | Global -> ())
        | _ -> ())
      args
  end

(* a function's global line, in its file *)
let where (f : string) (l : int) : string * int =
  match Hashtbl.find_opt C.C_front.owner f with
  | Some file -> (match locate (Hashtbl.find C.C_front.histories file) l with Some w -> w | None -> (file, l))
  | None -> ("?", l)

(* a place as the C says it *)
let said (s : string) : string =
  match place s with
  | Heap -> "what an allocator gave"
  | Literal when s = ".string" -> "a string (an initializer's)"
  | Literal -> (match site ("_in_" ^ Option.get (prefix "_str_in_" s) ^ "_0") with Some (f, l) -> Printf.sprintf "a string (line %d)" (snd (where f l)) | None -> "a string")
  | Local (f, x) -> Printf.sprintf "%s, a local of %s" x f
  | Global -> (match prefix "_array_elt_" s with Some v -> v ^ "[], a global" | None -> if Hashtbl.mem C.C_front.owner s then "the function " ^ s else s ^ ", a global")

(* the analysis on the facts: each call through a pointer, where, and
 * what it may reach; then what bugs.dl finds *)

let report (caps : < caps; .. >) (p : D.t) : unit =
  let tuples r = D.tuples (D.relation p r 2) in
  let loads = Hashtbl.create 101 in
  List.iter
    (fun (t : int array) ->
      let fld = name p t.(2) in
      let fld = if String.length fld > 6 && String.sub fld 0 6 = "_fld__" then String.sub fld 6 (String.length fld - 6) else fld in
      Hashtbl.replace loads (name p t.(0)) (name p t.(1), "->" ^ fld))
    (D.tuples (D.relation p "assign_load_field" 3));
  List.iter (fun (t : int array) -> Hashtbl.replace loads (name p t.(0)) (name p t.(1), "[]")) (tuples "assign_array_elt");
  let edges = Hashtbl.create 101 in
  List.iter (fun (t : int array) -> Hashtbl.add edges (name p t.(0)) (name p t.(1))) (tuples "target");
  (* (the calls in code that runs: what is not reached has no answers) *)
  let running = Hashtbl.create 101 in
  List.iter (fun (t : int array) -> Hashtbl.replace running (name p t.(0)) ()) (D.tuples (D.relation p "running" 3));
  let calls =
    List.filter_map
      (fun (t : int array) ->
        let s = name p t.(0) and v = name p t.(1) in
        match site s with
        | _ when not (Hashtbl.mem running s) -> None
        | None -> None
        | Some (f, l) ->
            let file, line = where f l in
            Some (file, line, f, through loads f v, List.sort_uniq compare (Hashtbl.find_all edges s)))
      (tuples "call_indirect") in
  let calls = List.sort_uniq compare calls in
  List.iter
    (fun (file, line, f, v, targets) ->
      Console.print caps
        (Printf.sprintf "%s:%d: in %s, through %s: %s\n" file line f v
           (if targets = [] then "nothing found" else String.concat ", " targets)))
    calls;
  (* a free's places together, a string's lines in one *)
  let frees = Hashtbl.create 17 in
  List.iter (fun (t : int array) -> Hashtbl.add frees (name p t.(0)) (name p t.(1))) (tuples "bad_free");
  let sites = List.sort_uniq compare (Hashtbl.fold (fun i _ acc -> i :: acc) frees []) in
  let bugs =
    List.filter_map
      (fun (i : string) ->
        match site i with
        | Some (f, l) ->
            let file, line = where f l in
            let places = List.sort_uniq compare (List.map said (Hashtbl.find_all frees i)) in
            let strings, others = List.partition (fun x -> prefix "a string" x <> None) places in
            let strings =
              match strings with
              | [] -> []
              | [ x ] -> [ x ]
              | xs ->
                  let line x = Option.bind (prefix "a string (line " x) (fun n -> int_of_string_opt (String.sub n 0 (String.length n - 1))) in
                  let lines = List.sort compare (List.filter_map line xs) in
                  [ Printf.sprintf "%d strings (%slines %s)" (List.length xs)
                      (if List.length lines < List.length xs then "an initializer's, " else "")
                      (String.concat ", " (List.map string_of_int lines)) ] in
            Some (Printf.sprintf "%s:%d: in %s, free may be given %s, not the heap's" file line f (String.concat "; " (others @ strings)))
        | None -> None)
      sites
    @ List.map
        (fun (t : int array) ->
          let f = name p t.(0) in
          let file = match Hashtbl.find_opt C.C_front.owner f with Some file -> file | None -> "?" in
          Printf.sprintf "%s: %s may return the address of %s" file f (said (name p t.(1))))
        (tuples "dangling") in
  List.iter (fun b -> Console.print caps ("bug? " ^ b ^ "\n")) (List.sort_uniq compare bugs);
  Console.print caps
    (Printf.sprintf "%d functions, %d calls through a pointer, %d of them reaching nothing; %d bugs?\n"
       (Hashtbl.length C.C_front.owner) (List.length calls)
       (List.length (List.filter (fun (_, _, _, _, t) -> t = []) calls))
       (List.length (List.sort_uniq compare bugs)))

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
let ml_report (caps : < caps; .. >) (p : D.t) : unit =
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
      Hashtbl.replace loads (name p t.(0)) (name p t.(1), Option.value (prefix "fld:" fld) ~default:fld))
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
                | [ t ] when t = v || String.ends_with ~suffix:("." ^ v) t -> None
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

(* -dead: what dead.dl finds, each with where it is written *)
let dead_report (caps : < caps; .. >) (p : D.t) (ml : bool) : unit =
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
    | None -> ((if ml then file_of (unit_of f) else match Hashtbl.find_opt C.C_front.owner f with Some x -> x | None -> "?"), 0) in
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
      (fun c g -> Printf.sprintf "never built: %s, matched in %s" (Option.value (prefix "con:" c) ~default:c) g)
      (fun c -> prefix "con:" c <> None) in
  let all = functions @ globals @ stmts @ fields @ constructors in
  List.iter (fun x -> Console.print caps (one x ^ "\n")) (List.sort_uniq compare all);
  Console.print caps
    (Printf.sprintf "%d functions dead (%d nothing names), %d only through a pointer; %d globals, %d fields, %d constructors, %d statements\n"
       (List.length dead) (List.length (List.filter is_own unnamed)) (List.length (tuples "through_pointer" 1))
       (List.length globals) (List.length fields) (List.length constructors) (List.length stmts))

(* -caps: what capabilities.dl finds, a line a function: what it holds, what is
 * missing and by what, what it holds for nothing *)
let caps_report (caps : < caps; .. >) (p : D.t) : unit =
  let tuples r n = List.map (fun (t : int array) -> Array.map (name p) t) (D.tuples (D.relation p r n)) in
  let file_of u = match Hashtbl.find_opt Ml_front.files u with Some f -> f | None -> u in
  let lines = Hashtbl.create 101 in
  List.iter (fun t -> Hashtbl.replace lines t.(0) (file_of t.(1), int_of_string t.(2))) (tuples "closure" 3);
  let at (o : string) : string * int =
    match Hashtbl.find_opt lines o with
    | Some w -> w
    | None -> (file_of (String.sub o 0 (String.index o ':')), 0) in
  let requires = tuples "requires" 2 in
  (* Cap.open_in|Cap.open_out: what allows S *)
  let need (s : string) : string =
    String.concat "|"
      (List.sort compare (List.filter_map (fun t -> if t.(0) = s then Some ("Cap." ^ t.(1)) else None) requires)) in
  let held (o : string) : string list =
    List.sort_uniq compare
      (List.filter_map (fun t -> if t.(0) = o then Some ("Cap." ^ t.(1)) else None) (tuples "declared_by" 2)) in
  (* one function's needs, each with the ways: Cap.stdout (Pervasives.print_string) *)
  let needs (r : string array list) (o : string) : string =
    let mine = List.filter (fun t -> t.(0) = o) r in
    let by_need =
      List.sort_uniq compare (List.map (fun t -> need t.(1)) mine)
      |> List.map (fun n ->
             let ways =
               List.sort_uniq compare
                 (List.filter_map
                    (fun t ->
                      if need t.(1) <> n then None
                      else if t.(2) <> "itself" then Some (ml_function t.(2))
                      else match prefix "prim:" t.(1) with Some x -> Some x | None -> Some t.(1))
                    mine) in
             Printf.sprintf "%s (%s)" n (String.concat ", " ways)) in
    String.concat ", " by_need in
  let functions r = List.sort_uniq compare (List.map (fun t -> t.(0)) r) in
  let none = tuples "no_cap" 3 and wrong = tuples "wrong_cap" 3 and unused = tuples "unused_cap" 2 in
  (* a function a line *)
  let report =
    List.map
      (fun o ->
        let f, l = at o in
        let unneeded = List.sort compare (List.filter_map (fun t -> if t.(0) = o then Some ("Cap." ^ t.(1)) else None) unused) in
        let says =
          (if List.exists (fun t -> t.(0) = o) none then [ "no capability, needs " ^ needs none o ] else [])
          @ (if List.exists (fun t -> t.(0) = o) wrong then [ "needs " ^ needs wrong o ] else [])
          @ if unneeded = [] then [] else [ "may not need " ^ String.concat ", " unneeded ] in
        let has = match held o with [] -> "" | h -> Printf.sprintf "has < %s >, " (String.concat "; " h) in
        (f, l, Printf.sprintf "%s: %s%s" (ml_function o) has (String.concat "; " says)))
      (functions (none @ wrong @ List.map (fun t -> [| t.(0) |]) unused)) in
  List.iter
    (fun (f, l, msg) -> Console.print caps (if l > 0 then Printf.sprintf "%s:%d: %s\n" f l msg else Printf.sprintf "%s: %s\n" f msg))
    (List.sort compare report);
  (* what is asked for most: where to start *)
  let counts = Hashtbl.create 17 in
  List.iter
    (fun t ->
      let n = need t.(1) in
      Hashtbl.replace counts n ((try Hashtbl.find counts n with Not_found -> []) @ [ t.(0) ]))
    (none @ wrong);
  let by_cap =
    Hashtbl.fold (fun n os acc -> (List.length (List.sort_uniq compare os), n) :: acc) counts []
    |> List.sort (fun a b -> compare b a)
    |> List.map (fun (k, n) -> Printf.sprintf "%s %d" n k) in
  Console.print caps
    (Printf.sprintf "%d functions with no capability, %d with the wrong one, %d with one they may not need%s\n"
       (List.length (functions none)) (List.length (functions wrong)) (List.length (functions unused))
       (if by_cap = [] then "" else "; missing: " ^ String.concat ", " by_cap))

(* a fact as a line, for -facts *)
let line (relation : string) (args : C.Facts.arg list) : string =
  let show = function C.Facts.Sym s -> "'" ^ String.concat "\\'" (String.split_on_char '\'' s) ^ "'" | C.Facts.Num n -> string_of_int n in
  relation ^ "(" ^ String.concat ", " (List.map show args) ^ ")."

let main (caps : < caps; .. >) (argv : string array) : int =
  let rules = ref "lib_code/datalog" and lib = ref "lib_core" and only = ref false and incs = ref [] and defs = ref [] and files = ref [] in
  let dead = ref false and ambient = ref false and roots = ref [] and context = ref "call1_heap1" and library = ref false in
  let options =
    Logging.flags
    @ [ ("-r", Arg.Set_string rules, " the directory of points_to/ and bugs.dl");
        ("-facts", Arg.Set only, " the facts, not the analysis");
        ("-dead", Arg.Set dead, " what no run can reach, not the calls and the bugs");
        ("-caps", Arg.Set ambient, " whether ML's own functions hold the capabilities they need");
        ("-root", Arg.String (fun f -> roots := f :: !roots), " a function entered from where the facts do not go");
        ("-context", Arg.Set_string context, " C: the context file of points_to/ (call1_heap1)");
        ("-library", Arg.Set library, " every function may be called from outside: a runtime, a library");
        ("-L", Arg.Set_string lib, " lib_core's directory, for an ML program's library");
        ("-I", Arg.String (fun d -> incs := d :: !incs), " a directory of #include's");
        ("-D", Arg.String (fun d -> defs := d :: !defs), " name=value, as #define") ] in
  (* (-Idir and -Dx in one word too, as mini-cc's) *)
  let split a =
    if String.length a > 2 && (String.sub a 0 2 = "-I" || String.sub a 0 2 = "-D") then [ String.sub a 0 2; String.sub a 2 (String.length a - 2) ]
    else [ a ] in
  let argv = Array.of_list (List.concat_map split (Array.to_list argv)) in
  match Arg.parse_argv argv options (fun (f : string) -> files := f :: !files) usage with
  | exception Arg.Help _ -> Console.print caps (help ^ "\n"); 0
  | exception Arg.Bad msg -> Console.eprint caps msg; 1
  | () -> (
      let path s = match FS.path s with Ok p -> p | Error m -> failwith m in
      try
        if !files = [] then failwith usage;
        let incs = List.map path (List.rev !incs) in
        let failed = ref 0 in
        let p = D.create () in
        let ml, c = List.partition (fun f -> Filename.check_suffix f ".ml") (List.rev !files) in
        let text = Buffer.create 4096 in
        let fact = if !only then (fun r args -> Buffer.add_string text (line r args ^ "\n")) else given p in
        if not !only then
          List.iter
            (fun (r : string) ->
              let rules = Fpath.append (path !rules) (Fpath.v r) in
              D.load p ~from:(Fpath.to_string rules) (FS.read caps rules))
            (if !dead || !ambient then
               [ "points_to/instructions.dl"; "points_to/contexts.dl"; "points_to/insensitive.dl"; "dead.dl" ]
               @ if !ambient then [ "capabilities.dl" ] else []
             else
               [ "points_to/instructions.dl"; "points_to/andersen.dl" ]
               @ (if c <> [] then [ "points_to/contexts.dl"; "points_to/" ^ !context ^ ".dl"; "bugs.dl" ] else [])
               @ if ml <> [] then [ "calls.dl" ] else []);
        List.iter (fun (f : string) -> given p "entry" [ C.Facts.Sym f ]) !roots;
        if !library then D.load p ~from:"-library" "entry(F) :- function(F).\n";
        C.Facts.added := fact;
        Closure_facts.added :=
          (fun r args -> fact r (List.map (function Closure_facts.Sym s -> C.Facts.Sym s | Closure_facts.Num n -> C.Facts.Num n) args));
        List.iter
          (fun (f : string) ->
            Logs.info (fun m -> m "reading %s" f);
            match C.C_front.file caps (List.rev !defs, incs) (path f) with
            | Ok () -> ()
            | Error m -> Console.eprint caps (m ^ "\n"); incr failed)
          c;
        if ml <> [] then
          List.iter (fun m -> Console.eprint caps (m ^ "\n"); incr failed) (Ml_front.program caps (incs @ Ml_front.library caps !lib) (List.map path ml));
        (* (what they call would be reported dead) *)
        if !dead || !ambient then List.iter (fun m -> Console.eprint caps ("not read: " ^ m ^ "\n"); incr failed) !Ml_front.unread;
        if !ambient then
          Hashtbl.iter (fun u () -> given p "own_unit" [ C.Facts.Sym u ]; given p "own_init" [ C.Facts.Sym (u ^ ":init") ]) Ml_front.own;
        if !only then Console.print caps (Buffer.contents text)
        else begin
          ignore (Datalog_eval.run ~naive:false p);
          if !ambient then caps_report caps p
          else if !dead then dead_report caps p (ml <> [])
          else begin
            if c <> [] then report caps p;
            if ml <> [] then ml_report caps p
          end
        end;
        if !failed > 0 then 1 else 0
      with
      | D.Error (msg, at) -> Console.eprint caps (Printf.sprintf "%s: %s\n" at msg); 1
      | Failure msg | Sys_error msg -> Console.eprint caps (msg ^ "\n"); 1)
