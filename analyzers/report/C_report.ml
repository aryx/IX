(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See C_report.mli *)

module D = Datalog

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
      else if String.sub v i 2 = "__" && Hashtbl.mem C_front.owner (String.sub v 0 i) then
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
let rec given (p : D.t) (relation : string) (args : Facts.arg list) : unit =
  let r = D.relation p relation (List.length args) in
  let value = function Facts.Sym s -> D.symbol p (Prolog.Atom s) | Facts.Num n -> D.symbol p (Prolog.Int n) in
  if D.add r (Array.of_list (List.map value args)) then begin
    r.given <- r.given + 1;
    List.iter
      (function
        | Facts.Sym s when relation <> "heap" && relation <> "local" && relation <> "literal" -> (
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
  match Hashtbl.find_opt C_front.owner f with
  | Some file -> (match locate (Hashtbl.find C_front.histories file) l with Some w -> w | None -> (file, l))
  | None -> ("?", l)

(* a place as the C says it *)
let said (s : string) : string =
  match place s with
  | Heap -> "what an allocator gave"
  | Literal when s = ".string" -> "a string (an initializer's)"
  | Literal -> (match site ("_in_" ^ Option.get (prefix "_str_in_" s) ^ "_0") with Some (f, l) -> Printf.sprintf "a string (line %d)" (snd (where f l)) | None -> "a string")
  | Local (f, x) -> Printf.sprintf "%s, a local of %s" x f
  | Global -> (match prefix "_array_elt_" s with Some v -> v ^ "[], a global" | None -> if Hashtbl.mem C_front.owner s then "the function " ^ s else s ^ ", a global")

(* the analysis on the facts: each call through a pointer, where, and
 * what it may reach; then what bugs.dl finds *)

let report (caps : < Cap.stdout; .. >) (p : D.t) : unit =
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
          let file = match Hashtbl.find_opt C_front.owner f with Some file -> file | None -> "?" in
          Printf.sprintf "%s: %s may return the address of %s" file f (said (name p t.(1))))
        (tuples "dangling") in
  List.iter (fun b -> Console.print caps ("bug? " ^ b ^ "\n")) (List.sort_uniq compare bugs);
  Console.print caps
    (Printf.sprintf "%d functions, %d calls through a pointer, %d of them reaching nothing; %d bugs?\n"
       (Hashtbl.length C_front.owner) (List.length calls)
       (List.length (List.filter (fun (_, _, _, _, t) -> t = []) calls))
       (List.length (List.sort_uniq compare bugs)))
