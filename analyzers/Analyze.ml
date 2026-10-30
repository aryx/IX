(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Analyze.mli *)

module D = Datalog

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

let usage = "usage: mini-analyze [-r rules-dir] [-Idir] [-Dname=value] [-facts] file.c...   (-h: how)"

let help = {|usage: mini-analyze [-r rules-dir] [-Idir] [-Dname=value] [-facts] file.c...
The C files read as one program, each call through a pointer said with the
functions it may reach, by an analysis of where each pointer may point
(Andersen's, the rules of pointer.dl):
  mini-analyze -r languages/datalog/analyses -I include prog/*.c
  walk.c:56: in walk, through f: hide, show
  main.c:76: in main, through a computed pointer: show
-r: the directory of pointer.dl (languages/datalog/analyses, from ix's top)
-I, -D: as mini-cc's; -facts: the facts made, not the analysis|}

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

(* the analysis on the facts: each call through a pointer, where, and
 * what it may reach *)
let report (caps : < caps; .. >) (rules : Fpath.t) (facts : string) : unit =
  let p = D.create () in
  D.load p ~from:(Fpath.to_string rules) (FS.read caps rules);
  D.load p ~from:"facts" facts;
  ignore (Datalog_eval.run ~naive:false p);
  let tuples r = (D.relation p r 2).all in
  let loads = Hashtbl.create 101 in
  List.iter
    (fun (t : int array) ->
      let fld = name p t.(2) in
      let fld = if String.length fld > 6 && String.sub fld 0 6 = "_fld__" then String.sub fld 6 (String.length fld - 6) else fld in
      Hashtbl.replace loads (name p t.(0)) (name p t.(1), "->" ^ fld))
    (D.relation p "assign_load_field" 3).all;
  List.iter (fun (t : int array) -> Hashtbl.replace loads (name p t.(0)) (name p t.(1), "[]")) (tuples "assign_array_elt");
  let edges = Hashtbl.create 101 in
  List.iter (fun (t : int array) -> Hashtbl.add edges (name p t.(0)) (name p t.(1))) (tuples "call_edge");
  let calls =
    List.filter_map
      (fun (t : int array) ->
        let s = name p t.(0) and v = name p t.(1) in
        match site s with
        | None -> None
        | Some (f, l) ->
            let file, line =
              match Hashtbl.find_opt C.C_front.owner f with
              | Some file -> (match locate (Hashtbl.find C.C_front.histories file) l with Some w -> w | None -> (file, l))
              | None -> ("?", l) in
            Some (file, line, f, through loads f v, List.sort_uniq compare (Hashtbl.find_all edges s)))
      (tuples "call_indirect") in
  let calls = List.sort_uniq compare calls in
  List.iter
    (fun (file, line, f, v, targets) ->
      Console.print caps
        (Printf.sprintf "%s:%d: in %s, through %s: %s\n" file line f v
           (if targets = [] then "nothing found" else String.concat ", " targets)))
    calls;
  Console.print caps
    (Printf.sprintf "%d functions, %d calls through a pointer, %d of them reaching nothing\n"
       (Hashtbl.length C.C_front.owner) (List.length calls)
       (List.length (List.filter (fun (_, _, _, _, t) -> t = []) calls)))

let main (caps : < caps; .. >) (argv : string array) : int =
  let rules = ref "languages/datalog/analyses" and only = ref false and incs = ref [] and defs = ref [] and files = ref [] in
  let options =
    Logging.flags
    @ [ ("-r", Arg.Set_string rules, " the directory of pointer.dl");
        ("-facts", Arg.Set only, " the facts, not the analysis");
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
        List.iter
          (fun (f : string) ->
            Logs.info (fun m -> m "reading %s" f);
            match C.C_front.file caps (List.rev !defs, incs) (path f) with
            | Ok () -> ()
            | Error m -> Console.eprint caps (m ^ "\n"); incr failed)
          (List.rev !files);
        if !only then Console.print caps (C.Facts.text ())
        else report caps (Fpath.append (path !rules) (Fpath.v "pointer.dl")) (C.Facts.text ());
        if !failed > 0 then 1 else 0
      with
      | D.Error (msg, at) -> Console.eprint caps (Printf.sprintf "%s: %s\n" at msg); 1
      | Failure msg | Sys_error msg -> Console.eprint caps (msg ^ "\n"); 1)
