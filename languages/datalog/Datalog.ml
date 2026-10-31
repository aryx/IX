(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Datalog.mli *)

module P = Prolog

type arg = Const of int | Slot of int | Any

type relation = {
  name : string;
  arity : int;
  set : Tuples.t;
  mutable rows : int array;
  mutable count : int;
  mutable indexes : (int * int array * Index.t) list;
  mutable delta_from : int;
  mutable delta_to : int;
  mutable stratum : int;
  mutable given : int;
  mutable rules : int;
}

type atom = { rel : relation; args : arg array }
type literal = Pos of atom | Neg of atom | Cmp of string * arg * arg
type rule = { head : atom; body : literal list; slots : int; at : string }
type query = { goal : atom; names : string array }

type t = {
  symbols : (string, int) Hashtbl.t;
  mutable terms : P.term array;
  mutable nsymbols : int;
  relations : (string, relation) Hashtbl.t;
  mutable rule_list : rule list;
  mutable queries : query list;
}

exception Error of string * string

let create () : t =
  { symbols = Hashtbl.create 1021; terms = Array.make 256 P.nil; nsymbols = 0; relations = Hashtbl.create 61; rule_list = []; queries = [] }

let ops : P.ops = P.default_ops ()
let text_of (t : P.term) : string = P.to_string ops ~quoted:true t

let symbol (p : t) (t : P.term) : int =
  let key = text_of t in
  match Hashtbl.find_opt p.symbols key with
  | Some k -> k
  | None ->
      let k = p.nsymbols in
      if k >= Array.length p.terms then begin
        let larger = Array.make (2 * k) P.nil in
        Array.blit p.terms 0 larger 0 k;
        p.terms <- larger
      end;
      p.terms.(k) <- t;
      p.nsymbols <- k + 1;
      Hashtbl.add p.symbols key k;
      k

let relation (p : t) (name : string) (arity : int) : relation =
  let key = name ^ "/" ^ string_of_int arity in
  match Hashtbl.find_opt p.relations key with
  | Some r -> r
  | None ->
      let r : relation =
        { name; arity; set = Tuples.create arity; rows = Array.make (16 * arity) 0; count = 0; indexes = []; delta_from = 0; delta_to = 0; stratum = 0; given = 0; rules = 0 } in
      Hashtbl.add p.relations key r;
      r

let show (p : t) (r : relation) (tuple : int array) : string =
  if r.arity = 0 then P.atom_text true r.name ^ "."
  else
    P.atom_text true r.name ^ "("
    ^ String.concat "," (List.map (fun (k : int) -> text_of p.terms.(k)) (Array.to_list tuple))
    ^ ")."

let get (r : relation) (i : int) (j : int) : int = r.rows.((i * r.arity) + j)

(* an index's key: the values of the mask's columns, in order *)
let columns (arity : int) (mask : int) : int array =
  let cols = ref [] in
  for i = arity - 1 downto 0 do
    if mask land (1 lsl i) <> 0 then cols := i :: !cols
  done;
  Array.of_list !cols

let append (r : relation) (tuple : int array) : int =
  let id = r.count and n = r.arity in
  if (id + 1) * n > Array.length r.rows then begin
    let larger = Array.make (2 * (id + 1) * n) 0 in
    Array.blit r.rows 0 larger 0 (id * n);
    r.rows <- larger
  end;
  Array.blit tuple 0 r.rows (id * n) n;
  r.count <- id + 1;
  id

let add (r : relation) (tuple : int array) : bool =
  if not (Tuples.add r.set tuple) then false
  else begin
    let id = append r tuple in
    List.iter
      (fun ((_, cols, index) : int * int array * Index.t) -> Index.add index (fun (i : int) -> tuple.(cols.(i))) id)
      r.indexes;
    true
  end

let tuples (r : relation) : int array list =
  let all = ref [] in
  for i = 0 to r.count - 1 do
    all := Array.sub r.rows (i * r.arity) r.arity :: !all
  done;
  !all

(*****************************************************************************)
(* A text read *)
(*****************************************************************************)

