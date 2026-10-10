(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Wam_machine.mli *)

module P = Prolog
module M = Prolog_machine

type frame = {
  parent : frame option;
  return : Wam.addr;
  y : P.term array;
  mutable catch : catch option;
}

(* catch/3's mark: the choice points and the trail when it was entered *)
and catch = { catcher : P.term; recovery : P.term; floor : int; trailed : int }

type choice = {
  args : P.term array;
  env : frame;
  cont : Wam.addr;
  mutable alt : Wam.addr;
  mark : int;       (* the trail's size *)
  before : int;     (* Prolog_machine's [young] then *)
}

type status = Running | Answer | No_answer

type t = {
  m : M.t;
  ctx : Wam_compile.ctx;
  mutable x : P.term array;
  mutable code : Wam.instr array;       (* P *)
  mutable pc : int;
  mutable cp : Wam.addr;
  mutable e : frame;
  mutable choices : choice list;        (* B *)
  mutable height : int;
  mutable b0 : int;                     (* the height at the last call: what a cut cuts to *)
  mutable nargs : int;                  (* the last call's arity: what a choice point keeps *)
  (* a structure's arguments: read from [s], or (write) gathered in [built] *)
  mutable write : bool;
  mutable s : P.term list;
  mutable built : P.term list;
  mutable left : int;
  mutable functor_ : string;
  mutable for_var : P.var option;       (* whom the structure is for: a variable, or the register *)
  mutable for_reg : int;
  mutable status : status;
  bags : (int, P.term list ref) Hashtbl.t; (* findall's answers *)
  mutable bag : int;
  boot : Wam.instr array;               (* call(A1), then stop *)
}

(* a throw/1 no catch/3 took *)
exception Uncaught of P.term

let stop_addr : Wam.addr = { code = [| Wam.Stop |]; pc = 0 }

(* a choice point that is only a mark: gone when it is come back to *)
let pop_addr : Wam.addr = { code = [| Wam.Trust Wam_compile.fail_addr |]; pc = 0 }

let root () : frame = { parent = None; return = stop_addr; y = [||]; catch = None }

(*****************************************************************************)
(* The choice points *)
(*****************************************************************************)

let jump (w : t) (a : Wam.addr) : unit =
  w.code <- a.code;
  w.pc <- a.pc

let push (w : t) (nargs : int) (alt : Wam.addr) : unit =
  let m = w.m in
  w.choices <- { args = Array.sub w.x 0 nargs; env = w.e; cont = w.cp; alt; mark = m.trail_size; before = m.young } :: w.choices;
  w.height <- w.height + 1;
  m.young <- P.newest ()

let pop (w : t) : unit =
  match w.choices with
  | c :: rest ->
      w.choices <- rest;
      w.height <- w.height - 1;
      w.m.young <- c.before
  | [] -> ()

let cut_to (w : t) (height : int) : unit =
  while w.height > height do
    pop w
  done

(* the last choice point's state again (it stays: retry and trust say what becomes of it) *)
let backtrack (w : t) : unit =
  match w.choices with
  | [] -> w.status <- No_answer
  | c :: _ ->
      Array.blit c.args 0 w.x 0 (Array.length c.args);
      w.nargs <- Array.length c.args;
      w.e <- c.env;
      w.cp <- c.cont;
      M.undo w.m c.mark;
      w.b0 <- w.height - 1;
      jump w c.alt

(*****************************************************************************)
(* A call *)
(*****************************************************************************)

let grow (w : t) (n : int) : unit =
  if n > Array.length w.x then w.x <- Array.append w.x (Array.make (n - Array.length w.x + 64) P.nil)

let existence (name : string) (arity : int) : exn =
  M.error (P.Struct ("existence_error", [ P.Atom "procedure"; M.indicator name arity ]))

(* what the first machine has under this name *)
let resolve (w : t) (p : Wam.pred) : unit =
  match Hashtbl.find_opt w.m.procs (M.key p.name p.arity) with
  | Some (M.Pred dbp) -> p.kind <- Wam.User dbp
  | Some (M.Det f) -> p.kind <- Wam.Det f
  | Some (M.Control _) ->
      if p.name = "call" then p.kind <- Wam.Meta
      else if p.name = "throw" then
        p.kind <-
          Wam.Det
            (fun (_ : M.t) (a : P.term array) ->
              match P.deref a.(0) with
              | P.Var _ -> raise (M.instantiation_error ())
              | ball -> raise (M.Throw ball))
      else raise (existence p.name p.arity)
  | None -> raise (existence p.name p.arity)

let rec enter (w : t) (p : Wam.pred) : unit =
  w.m.steps <- w.m.steps + 1;
  w.b0 <- w.height;
  w.nargs <- p.arity;
  match p.kind with
  | Wam.Fixed -> jump w p.entry
  | Wam.User dbp ->
      let cs = Prolog_db.clauses dbp in
      if cs != p.linked then begin
        Wam_compile.link w.ctx p cs;
        grow w w.ctx.xneed
      end;
      jump w p.entry
  | Wam.Det f -> if f w.m (Array.sub w.x 0 p.arity) then jump w w.cp else backtrack w
  | Wam.Meta ->
      let extra : P.term list = List.tl (Array.to_list (Array.sub w.x 0 p.arity)) in
      meta w (M.with_args w.x.(0) extra)
  | Wam.Unknown ->
      resolve w p;
      enter w p

(* call/1: the goal's arguments loaded and its predicate entered; a
 * conjunction, a disjunction, an arrow or a negation is first made a
 * clause, its goals that clause's arguments (so what is compiled is as
 * large as the control, not as the goals) *)
and meta (w : t) (goal : P.term) : unit =
  match P.deref goal with
  | P.Var _ -> raise (M.instantiation_error ())
  | P.Atom ("true" | "!") -> jump w w.cp
  | P.Atom ("fail" | "false") -> backtrack w
  | P.Struct (("," | ";" | "->"), [ _; _ ]) | P.Struct ("\\+", [ _ ]) ->
      let leaves : P.term list ref = ref [] and vars : P.term list ref = ref [] in
      let rec skeleton (t : P.term) : P.term =
        match P.deref t with
        | P.Struct (",", [ a; b ]) -> let a = skeleton a in P.Struct (",", [ a; skeleton b ])
        | P.Struct (";", [ a; b ]) -> let a = skeleton a in P.Struct (";", [ a; skeleton b ])
        | P.Struct ("->", [ a; b ]) -> let a = skeleton a in P.Struct ("->", [ a; skeleton b ])
        | P.Struct ("\\+", [ a ]) -> P.Struct ("\\+", [ skeleton a ])
        | P.Atom ("!" | "true" | "fail" | "false") as t -> t
        | t ->
            let v = P.fresh () in
            leaves := t :: !leaves;
            vars := v :: !vars;
            v in
      let body = skeleton goal in
      let head : P.term = match !vars with [] -> P.Atom "$call" | vs -> P.Struct ("$call", List.rev vs) in
      let code = Wam_compile.clause w.ctx (Prolog_db.clause (P.Struct (":-", [ head; body ]))) in
      grow w (max w.ctx.xneed (List.length !leaves));
      List.iteri (fun (i : int) (t : P.term) -> w.x.(i) <- t) (List.rev !leaves);
      w.b0 <- w.height;
      w.nargs <- List.length !leaves;
      jump w { code; pc = 0 }
  | P.Atom name -> enter w (Wam_compile.intern w.ctx name 0)
  | P.Struct (name, args) ->
      let n = List.length args in
      grow w n;
      List.iteri (fun (i : int) (a : P.term) -> w.x.(i) <- a) args;
      enter w (Wam_compile.intern w.ctx name n)
  | goal -> raise (M.type_error "callable" goal)

(*****************************************************************************)
(* An instruction *)
(*****************************************************************************)

let get (w : t) (r : Wam.reg) : P.term = match r with Wam.X i -> w.x.(i) | Wam.Y i -> w.e.y.(i)

let set (w : t) (r : Wam.reg) (t : P.term) : unit =
  match r with Wam.X i -> w.x.(i) <- t | Wam.Y i -> w.e.y.(i) <- t

(* write mode: one more argument; the last makes the structure *)
let give (w : t) (t : P.term) : unit =
  w.built <- t :: w.built;
  w.left <- w.left - 1;
  if w.left = 0 then begin
    let made = P.Struct (w.functor_, List.rev w.built) in
    match w.for_var with
    | Some v -> M.bind w.m v made
    | None -> w.x.(w.for_reg) <- made
  end

let rec has_length (l : P.term list) (n : int) : bool =
  match l with [] -> n = 0 | _ :: rest -> n > 0 && has_length rest (n - 1)

(* a constant against a term: the same, or a variable that gets it *)
let constant (w : t) (c : P.term) (t : P.term) : bool =
  match (P.deref t, c) with
  | P.Var v, _ -> M.bind w.m v c; true
  | P.Atom a, P.Atom b -> a = b
  | P.Int a, P.Int b -> a = b
  | _ -> false

let step (w : t) : unit =
  let m = w.m in
  let next (ok : bool) : unit = if ok then w.pc <- w.pc + 1 else backtrack w in
  match w.code.(w.pc) with
  | Wam.Get_variable (r, i) -> set w r w.x.(i); w.pc <- w.pc + 1
  | Wam.Get_value (r, i) -> next (M.unify m (get w r) w.x.(i))
  | Wam.Get_constant (c, i) -> next (constant w c w.x.(i))
  | Wam.Get_structure (f, n, i) -> (
      match P.deref w.x.(i) with
      | P.Struct (g, args) ->
          if g = f && has_length args n then begin
            w.write <- false;
            w.s <- args;
            w.pc <- w.pc + 1
          end
          else backtrack w
      | P.Var v ->
          w.write <- true;
          w.functor_ <- f;
          w.left <- n;
          w.built <- [];
          w.for_var <- Some v;
          w.pc <- w.pc + 1
      | _ -> backtrack w)
  | Wam.Put_variable (r, i) ->
      let v = P.fresh () in
      set w r v;
      w.x.(i) <- v;
      w.pc <- w.pc + 1
  | Wam.Put_value (r, i) -> w.x.(i) <- get w r; w.pc <- w.pc + 1
  | Wam.Put_constant (c, i) -> w.x.(i) <- c; w.pc <- w.pc + 1
  | Wam.Put_structure (f, n, i) ->
      w.write <- true;
      w.functor_ <- f;
      w.left <- n;
      w.built <- [];
      w.for_var <- None;
      w.for_reg <- i;
      w.pc <- w.pc + 1
  | Wam.Unify_variable r ->
      if w.write then begin
        let v = P.fresh () in
        set w r v;
        give w v
      end
      else begin
        match w.s with
        | a :: rest -> set w r a; w.s <- rest
        | [] -> ()
      end;
      w.pc <- w.pc + 1
  | Wam.Unify_value r ->
      if w.write then begin
        give w (get w r);
        w.pc <- w.pc + 1
      end
      else begin
        match w.s with
        | a :: rest -> w.s <- rest; next (M.unify m (get w r) a)
        | [] -> backtrack w
      end
  | Wam.Unify_constant c ->
      if w.write then begin
        give w c;
        w.pc <- w.pc + 1
      end
      else begin
        match w.s with
        | a :: rest -> w.s <- rest; next (constant w c a)
        | [] -> backtrack w
      end
  | Wam.Unify_void n ->
      for _i = 1 to n do
        if w.write then give w (P.fresh ()) else match w.s with _ :: rest -> w.s <- rest | [] -> ()
      done;
      w.pc <- w.pc + 1
  | Wam.Allocate n ->
      w.e <- { parent = Some w.e; return = w.cp; y = Array.make n P.nil; catch = None };
      w.pc <- w.pc + 1
  | Wam.Deallocate ->
      w.cp <- w.e.return;
      (match w.e.parent with Some f -> w.e <- f | None -> ());
      w.pc <- w.pc + 1
  | Wam.Call p ->
      w.cp <- { code = w.code; pc = w.pc + 1 };
      enter w p
  | Wam.Execute p -> enter w p
  | Wam.Proceed -> jump w w.cp
  | Wam.Builtin (_, n, f) ->
      m.steps <- m.steps + 1;
      next (f m (Array.sub w.x 0 n))
  | Wam.Fail -> backtrack w
  | Wam.Try a ->
      push w w.nargs { code = w.code; pc = w.pc + 1 };
      jump w a
  | Wam.Retry a ->
      (match w.choices with c :: _ -> c.alt <- { code = w.code; pc = w.pc + 1 } | [] -> ());
      jump w a
  | Wam.Trust a -> pop w; jump w a
  | Wam.Switch_on_term s -> (
      match P.deref w.x.(0) with
      | P.Atom a -> jump w (match Hashtbl.find_opt s.atoms a with Some t -> t | None -> s.other)
      | P.Int n -> jump w (match Hashtbl.find_opt s.ints n with Some t -> t | None -> s.other)
      | P.Struct (f, _) -> jump w (match Hashtbl.find_opt s.structs f with Some t -> t | None -> s.other)
      | _ -> jump w s.on_var)
  | Wam.Neck_cut -> cut_to w w.b0; w.pc <- w.pc + 1
  | Wam.Get_level r -> set w r (P.Int w.b0); w.pc <- w.pc + 1
  | Wam.Cut r ->
      (match P.deref (get w r) with P.Int height -> cut_to w height | _ -> ());
      w.pc <- w.pc + 1
  | Wam.Catch_enter (c, r) ->
      let mark : catch = { catcher = get w c; recovery = get w r; floor = w.height; trailed = m.trail_size } in
      (* a choice point that only fails: what the goal binds is on the
       * trail from here, for a throw to undo *)
      push w 0 pop_addr;
      w.e.catch <- Some mark;
      w.pc <- w.pc + 1
  | Wam.Catch_exit ->
      (match w.e.catch with
       | Some c -> if w.height = c.floor + 1 then cut_to w c.floor
       | None -> ());
      w.pc <- w.pc + 1
  | Wam.Stop -> w.status <- Answer

(*****************************************************************************)
(* throw, and running *)
(*****************************************************************************)

(* the nearest catch/3 the continuation is still inside, whose catcher
 * the ball unifies with: its recovery, with that catch's continuation *)
let rec recover (w : t) (ball : P.term) (f : frame) : unit =
  let outer () : unit = match f.parent with Some g -> recover w ball g | None -> raise (Uncaught ball) in
  match f.catch with
  | None -> outer ()
  | Some c ->
      cut_to w c.floor;
      M.undo w.m c.trailed;
      if M.unifiable w.m c.catcher ball && M.unify w.m c.catcher ball then begin
        (match f.parent with Some g -> w.e <- g | None -> ());
        w.cp <- f.return;
        meta w c.recovery
      end
      else outer ()

let run (w : t) : bool =
  let thrown : P.term option ref = ref None in
  (try
     while w.status = Running do
       try
         (match !thrown with
          | Some ball ->
              thrown := None;
              recover w ball w.e
          | None -> ());
         while w.status = Running do
           step w
         done
       with M.Throw ball ->
         (* (copied: undoing the trail must not undo the ball) *)
         thrown := Some (P.copy ball)
     done
   with Uncaught ball -> raise (M.Throw ball));
  w.status = Answer

let start (w : t) (goal : P.term) : unit =
  w.x.(0) <- goal;
  w.e <- root ();
  w.cp <- stop_addr;
  w.code <- w.boot;
  w.pc <- 0;
  w.status <- Running

let solve (w : t) (goal : P.term) : bool =
  let m = w.m in
  w.choices <- [];
  w.height <- 0;
  m.trail <- [];
  m.trail_size <- 0;
  m.young <- 0;
  start w goal;
  run w

let more (w : t) : bool =
  w.status <- Running;
  backtrack w;
  run w

(* inside a built-in: the registers and the rest are found again after *)
let once (w : t) (goal : P.term) : bool =
  let m = w.m in
  let x = Array.copy w.x and code = w.code and pc = w.pc and cp = w.cp and e = w.e in
  let choices = w.choices and height = w.height and b0 = w.b0 and nargs = w.nargs and status = w.status in
  let mark = m.trail_size and young = m.young in
  let restore () : unit =
    Array.blit x 0 w.x 0 (Array.length x);
    w.code <- code;
    w.pc <- pc;
    w.cp <- cp;
    w.e <- e;
    w.choices <- choices;
    w.height <- height;
    w.b0 <- b0;
    w.nargs <- nargs;
    w.status <- status;
    m.young <- young in
  w.choices <- [];
  w.height <- 0;
  start w goal;
  match run w with
  | ok ->
      restore ();
      if not ok then M.undo m mark;
      ok
  | exception exn ->
      restore ();
      M.undo m mark;
      raise exn

(*****************************************************************************)
(* The machine's own predicates *)
(*****************************************************************************)

(* catch/3 and findall/3, which the first machine has in OCaml over its
 * continuation: here in Prolog, over an instruction and a bag each *)
let own : string =
  {|catch(G, C, R) :- '$catch_enter'(C, R), call(G), '$catch_exit'.
findall(T, G, L) :- '$bag_new'(B), '$findall'(T, G, B), '$bag_get'(B, L).
'$findall'(T, G, B) :- call(G), '$bag_add'(B, T), fail.
'$findall'(_, _, _).
|}

let install (m : M.t) : t =
  let ctx = Wam_compile.create m in
  let call1 = Wam_compile.intern ctx "call" 1 in
  let w : t =
    { m; ctx; x = Array.make 256 P.nil; code = stop_addr.code; pc = 0; cp = stop_addr; e = root (); choices = [];
      height = 0; b0 = 0; nargs = 0; write = false; s = []; built = []; left = 0; functor_ = ""; for_var = None;
      for_reg = 0; status = No_answer; bags = Hashtbl.create 17; bag = 0; boot = [| Wam.Call call1; Wam.Stop |] } in
  let bag (a : P.term array) : int = match P.deref a.(0) with P.Int k -> k | _ -> -1 in
  M.define m "$bag_new" 1 (fun (m : M.t) (a : P.term array) ->
      w.bag <- w.bag + 1;
      Hashtbl.replace w.bags w.bag (ref []);
      M.unify m a.(0) (P.Int w.bag));
  M.define m "$bag_add" 2 (fun (_ : M.t) (a : P.term array) ->
      (match Hashtbl.find_opt w.bags (bag a) with Some r -> r := P.copy a.(1) :: !r | None -> ());
      true);
  M.define m "$bag_get" 2 (fun (m : M.t) (a : P.term array) ->
      let found : P.term list = match Hashtbl.find_opt w.bags (bag a) with Some r -> List.rev !r | None -> [] in
      Hashtbl.remove w.bags (bag a);
      M.unify m a.(1) (P.of_list found));
  (* its own clauses: kept here, not in the first machine's table *)
  let r = Prolog_read.make m.ops own in
  let rec load () : unit =
    match Prolog_read.next r with
    | None -> ()
    | Some (t, _) ->
        let c = Prolog_db.clause t in
        (match Prolog_db.functor_of c.head with
         | Some (name, arity) ->
             let p = Wam_compile.intern ctx name arity in
             let dbp : Prolog_db.pred =
               match p.kind with
               | Wam.User dbp -> dbp
               | _ ->
                   let dbp : Prolog_db.pred = { name; arity; clauses = []; added = []; dynamic = false } in
                   p.kind <- Wam.User dbp;
                   dbp in
             Prolog_db.add dbp ~front:false c
         | None -> ());
        load () in
  load ();
  m.engine <-
    Some
      { e_solve = (fun (goal : P.term) -> solve w goal);
        e_more = (fun () -> more w);
        e_has_more = (fun () -> match w.choices with [] -> false | _ -> true);
        e_once = (fun (goal : P.term) -> once w goal) };
  w

let listing (w : t) (name : string) (arity : int) : string option =
  match M.find_pred w.m name arity with
  | None -> None
  | Some dbp ->
      let p = Wam_compile.intern w.ctx name arity in
      p.kind <- Wam.User dbp;
      Wam_compile.link w.ctx p (Prolog_db.clauses dbp);
      Some (Wam_compile.listing w.m.ops p)
