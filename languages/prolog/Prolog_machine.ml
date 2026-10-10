(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Prolog_machine.mli *)

exception Throw of Prolog.term
exception Halt of int

type cont =
  | Done
  | Failed
  | Goal of Prolog.term * int * cont
  | Try of call * Prolog_db.clause list * bool
  | Cut of int * cont
  | Native of (unit -> bool) * cont
  | Catch of catch * cont
and call = { goal : Prolog.term; args : Prolog.term list; next : cont; depth : int }
and catch = { catcher : Prolog.term; recovery : Prolog.term; height : int; trail : int }

type choice = { mark : int; alt : cont; before : int }

type engine = {
  e_solve : Prolog.term -> bool;
  e_more : unit -> bool;
  e_has_more : unit -> bool;
  e_once : Prolog.term -> bool;
}

type t = {
  ops : Prolog.ops;
  procs : (string, proc) Hashtbl.t;
  refs : (int, Prolog_db.pred * Prolog_db.clause) Hashtbl.t;
  globals : (string, Prolog.term) Hashtbl.t;
  mutable cont : cont;
  mutable choices : choice list;
  mutable height : int;
  mutable trail : Prolog.var list;
  mutable trail_size : int;
  mutable young : int;
  mutable steps : int;
  mutable trace : bool;
  mutable depth : int;
  mutable print : string -> unit;
  mutable warn : string -> unit;
  mutable read_line : unit -> string option;
  mutable read_file : string -> string;
  mutable clock : unit -> int;
  mutable inits : Prolog.term list;
  mutable loading : (string, unit) Hashtbl.t;
  mutable errors : int;
  mutable engine : engine option;
}
and proc =
  | Control of (t -> Prolog.term array -> int -> cont -> unit)
  | Det of (t -> Prolog.term array -> bool)
  | Pred of Prolog_db.pred

let key (name : string) (arity : int) : string = name ^ "/" ^ string_of_int arity

(*****************************************************************************)
(* Errors *)
(*****************************************************************************)

let error (formal : Prolog.term) : exn = Throw (Prolog.Struct ("error", [ formal; Prolog.fresh () ]))
let instantiation_error () : exn = error (Prolog.Atom "instantiation_error")

let type_error (kind : string) (culprit : Prolog.term) : exn =
  error (Prolog.Struct ("type_error", [ Prolog.Atom kind; culprit ]))

let indicator (name : string) (arity : int) : Prolog.term = Prolog.Struct ("/", [ Prolog.Atom name; Prolog.Int arity ])

(*****************************************************************************)
(* Binding, and its undoing *)
(*****************************************************************************)

let bind (m : t) (v : Prolog.var) (t : Prolog.term) : unit =
  v.value <- Some t;
  (* (a variable made after the last choice point is gone with what
   * made it when that one is gone back to: nothing to undo) *)
  if v.id <= m.young then begin
    m.trail <- v :: m.trail;
    m.trail_size <- m.trail_size + 1
  end

let undo (m : t) (mark : int) : unit =
  while m.trail_size > mark do
    match m.trail with
    | v :: rest ->
        v.value <- None;
        m.trail <- rest;
        m.trail_size <- m.trail_size - 1
    | [] -> m.trail_size <- mark
  done

let rec unify (m : t) (a : Prolog.term) (b : Prolog.term) : bool =
  let a = Prolog.deref a and b = Prolog.deref b in
  match (a, b) with
  | Prolog.Var x, Prolog.Var y ->
      if x.id <> y.id then bind m x b;
      true
  | Prolog.Var x, _ -> bind m x b; true
  | _, Prolog.Var y -> bind m y a; true
  | Prolog.Atom x, Prolog.Atom y -> x = y
  | Prolog.Int x, Prolog.Int y -> x = y
  | Prolog.Struct (f, xs), Prolog.Struct (g, ys) ->
      f = g && unify_all m xs ys
  | _ -> false