(* a rule's variables: each its slot; _ has none *)
type scope = { mutable slots_of : (int * int) list; mutable names_of : (int * string) list }

let rec conjuncts (t : P.term) : P.term list =
  match P.deref t with
  | P.Struct (",", [ a; b ]) -> conjuncts a @ conjuncts b
  | t -> [ t ]

let comparisons : string list = [ "="; "\\="; "=="; "\\=="; "<"; ">"; "=<"; ">=" ]

(* [named]: the variables the reader has a name for (not _) *)
let arg_of (p : t) (scope : scope) (named : (string * P.term) list) (at : string) (t : P.term) : arg =
  match P.deref t with
  | P.Var v -> (
      match List.assoc_opt v.id scope.slots_of with
      | Some k -> Slot k
      | None ->
          let name : string option =
            List.fold_left
              (fun (found : string option) ((name, t') : string * P.term) ->
                match P.deref t' with P.Var v' when v'.id = v.id -> Some name | _ -> found)
              None named in
          (match name with
           | None -> Any
           | Some name ->
               let k = List.length scope.slots_of in
               scope.slots_of <- (v.id, k) :: scope.slots_of;
               scope.names_of <- (k, name) :: scope.names_of;
               Slot k))
  | (P.Atom _ | P.Int _) as t -> Const (symbol p t)
  | t -> raise (Error ("a compound term is not Datalog's: " ^ text_of t, at))

let atom_of (p : t) (scope : scope) (named : (string * P.term) list) (at : string) (t : P.term) : atom =
  match P.deref t with
  | P.Atom name -> { rel = relation p name 0; args = [||] }
  | P.Struct (name, args) ->
      { rel = relation p name (List.length args); args = Array.of_list (List.map (arg_of p scope named at) args) }
  | t -> raise (Error ("an atom is expected, not " ^ text_of t, at))

let literal_of (p : t) (scope : scope) (named : (string * P.term) list) (at : string) (t : P.term) : literal =
  match P.deref t with
  | P.Struct (("\\+" | "not"), [ a ]) -> Neg (atom_of p scope named at a)
  | P.Struct (op, [ a; b ]) when List.mem op comparisons -> Cmp (op, arg_of p scope named at a, arg_of p scope named at b)
  | t -> Pos (atom_of p scope named at t)

let slots_in (a : atom) : int list =
  Array.fold_left (fun (acc : int list) (x : arg) -> match x with Slot k -> k :: acc | _ -> acc) [] a.args

let clause (p : t) (named : (string * P.term) list) (at : string) (t : P.term) : unit =
  let scope : scope = { slots_of = []; names_of = [] } in
  let names () : string array =
    Array.init (List.length scope.slots_of) (fun (k : int) -> List.assoc k scope.names_of) in
  match P.deref t with
  | P.Struct ((":-" | "?-"), [ goal ]) ->
      (* (a query's _ is a column not asked for: a slot with no name) *)
      let goal = atom_of p scope named at goal in
      let n = ref (List.length scope.slots_of) in
      let args = Array.map (fun (x : arg) -> match x with Any -> incr n; Slot (!n - 1) | x -> x) goal.args in
      let names = Array.append (names ()) (Array.make (!n - List.length scope.slots_of) "_") in
      p.queries <- { goal = { rel = goal.rel; args }; names } :: p.queries
  | P.Struct (":-", [ head; body ]) ->
      (* the positive atoms first: they are what gives a variable its slot *)
      let lits = List.map (fun (b : P.term) -> (b, literal_of p scope named at b)) (conjuncts body) in
      let positive : int list =
        List.concat_map (fun ((_, l) : P.term * literal) -> match l with Pos a -> slots_in a | _ -> []) lits in
      let safe (what : string) (x : arg) : unit =
        match x with
        | Slot k when not (List.mem k positive) ->
            raise (Error (Printf.sprintf "the variable %s of %s is in no positive atom of the body" (List.assoc k scope.names_of) what, at))
        | Any when what <> "a negation" -> raise (Error ("_ in " ^ what, at))
        | _ -> () in
      List.iter
        (fun ((_, l) : P.term * literal) ->
          match l with
          | Pos _ -> ()
          | Neg a -> Array.iter (safe "a negation") a.args
          | Cmp (_, x, y) -> safe "a comparison" x; safe "a comparison" y)
        lits;
      let head = atom_of p scope named at head in
      Array.iter (safe "the head") head.args;
      head.rel.rules <- head.rel.rules + 1;
      p.rule_list <- { head; body = List.map snd lits; slots = List.length scope.slots_of; at } :: p.rule_list
  | t ->
      let fact = atom_of p scope named at t in
      let tuple =
        Array.map
          (fun (x : arg) -> match x with Const k -> k | _ -> raise (Error ("a fact with a variable: " ^ text_of t, at)))
          fact.args in
      fact.rel.given <- fact.rel.given + 1;
      ignore (add fact.rel tuple)

(* the author's files' way: a line ended by ? is a query *)
let questions (text : string) : string =
  let line (l : string) : string =
    let code : string = match String.index_opt l '%' with Some i -> String.sub l 0 i | None -> l in
    let code = String.trim code in
    let n = String.length code in
    if n > 1 && code.[n - 1] = '?' && not (n > 2 && code.[0] = '?' && code.[1] = '-') then "?- " ^ String.sub code 0 (n - 1) ^ " ." else l in
  String.concat "\n" (List.map line (String.split_on_char '\n' text))

let load (p : t) ~(from : string) (text : string) : unit =
  let place (line : int) : string = from ^ ":" ^ string_of_int line in
  let text = questions text in
  let r = Prolog_read.make ops text in
  (* a place's line, counted on from the last one asked (each clause
   * asks: from the text's start each time, a file of facts was read in
   * the square of its size) *)
  let last = ref 0 and lines = ref 1 in
  let line (pos : int) : int =
    let pos = min pos (String.length text) in
    for i = !last to pos - 1 do
      if text.[i] = '\n' then incr lines
    done;
    if pos > !last then last := pos;
    !lines in
  let stop = ref false in
  while not !stop do
    match Prolog_read.next r with
    | None -> stop := true
    | exception Prolog_read.Error (msg, pos) -> raise (Error (msg, place (line pos)))
    | Some (t, named) -> clause p named (place (line (Prolog_read.position r))) t
  done

let query (p : t) (text : string) : query =
  let before = p.queries in
  load p ~from:"-q" ("?- " ^ text ^ " .");
  match p.queries with
  | q :: _ when List.length p.queries = List.length before + 1 ->
      p.queries <- before;
      q
  | _ -> raise (Error ("a query is expected: " ^ text, "-q"))
