(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Prolog_db.mli *)

type clause = {
  head : Prolog.term;
  body : Prolog.term;
  nvars : int;
  id : int;
  mutable erased : bool;
}

type pred = {
  name : string;
  arity : int;
  mutable clauses : clause list;
  mutable added : clause list;
  mutable dynamic : bool;
}

let ids : int ref = ref 0

let functor_of (t : Prolog.term) : (string * int) option =
  match Prolog.deref t with
  | Prolog.Atom name -> Some (name, 0)
  | Prolog.Struct (name, args) -> Some (name, List.length args)
  | _ -> None

let clause (t : Prolog.term) : clause =
  let numbers : (int, int) Hashtbl.t = Hashtbl.create 17 in
  let rec number (t : Prolog.term) : Prolog.term =
    match Prolog.deref t with
    | Prolog.Var v -> (
        match Hashtbl.find_opt numbers v.id with
        | Some k -> Prolog.Local k
        | None ->
            let k = Hashtbl.length numbers in
            Hashtbl.replace numbers v.id k;
            Prolog.Local k)
    | Prolog.Struct (name, args) -> Prolog.Struct (name, List.map number args)
    | t -> t in
  let head, body =
    match Prolog.deref t with
    | Prolog.Struct (":-", [ h; b ]) ->
        (* (the head's first: A, B... in the order they are read) *)
        let h = number h in
        (h, number b)
    | t -> (number t, Prolog.Atom "true") in
  incr ids;
  { head; body; nvars = Hashtbl.length numbers; id = !ids; erased = false }

let unset : Prolog.term = Prolog.Local (-1)

let rec instantiate (vars : Prolog.term array) (t : Prolog.term) : Prolog.term =
  match t with
  | Prolog.Local k -> (
      match vars.(k) with
      | Prolog.Local _ ->
          let v = Prolog.fresh () in
          vars.(k) <- v;
          v
      | t -> t)
  | Prolog.Struct (name, args) -> Prolog.Struct (name, List.map (fun (a : Prolog.term) -> instantiate vars a) args)
  | t -> t

let may_match (c : clause) (arg : Prolog.term) : bool =
  match c.head with
  | Prolog.Struct (_, first :: _) -> (
      match (first, Prolog.deref arg) with
      | Prolog.Atom a, Prolog.Atom b -> a = b
      | Prolog.Int a, Prolog.Int b -> a = b
      | Prolog.Struct (f, xs), Prolog.Struct (g, ys) -> f = g && List.length xs = List.length ys
      | (Prolog.Local _ | Prolog.Var _), _ -> true
      | _, Prolog.Var _ -> true
      | _ -> false)
  | _ -> true

let clauses (p : pred) : clause list =
  (match p.added with
   | [] -> ()
   | added ->
       p.clauses <- p.clauses @ List.rev added;
       p.added <- []);
  p.clauses

let add (p : pred) ~(front : bool) (c : clause) : unit =
  if front then p.clauses <- c :: p.clauses else p.added <- c :: p.added

let erase (p : pred) (c : clause) : unit =
  c.erased <- true;
  p.clauses <- List.filter (fun (c' : clause) -> not c'.erased) (clauses p)