(* (the last argument is a tail call: a long list is a loop) *)
and unify_all (m : t) (xs : Prolog.term list) (ys : Prolog.term list) : bool =
  match (xs, ys) with
  | [ x ], [ y ] -> unify m x y
  | x :: xs, y :: ys -> unify m x y && unify_all m xs ys
  | [], [] -> true
  | _ -> false

(* a kept clause's term against a call's: the clause's variables are the
 * array's slots, filled as they are met *)
let rec unify_head (m : t) (vars : Prolog.term array) (pattern : Prolog.term) (t : Prolog.term) : bool =
  match pattern with
  | Prolog.Local k -> (
      match vars.(k) with
      | Prolog.Local _ -> vars.(k) <- t; true
      | bound -> unify m bound t)
  | Prolog.Atom a -> (
      match Prolog.deref t with
      | Prolog.Atom b -> a = b
      | Prolog.Var v -> bind m v pattern; true
      | _ -> false)
  | Prolog.Int a -> (
      match Prolog.deref t with
      | Prolog.Int b -> a = b
      | Prolog.Var v -> bind m v pattern; true
      | _ -> false)
  | Prolog.Struct (f, ps) -> (
      match Prolog.deref t with
      | Prolog.Struct (g, ts) ->
          f = g && unify_heads m vars ps ts
      | Prolog.Var v -> bind m v (Prolog_db.instantiate vars pattern); true
      | _ -> false)
  | Prolog.Var _ -> unify m pattern t

and unify_heads (m : t) (vars : Prolog.term array) (ps : Prolog.term list) (ts : Prolog.term list) : bool =
  match (ps, ts) with
  | [ p ], [ t ] -> unify_head m vars p t
  | p :: ps, t :: ts -> unify_head m vars p t && unify_heads m vars ps ts
  | [], [] -> true
  | _ -> false

(*****************************************************************************)
(* The choice points *)
(*****************************************************************************)

let push (m : t) (alt : cont) : unit =
  m.choices <- { mark = m.trail_size; alt; before = m.young } :: m.choices;
  m.height <- m.height + 1;
  m.young <- Prolog.newest ()

let cut_to (m : t) (height : int) : unit =
  while m.height > height do
    (match m.choices with
     | c :: rest ->
         m.choices <- rest;
         m.young <- c.before
     | [] -> ());
    m.height <- m.height - 1
  done

let backtrack (m : t) : unit =
  match m.choices with
  | [] -> m.cont <- Failed
  | c :: rest ->
      m.choices <- rest;
      m.height <- m.height - 1;
      m.young <- c.before;
      undo m c.mark;
      m.cont <- c.alt

(*****************************************************************************)
(* A step *)
(*****************************************************************************)

(* the tracer's line: a port, the depth, the goal *)
let port (m : t) (name : string) (depth : int) (goal : Prolog.term) : unit =
  m.print (Printf.sprintf "%s%s: %s\n" (String.make (2 * depth) ' ') name (Prolog.to_string m.ops ~quoted:true goal))

(* (the prelude's own helpers are not shown) *)
let traced (m : t) (name : string) : bool = m.trace && not (String.length name > 0 && name.[0] = '$')

(* the clauses that may match, from the first that does *)
let rec matching (args : Prolog.term list) (clauses : Prolog_db.clause list) : Prolog_db.clause list =
  match clauses with
  | [] -> []
  | c :: rest ->
      let may : bool = match args with [] -> true | first :: _ -> Prolog_db.may_match c first in
      if c.erased || not may then matching args rest else clauses

let head_unifies (m : t) (vars : Prolog.term array) (head : Prolog.term) (args : Prolog.term list) : bool =
  match head with
  | Prolog.Struct (_, ps) -> unify_heads m vars ps args
  | _ -> true

let try_clauses (m : t) (call : call) (clauses : Prolog_db.clause list) (redo : bool) : unit =
  match matching call.args clauses with
  | [] -> backtrack m
  | c :: rest ->
      if redo && m.trace && call.depth >= 0 then begin
        port m "Redo" call.depth call.goal;
        m.depth <- call.depth + 1
      end;
      (* what the body's cut cuts to: this call's other clauses with it *)
      let height = m.height in
      (match matching call.args rest with
       | [] -> ()
       | rest -> push m (Try (call, rest, true)));
      let vars = Array.make c.nvars Prolog_db.unset in
      if head_unifies m vars c.head call.args then
        match c.body with
        | Prolog.Atom "true" -> m.cont <- call.next
        | body -> m.cont <- Goal (Prolog_db.instantiate vars body, height, call.next)
      else backtrack m

let invoke (m : t) (goal : Prolog.term) (name : string) (args : Prolog.term list) (barrier : int) (next : cont) : unit =
  let arity = List.length args in
  match Hashtbl.find_opt m.procs (key name arity) with
  | Some (Control f) -> f m (Array.of_list args) barrier next
  | Some (Det f) ->
      let args = Array.of_list args in
      if traced m name then begin
        port m "Call" m.depth goal;
        let ok = f m args in
        port m (if ok then "Exit" else "Fail") m.depth goal;
        if ok then m.cont <- next else backtrack m
      end
      else if f m args then m.cont <- next
      else backtrack m
  | Some (Pred p) ->
      if traced m name then begin
        let depth = m.depth in
        port m "Call" depth goal;
        push m (Native ((fun () -> port m "Fail" depth goal; m.depth <- depth; false), Done));
        let next = Native ((fun () -> port m "Exit" depth goal; m.depth <- depth; true), next) in
        m.depth <- depth + 1;
        try_clauses m { goal; args; next; depth } (Prolog_db.clauses p) false
      end
      else try_clauses m { goal; args; next; depth = -1 } (Prolog_db.clauses p) false
  | None ->
      raise (error (Prolog.Struct ("existence_error", [ Prolog.Atom "procedure"; indicator name arity ])))

let step (m : t) : unit =
  m.steps <- m.steps + 1;
  match m.cont with
  | Done | Failed -> ()
  | Cut (height, next) -> cut_to m height; m.cont <- next
  | Native (f, next) -> if f () then m.cont <- next else backtrack m
  | Catch (c, next) ->
      (* (its choice point, if the goal left no other above it) *)
      if m.height = c.height + 1 then cut_to m c.height;
      m.cont <- next
  | Try (call, clauses, redo) -> try_clauses m call clauses redo
  | Goal (goal, barrier, next) -> (
      match Prolog.deref goal with
      | Prolog.Atom name as goal -> invoke m goal name [] barrier next
      | Prolog.Struct (name, args) as goal -> invoke m goal name args barrier next
      | Prolog.Var _ -> raise (instantiation_error ())
      | goal -> raise (type_error "callable" goal))

(*****************************************************************************)
(* throw, and running *)
(*****************************************************************************)

(* would they unify? (nothing is left bound) *)
let unifiable (m : t) (a : Prolog.term) (b : Prolog.term) : bool =
  let young = m.young and mark = m.trail_size in
  m.young <- max_int;
  let ok = unify m a b in
  undo m mark;
  m.young <- young;
  ok

(* the nearest catch/3 the continuation is still inside *)
let rec catcher (k : cont) : (catch * cont) option =
  match k with
  | Done | Failed -> None
  | Goal (_, _, next) | Cut (_, next) | Native (_, next) -> catcher next
  | Try (call, _, _) -> catcher call.next
  | Catch (c, next) -> Some (c, next)

let rec recover (m : t) (ball : Prolog.term) : unit =
  match catcher m.cont with
  | None -> raise (Throw ball)
  | Some (c, next) ->
      cut_to m c.height;
      undo m c.trail;
      if unifiable m c.catcher ball && unify m c.catcher ball then m.cont <- Goal (c.recovery, m.height, next)
      else begin
        m.cont <- next;
        recover m ball
      end

let run (m : t) : bool =
  let finished = ref false and answer = ref false in
  while not !finished do
    try
      while not !finished do
        match m.cont with
        | Done -> answer := true; finished := true
        | Failed -> finished := true
        | _ -> step m
      done
    with Throw ball ->
      (* (copied: undoing the trail must not undo the ball) *)
      recover m (Prolog.copy ball)
  done;
  !answer

let solve (m : t) (goal : Prolog.term) : bool =
  match m.engine with
  | Some e -> e.e_solve goal
  | None ->
      m.cont <- Goal (goal, 0, Done);
      m.choices <- [];
      m.height <- 0;
      m.trail <- [];
      m.trail_size <- 0;
      m.young <- 0;
      m.depth <- 0;
      run m

let more (m : t) : bool =
  match m.engine with
  | Some e -> e.e_more ()
  | None ->
      backtrack m;
      run m

let has_more (m : t) : bool =
  match m.engine with
  | Some e -> e.e_has_more ()
  | None -> ( match m.choices with [] -> false | _ -> true)

let once (m : t) (goal : Prolog.term) : bool =
  match m.engine with
  | Some e -> e.e_once goal
  | None ->
      let cont = m.cont and choices = m.choices and height = m.height and mark = m.trail_size and young = m.young in
      let restore () : unit =
        m.cont <- cont;
        m.choices <- choices;
        m.height <- height;
        m.young <- young in
      m.cont <- Goal (goal, 0, Done);
      m.choices <- [];
      m.height <- 0;
      match run m with
      | ok ->
          restore ();
          if not ok then undo m mark;
          ok
      | exception e ->
          restore ();
          undo m mark;
          raise e

(*****************************************************************************)
(* The procedures *)
(*****************************************************************************)

let define (m : t) (name : string) (arity : int) (f : t -> Prolog.term array -> bool) : unit =
  Hashtbl.replace m.procs (key name arity) (Det f)

let find_pred (m : t) (name : string) (arity : int) : Prolog_db.pred option =
  match Hashtbl.find_opt m.procs (key name arity) with Some (Pred p) -> Some p | _ -> None

let pred (m : t) (name : string) (arity : int) : Prolog_db.pred =
  match Hashtbl.find_opt m.procs (key name arity) with
  | Some (Pred p) -> p
  | Some _ ->
      raise
        (error
           (Prolog.Struct
              ("permission_error", [ Prolog.Atom "modify"; Prolog.Atom "static_procedure"; indicator name arity ])))
  | None ->
      let p : Prolog_db.pred = { name; arity; clauses = []; added = []; dynamic = false } in
      Hashtbl.replace m.procs (key name arity) (Pred p);
      p

let head_pred (m : t) (head : Prolog.term) : Prolog_db.pred =
  match Prolog.deref head with
  | Prolog.Var _ -> raise (instantiation_error ())
  | head -> (
      match Prolog_db.functor_of head with
      | Some (name, arity) -> pred m name arity
      | None -> raise (type_error "callable" head))

let add_clause (m : t) ~(front : bool) (t : Prolog.term) : unit =
  let head : Prolog.term = match Prolog.deref t with Prolog.Struct (":-", [ h; _ ]) -> h | t -> t in
  let p = head_pred m head in
  Prolog_db.add p ~front (Prolog_db.clause t)

(*****************************************************************************)
(* The control constructs *)
(*****************************************************************************)

(* call/N's goal: a term with more arguments *)
let with_args (goal : Prolog.term) (extra : Prolog.term list) : Prolog.term =
  match extra with
  | [] -> goal
  | _ -> (
    match Prolog.deref goal with
    | Prolog.Atom name -> Prolog.Struct (name, extra)
    | Prolog.Struct (name, args) -> Prolog.Struct (name, args @ extra)
    | Prolog.Var _ -> raise (instantiation_error ())
    | goal -> raise (type_error "callable" goal))

let fail_goal : cont = Goal (Prolog.Atom "fail", 0, Done)

let controls (m : t) : unit =
  let control (name : string) (arity : int) (f : t -> Prolog.term array -> int -> cont -> unit) : unit =
    Hashtbl.replace m.procs (key name arity) (Control f) in
  control "true" 0 (fun (m : t) (_ : Prolog.term array) (_ : int) (next : cont) -> m.cont <- next);
  control "fail" 0 (fun (m : t) (_ : Prolog.term array) (_ : int) (_ : cont) -> backtrack m);
  control "false" 0 (fun (m : t) (_ : Prolog.term array) (_ : int) (_ : cont) -> backtrack m);
  control "!" 0 (fun (m : t) (_ : Prolog.term array) (barrier : int) (next : cont) ->
      cut_to m barrier;
      m.cont <- next);
  control "," 2 (fun (m : t) (args : Prolog.term array) (barrier : int) (next : cont) ->
      m.cont <- Goal (args.(0), barrier, Goal (args.(1), barrier, next)));
  control ";" 2 (fun (m : t) (args : Prolog.term array) (barrier : int) (next : cont) ->
      match Prolog.deref args.(0) with
      | Prolog.Struct ("->", [ cond; then_ ]) ->
          (* the condition's cut is its own; once it holds, the else and
           * its other answers go *)
          let height = m.height in
          push m (Goal (args.(1), barrier, next));
          m.cont <- Goal (cond, height + 1, Cut (height, Goal (then_, barrier, next)))
      | left ->
          push m (Goal (args.(1), barrier, next));
          m.cont <- Goal (left, barrier, next));
  control "->" 2 (fun (m : t) (args : Prolog.term array) (barrier : int) (next : cont) ->
      let height = m.height in
      m.cont <- Goal (args.(0), height, Cut (height, Goal (args.(1), barrier, next))));
  control "\\+" 1 (fun (m : t) (args : Prolog.term array) (_ : int) (next : cont) ->
      let height = m.height in
      push m next;
      m.cont <- Goal (args.(0), height + 1, Cut (height, fail_goal)));
  for n = 1 to 8 do
    control "call" n (fun (m : t) (args : Prolog.term array) (_ : int) (next : cont) ->
        (* (opaque to the cut: it cuts to here) *)
        m.cont <- Goal (with_args args.(0) (List.tl (Array.to_list args)), m.height, next))
  done;
  control "findall" 3 (fun (m : t) (args : Prolog.term array) (_ : int) (next : cont) ->
      let found : Prolog.term list ref = ref [] in
      let height = m.height in
      (* when the goal has no more answers: the list *)
      push m (Native ((fun () -> unify m args.(2) (Prolog.of_list (List.rev !found))), next));
      m.cont <-
        Goal (args.(1), height + 1, Native ((fun () -> found := Prolog.copy args.(0) :: !found; false), Done)));
  control "catch" 3 (fun (m : t) (args : Prolog.term array) (_ : int) (next : cont) ->
      let c : catch = { catcher = args.(1); recovery = args.(2); height = m.height; trail = m.trail_size } in
      (* a choice point that only fails: what the goal binds is on the
       * trail from here, for a throw to undo *)
      push m fail_goal;
      m.cont <- Goal (args.(0), m.height, Catch (c, next)));
  control "throw" 1 (fun (_ : t) (args : Prolog.term array) (_ : int) (_ : cont) ->
      match Prolog.deref args.(0) with
      | Prolog.Var _ -> raise (instantiation_error ())
      | ball -> raise (Throw ball))

let create () : t =
  let m : t =
    {
      ops = Prolog.default_ops ();
      procs = Hashtbl.create 511;
      refs = Hashtbl.create 61;
      globals = Hashtbl.create 17;
      cont = Done;
      choices = [];
      height = 0;
      trail = [];
      trail_size = 0;
      young = 0;
      steps = 0;
      trace = false;
      depth = 0;
      print = (fun (_ : string) -> ());
      warn = (fun (_ : string) -> ());
      read_line = (fun () -> None);
      read_file = (fun (name : string) -> failwith (name ^ ": no file can be read here"));
      clock = (fun () -> 0);
      inits = [];
      loading = Hashtbl.create 1;
      errors = 0;
      engine = None;
    } in
  controls m;
  m
