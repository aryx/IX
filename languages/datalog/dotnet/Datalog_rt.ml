(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Datalog_rt.mli *)

module D = Datalog

exception Failed of string

let fail (msg : string) : 'a = raise (Failed msg)

(* the program's facts: the rules' files' texts (name, text, ...),
 * then the files given *)
let load (caps : < Cap.open_in; .. >) (texts : string array) (files : string array)
    : D.t =
  let p = D.create () in
  let load (from : string) (text : string) =
    try D.load p ~from text with D.Error (msg, at) -> fail (at ^ ": " ^ msg) in
  for i = 0 to (Array.length texts / 2) - 1 do
    load texts.(2 * i) texts.((2 * i) + 1)
  done;
  Array.iter
    (fun (f : string) ->
      match FS.path f with
      | Error msg -> fail msg
      | Ok path -> (
          match FS.read_opt caps path with
          | Some text -> load f text
          | None -> fail (f ^ ": cannot be read")))
    files;
  p

let relation (p : D.t) (name : string) (arity : int) : D.relation =
  D.relation p name arity

let symbol (p : D.t) (text : string) : int =
  match Hashtbl.find_opt p.symbols text with
  | Some k -> k
  | None -> fail ("no symbol " ^ text)

let count (r : D.relation) : int = r.count
let delta_from (r : D.relation) : int = r.delta_from
let delta_to (r : D.relation) : int = r.delta_to
let get (r : D.relation) (id : int) (col : int) : int = D.get r id col

(* the tuples whose mask's columns are the keys, by their numbers *)
let lookup (r : D.relation) (mask : int) (keys : int array) : int array =
  let found = ref [] in
  Index.iter (Datalog_eval.index r mask) r.rows r.arity (fun (i : int) -> keys.(i))
    (fun (_ : int array) (base : int) -> found := (base / r.arity) :: !found);
  Array.of_list (List.rev !found)

(* a relation's hashed index by the mask's columns (made the first
 * time), and its chain: the last tuple with the keys, the one before
 * with the same, -1 at the end (the compiled loop's, no allocation) *)
let index (r : D.relation) (mask : int) : Index.t = Datalog_eval.index r mask

let first (idx : Index.t) (keys : int array) : int = Index.first_array idx keys
let next (idx : Index.t) (id : int) : int = Index.next idx id

let mem (r : D.relation) (tuple : int array) : bool = Relset.mem_array r.set tuple

let absent (r : D.relation) (mask : int) (keys : int array) : bool =
  if mask = 0 then r.count = 0
  else if mask = (1 lsl r.arity) - 1 then not (mem r keys)
  else not (Index.exists_array (Datalog_eval.index r mask) keys)

let compare (p : D.t) (x : int) (y : int) : int =
  Prolog.compare p.terms.(x) p.terms.(y)

(* (the tuple is the caller's, filled again: copied when it is new) *)
let add (r : D.relation) (tuple : int array) : unit =
  if not (mem r tuple) then ignore (D.add r (Array.copy tuple))

(* a stratum's rounds: its heads' new tuples, Datalog_eval's ranges *)
let since (r : D.relation) (from : int) : unit =
  r.delta_from <- from;
  r.delta_to <- r.count

let begin_stratum (heads : D.relation array) : unit =
  Array.iter (fun (r : D.relation) -> since r r.count) heads

let turn (heads : D.relation array) : bool =
  let any = ref false in
  Array.iter
    (fun (r : D.relation) ->
      if r.count > r.delta_to then any := true;
      since r r.delta_to)
    heads;
  !any

let end_stratum (heads : D.relation array) : unit = begin_stratum heads

(* the queries' answers, the texts' then the program's, each sorted *)
let answers (caps : < Cap.stdout; .. >) (p : D.t) (queries : string array) : unit =
  let asked =
    Array.to_list
      (Array.map
         (fun (q : string) ->
           try D.query p q with D.Error (msg, at) -> fail (at ^ ": " ^ msg))
         queries) in
  List.iter
    (fun (q : D.query) ->
      List.iter
        (fun (line : string) -> Console.print caps (line ^ "\n"))
        (Datalog_eval.answers p q))
    (List.rev p.queries @ asked)

let main (texts : string array) (queries : string array) (rules : D.t -> unit)
    : unit =
  Cap.main (fun (caps : Cap.all_caps) ->
      let argv = CapSys.argv caps in
      let files = Array.sub argv 1 (Array.length argv - 1) in
      match load caps texts files with
      | p ->
          rules p;
          answers caps p queries;
          flush (Console.stdout caps)
      | exception Failed msg ->
          Console.eprint caps (msg ^ "\n");
          CapStdlib.exit caps 1)
