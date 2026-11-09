(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMLCompile.mli *)
(* (for its operator |||, an option's value or a default: tiny-ml does not
 * read Common.( ||| )) *)
open Common
module Lexer = TinyMLLexer
module Tree = TinyMLTree
module Types = TinyMLTypes
module Machine = TinyMLMachine

(*****************************************************************************)
(* From the tree to the stack machine *)
(*****************************************************************************)

(* where a name's value is: a slot of the frame, a field of the
 * closure, a global of a unit (its table, its index), a static block *)
type loc = Slot of Machine.slot | Env of int | Glob of Machine.sym * int
  | Static of Machine.sym
(* a function whose code is known: that code, and its arity *)
type known = Machine.sym * int
(* a name's value, or a primitive (its name, its arity) *)
type binding = Loc of loc * known option | Ext of string * int

(* the values' table, as the types' (tglobals) *)
let globals : (string, binding) Hashtbl.t = Hashtbl.create 1024

type fn =
  { mutable code : Machine.ir list; mutable nslots : int; mutable ntries : int }

let cur = ref { code = []; nslots = 1; ntries = 0 }
let emit i = (!cur).code <- i :: (!cur).code
let slot () : Machine.slot = let s = (!cur).nslots in (!cur).nslots <- s + 1; s

(* a function's code begun, its frame of that many slots and handlers
 * so far; then made, its label and parameters' count *)
let start_fun nslots ntries =
  cur := { code = []; nslots = nslots; ntries = ntries }
let finish_fun (lab : Machine.sym) nparams =
  Machine.machine lab nparams (!cur).nslots (List.rev (!cur).code)
(* the functions to compile, in their order: a queue as two lists, the
 * next ones and the ones added since, last first (old: OCaml's Queue,
 * which TinyLibCore does not have) *)
let queue : (unit -> unit) list ref = ref []
and queued : (unit -> unit) list ref = ref []
let enqueue f = queued := f :: !queued
let rec dequeue () =
  match !queue, !queued with
  | f :: rest, _ -> queue := rest; Some f
  | [], [] -> None
  | [], l -> queue := List.rev l; queued := []; dequeue ()
let nfuns = ref 0

let fun_label x =
  incr nfuns;
  (!Tree.unit_name ^ ".f" ^ string_of_int !nfuns ^ "_"
   ^ (String.map (fun c ->
          if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
             || (c >= '0' && c <= '9') || c = '_'
          then c
          else '_')
        x))

let lookup env x =
  match Types.find_name env globals x with
  | Some b -> b
  | None -> Lexer.error ("unbound " ^ x)

let rec pat_vars = function
  | Tree.PAny | Tree.PConst _ -> []
  | Tree.PVar x -> [ x ]
  | Tree.PCon (_, ps) -> List.concat_map pat_vars ps
  | Tree.PTuple ps -> List.concat_map pat_vars ps
  | Tree.PRecord (fs, _, _) -> List.concat_map (fun (_, p) -> pat_vars p) fs
  | Tree.PAlias (p, x) -> x :: pat_vars p
  | Tree.PAnnot (p, _) -> pat_vars p
  | Tree.POr (p, _) -> pat_vars p

(* the names free in e, each once, in their order *)
(* (old: or-patterns with names, Match (e, cs) | Try (e, cs): written
 * apart, as tiny-ml compiles this file too) *)
let rec free bound e acc =
  let fr = free bound in
  let cases e cs =
    List.fold_left (fun acc (p, g, b) ->
      let bound = pat_vars p @ bound in
      free bound b (match g with Some g -> free bound g acc | None -> acc))
      (fr e acc) cs in
  match e with
  | Tree.Const _ -> acc
  | Tree.Var (x, _) ->
      if List.mem x bound || List.mem x acc then acc else acc @ [ x ]
  | Tree.Con (_, l) -> List.fold_left (fun acc e -> fr e acc) acc l
  | Tree.Tuple l -> List.fold_left (fun acc e -> fr e acc) acc l
  | Tree.App (f, l) -> List.fold_left (fun acc e -> fr e acc) acc (f :: l)
  | Tree.Fun (xs, b) -> free (xs @ bound) b acc
  | Tree.Let (r, bs, b) ->
      let vs = List.concat_map (fun (p, _) -> pat_vars p) bs in
      let acc =
        List.fold_left
          (fun acc (_, e) ->
             free (if r = Tree.Recursive then vs @ bound else bound) e acc)
          acc bs
      in
      free (vs @ bound) b acc
  | Tree.Match (e, cs) -> cases e cs
  | Tree.Try (e, cs) -> cases e cs
  | Tree.If (a, b, c) -> fr c (fr b (fr a acc))
  | Tree.Seq (a, b) -> fr b (fr a acc)
  | Tree.While (a, b) -> fr b (fr a acc)
  | Tree.For (x, a, b, _, body) -> free (x :: bound) body (fr b (fr a acc))
  | Tree.Record (fs, _) -> List.fold_left (fun acc (_, e) -> fr e acc) acc fs
  | Tree.With (e, fs, _, _) ->
      List.fold_left (fun acc (_, e) -> fr e acc) (fr e acc) fs
  | Tree.Dot (e, _, _) -> fr e acc
  | Tree.SetDot (e, _, _, v) -> fr v (fr e acc)

(* the free names a closure must hold: those of the enclosing function,
 * among the names free in it *)
let captured env names =
  List.filter (fun x ->
      match List.assoc_opt x env with
      | Some (Loc ((Slot _ | Env _), _)) -> true
      | _ -> false)
    names

(* a function's names: its closure's fields, then the others it names,
 * found now (the toplevel's table changes before its code is made;
 * old: the env's names that are not local, all of them) *)
let body_env env names fvs =
  List.mapi (fun j x ->
      x, match lookup env x with Loc (_, k) -> Loc (Env j, k) | b -> b)
    fvs
  @ List.filter_map
      (fun x -> if List.mem x fvs then None else Some (x, lookup env x))
      names

let rec refutable = function
  | Tree.PAny | Tree.PVar _ -> false
  | Tree.PAlias (p, _) -> refutable p
  | Tree.PAnnot (p, _) -> refutable p
  | Tree.PTuple ps -> List.exists refutable ps
  | Tree.PRecord (fs, _, _) -> List.exists (fun (_, p) -> refutable p) fs
  | Tree.PCon (c, ps) ->
      let ci = Tree.find_con c in
      ci.nconst + ci.nblock > 1 || ci.kind = Tree.KExn
      || List.exists refutable ps
  | Tree.PConst _ | Tree.POr _ -> true

(* the tests of p against the value in slot s, each jumping to fail;
 * its names bound to slots *)
let rec test acc s p fail =
  let check l = emit (Machine.Get s); List.iter emit l;
  emit (Machine.Jz fail) in
  let fields base ps acc =
    fst (List.fold_left (fun (acc, k) p ->
      (match p with
       | Tree.PAny -> acc
       | p ->
           let s' = slot () in
           emit (Machine.Get s); emit (Machine.Field k); emit (Machine.Set s');
           test acc s' p fail), k + 1)
      (acc, base) ps)
  in
  match p with
  | Tree.PAny -> acc
  | Tree.PVar x -> (x, Loc (Slot s, None)) :: acc
  | Tree.PAlias (p, x) -> test ((x, Loc (Slot s, None)) :: acc) s p fail
  | Tree.PAnnot (p, _) -> test acc s p fail
  | Tree.PConst (Tree.CInt n) ->
    check [ Machine.Imm (Machine.tagged n);
      Machine.Op (Machine.Cmp Machine.Eq) ]; acc
  | Tree.PConst (Tree.CChar n) ->
    check [ Machine.Imm (Machine.tagged n);
      Machine.Op (Machine.Cmp Machine.Eq) ]; acc
  | Tree.PConst (Tree.CStr str) ->
      check [ Machine.Addr (Machine.static_string str);
        Machine.CallC ("ml_equal", 2) ]; acc
  | Tree.PTuple ps -> fields 0 ps acc
  (* a record is a tuple: the fields not named are _ *)
  | Tree.PRecord (fs, idxs, n) ->
      let at = List.combine !idxs (List.map snd fs) in
      fields 0 (List.init !n (fun k -> List.assoc_opt k at ||| Tree.PAny)) acc
  | Tree.PCon (c, ps) ->
      let ci = Tree.find_con c in
      (match ci.kind with
       | Tree.KConst n ->
           if ci.nconst + ci.nblock > 1 then
             check [ Machine.Imm (Machine.tagged n);
               Machine.Op (Machine.Cmp Machine.Eq) ]
       | Tree.KBlock t ->
           if ci.nconst > 0 then
             (emit (Machine.Get s); emit (Machine.Op Machine.IsInt);
               emit (Machine.Jnz fail));
           if ci.nblock > 1 then
             check [ Machine.Op Machine.Tag; Machine.Imm (Machine.tagged t);
               Machine.Op (Machine.Cmp Machine.Eq) ]
       | Tree.KExn ->
         check [ Machine.Field 0; Machine.Addr (Machine.exn_id c);
           Machine.Op (Machine.Cmp Machine.Eq) ]);
      fields (if ci.kind = Tree.KExn then 1 else 0) ps acc
  | Tree.POr (a, b) ->
      let other = Machine.label () and ok = Machine.label () in
      ignore (test acc s a other);
      emit (Machine.Jmp ok);
      emit (Machine.Label other);
      ignore (test acc s b fail);
      emit (Machine.Label ok);
      acc

let match_failure () = emit (Machine.Addr (Machine.exn_const "Match_failure"));
emit Machine.Raise

(* a primitive: an instruction, or a call of the runtime; a comparison
 * of integers inlined, the others the runtime's compare *)
let prim p n ty =
  let int_arg =
    match Types.repr ty with
    | Tree.TCon ("->", [ a; _ ]) ->
        (match Types.repr a with
         | Tree.TCon (("int" | "char" | "bool" | "unit"), []) -> true
         | _ -> false)
    | _ -> false
  in
  let rel r =
    if int_arg then emit (Machine.Op (Machine.Cmp r))
    else
      match r with
      | Machine.Eq -> emit (Machine.CallC ("ml_equal", 2))
      | Machine.Ne -> emit (Machine.CallC ("ml_equal", 2));
      emit (Machine.Op Machine.Not)
      | r ->
          (* compare's result r 0 is 0 r' compare's result *)
          emit (Machine.CallC ("ml_compare", 2));
          emit (Machine.Imm (Machine.tagged 0));
          emit (Machine.Op (Machine.Cmp (match r with
            | Machine.Lt -> Machine.Gt | Machine.Gt -> Machine.Lt
              | Machine.Le -> Machine.Ge | Machine.Ge -> Machine.Le | r -> r)))
  in
  let ops =
    [ "%add", Machine.Add; "%sub", Machine.Sub; "%mul", Machine.Mul; "%div",
      Machine.Div; "%mod", Machine.Mod;
              "%and", Machine.And; "%or", Machine.Or; "%xor", Machine.Xor;
              "%lsl", Machine.Lsl; "%lsr", Machine.Lsr;
              "%asr", Machine.Asr; "%neg", Machine.Neg; "%lnot", Machine.Lnot;
              "%not", Machine.Not ] in
  let rels =
    [ "%eq", Machine.Eq; "%neq", Machine.Ne; "%lt", Machine.Lt; "%le",
      Machine.Le; "%gt", Machine.Gt; "%ge", Machine.Ge ] in
  match p with
  | _ when List.mem_assoc p ops -> emit (Machine.Op (List.assoc p ops))
  | _ when List.mem_assoc p rels -> rel (List.assoc p rels)
  | "%physeq" -> emit (Machine.Op (Machine.Cmp Machine.Eq))
  | "%physneq" -> emit (Machine.Op (Machine.Cmp Machine.Ne))
  | "%ref" -> emit (Machine.Alloc (0, 1))
  | "%field0" -> emit (Machine.Field 0)
  | "%field1" -> emit (Machine.Field 1)
  | "%setfield0" -> emit (Machine.SetField 0);
  emit (Machine.Imm (Machine.tagged 0))
  | "%raise" -> emit Machine.Raise
  | "%identity" -> ()
  | "%ignore" -> emit Machine.Drop; emit (Machine.Imm (Machine.tagged 0))
  | _ when p.[0] = '%' -> Lexer.error ("unknown primitive " ^ p)
  | _ -> emit (Machine.CallC (p, n))

(* a closure: static, its symbol, when it captures nothing, else
 * built on the stack; each with its code's label and arity *)
type closure =
  | Closure_static of Machine.sym * Machine.sym * int
  | Closure_pushed of Machine.sym * int

(* e's value pushed *)
let rec value env e =
  match e with
  | Tree.Const (Tree.CInt n) -> emit (Machine.Imm (Machine.tagged n))
  | Tree.Const (Tree.CChar n) -> emit (Machine.Imm (Machine.tagged n))
  | Tree.Const (Tree.CStr s) -> emit (Machine.Addr (Machine.static_string s))
  | Tree.Var (x, _) -> var env x
  | Tree.Con (c, args) -> (
      match (Tree.find_con c).kind with
      | Tree.KConst n -> emit (Machine.Imm (Machine.tagged n))
      | Tree.KBlock t ->
          List.iter (value env) (List.rev args);
          emit (Machine.Alloc (t, List.length args))
      | Tree.KExn when args = [] -> emit (Machine.Addr (Machine.exn_const c))
      | Tree.KExn ->
          List.iter (value env) (List.rev args);
          emit (Machine.Addr (Machine.exn_id c));
          emit (Machine.Alloc (0, 1 + List.length args)))
  | Tree.Tuple es -> fields_block (List.map (fun e () -> value env e) es)
  (* a record is a tuple of its fields in their declaration's order,
   * evaluated as ocamlopt does, right to left *)
  | Tree.Record (fs, order) ->
      value env
        (Tree.Tuple
           (List.map snd
              (List.sort (fun (a, _) (b, _) -> compare a b)
                 (List.combine !order (List.map snd fs)))))
  (* the record copied first, kept in a slot (unless it is a variable,
   * read again for each field); then the fields, the new ones and the
   * copied ones, right to left as in a record *)
  | Tree.With (e, fs, idxs, n) ->
      let base = match e with
        | Tree.Var _ -> (fun () -> value env e)
        | _ ->
            value env e;
            let s = slot () in
            emit (Machine.Set s);
            (fun () -> emit (Machine.Get s)) in
      let given = List.combine !idxs (List.map snd fs) in
      fields_block (List.init !n (fun k () ->
        match List.assoc_opt k given with
        | Some v -> value env v
        | None -> base (); emit (Machine.Field k)))
  | Tree.Dot (e, _, i) -> value env e; emit (Machine.Field !i)
  | Tree.SetDot (e, _, i, v) ->
      value env v; value env e; emit (Machine.SetField !i);
      emit (Machine.Imm (Machine.tagged 0))
  | Tree.App (f, args) -> ignore (app env f args false)
  | Tree.Fun (xs, b) ->
      (match closure env "fun" xs b with
       | Closure_static (sym, _, _) -> emit (Machine.Addr sym)
       | Closure_pushed _ -> ())
  | Tree.Let _ | Tree.Match _ | Tree.If _ | Tree.Seq _ -> control env e false
  | Tree.Try (b, cases) ->
      let k = (!cur).ntries in
      (!cur).ntries <- k + 1;
      let handler = Machine.label () and out = Machine.label () in
      emit (Machine.TryEnter (k, handler));
      value env b;
      emit (Machine.TryExit k);
      emit (Machine.Jmp out);
      emit (Machine.Label handler);
      emit (Machine.Catch k);
      let s = slot () in
      emit (Machine.Set s);
      (* no clause matches: raised again *)
      match_cases env s cases false
        (fun () -> emit (Machine.Get s); emit Machine.Raise);
      emit (Machine.Label out)
  | Tree.While (c, b) ->
      let top = Machine.label () and out = Machine.label () in
      emit (Machine.Label top); value env c; emit (Machine.Jz out); value env b;
      emit Machine.Drop;
      emit (Machine.Jmp top); emit (Machine.Label out);
      emit (Machine.Imm (Machine.tagged 0))
  | Tree.For (x, a, b, up, body) ->
      value env a;
      let i = slot () in
      emit (Machine.Set i);
      value env b;
      let lim = slot () in
      emit (Machine.Set lim);
      let top = Machine.label () and out = Machine.label () in
      emit (Machine.Label top);
      emit (Machine.Get lim); emit (Machine.Get i);
      emit (Machine.Op (Machine.Cmp (if up then Machine.Gt else Machine.Lt)));
      emit (Machine.Jnz out);
      value ((x, Loc (Slot i, None)) :: env) body;
      emit Machine.Drop;
      emit (Machine.Imm (Machine.tagged 1)); emit (Machine.Get i);
      emit (Machine.Op (if up then Machine.Add else Machine.Sub));
      emit (Machine.Set i);
      emit (Machine.Jmp top);
      emit (Machine.Label out);
      emit (Machine.Imm (Machine.tagged 0))

(* e as a function's last: its value returned, or a call made a jump *)
(* A block of the fields given in their order, computed right to left
 * (ocamlopt's order): each on the stack of registers, then allocated
 * and filled. Past 11 fields there are not the registers: the block
 * allocated first, blank, kept in a slot, each field stored in it as
 * it is computed (a process of tiny-kernel's, 12) *)
and fields_block fields =
  let n = List.length fields in
  if n <= 11 then
    (List.iter (fun f -> f ()) (List.rev fields); emit (Machine.Alloc (0, n)))
  else begin
    emit (Machine.Blank (0, n));
    let s = slot () in
    emit (Machine.Set s);
    List.iteri (fun k f ->
      let k = n - 1 - k in
      f (); emit (Machine.Get s); emit (Machine.SetField k)) (List.rev fields);
    emit (Machine.Get s)
  end

and tail env e =
  match e with
  | Tree.App (f, args) -> if not (app env f args true) then emit Machine.Ret
  | Tree.Let _ | Tree.Match _ | Tree.If _ | Tree.Seq _ -> control env e true
  | _ -> value env e; emit Machine.Ret

and control env e tl =
  let k env e = if tl then tail env e else value env e in
  match e with
  | Tree.Seq (a, b) -> value env a; emit Machine.Drop; k env b
  | Tree.If (c, a, b) ->
      let other = Machine.label () in
      value env c;
      emit (Machine.Jz other);
      k env a;
      if tl then (emit (Machine.Label other); k env b)
      else (
        let out = Machine.label () in
        emit (Machine.Jmp out); emit (Machine.Label other); k env b;
        emit (Machine.Label out))
  | Tree.Let (r, bs, body) -> k (bind env r bs) body
  | Tree.Match (e, cases) ->
      value env e;
      let s = slot () in
      emit (Machine.Set s);
      match_cases env s cases tl match_failure
  | _ -> invalid_arg "control"

(* the clauses in order, each tests then its body; after an irrefutable
 * one, nothing *)
and match_cases env s cases tl on_fail =
  let out = Machine.label () in
  let rec go = function
    | [] -> on_fail ()
    | (p, g, body) :: rest ->
        let fail = Machine.label () in
        let env = test env s p fail in
        Option.iter (fun g -> value env g; emit (Machine.Jz fail)) g;
        if tl then tail env body else (value env body; emit (Machine.Jmp out));
        if refutable p || g <> None then (emit (Machine.Label fail); go rest)
  in
  go cases;
  if not tl then emit (Machine.Label out)

and var env x =
  match lookup env x with
  | Loc (Slot s, _) -> emit (Machine.Get s)
  | Loc (Env j, _) -> emit (Machine.Get 0); emit (Machine.Field (2 + j))
  | Loc (Glob (t, g), _) -> emit (Machine.GetG (t, g))
  | Loc (Static sym, _) -> emit (Machine.Addr sym)
  | Ext (_, n) ->
      (* a primitive as a value: the function that applies it *)
      let xs = List.init n (fun i -> Printf.sprintf "%%e%d" i) in
      value env
        (Tree.Fun (xs, Tree.App (TinyMLTree.var x, List.map TinyMLTree.var xs)))

(* f args: a primitive, a known function's code called with its
 * arguments, or the closure applied to one at a time; whether it ended
 * in a tail call *)
and app env f args tl =
  let m = List.length args in
  let rest k =
    let n = m - k in
    for i = 1 to n do emit (Machine.Call (Machine.Indirect 0, 1, tl && i = n))
      done;
    tl && n > 0
  in
  let args_in k =
    let first = List.filteri (fun i _ -> i < k) args
    and later = List.filteri (fun i _ -> i >= k) args in
    List.iter (value env) (List.rev later);
    List.iter (value env) (List.rev first)
  in
  match f with
  | Tree.Var (x, ty) -> (
      match lookup env x with
      | Ext (p, n) when m >= n -> args_in n; prim p n !ty; rest n
      | Loc (_, Some (lab, n)) when m >= n ->
          args_in n;
          var env x;
          emit (Machine.Call (Machine.Direct lab, n, tl && m = n));
          if m = n then tl else rest n
      | _ -> args_in m; value env f; rest 0)
  | _ -> args_in m; value env f; rest 0

(* let: the values in env, then their names *)
and bind env (r : Tree.rec_flag) bs =
  if r = Tree.Recursive then bind_rec env bs
  else
    List.concat_map (fun (p, e) ->
      match p, e with
      | Tree.PVar x, Tree.Fun (xs, b) -> (
          match closure env x xs b with
          | Closure_static (sym, lab, n) ->
              [ x, Loc (Static sym, Some (lab, n)) ]
          | Closure_pushed (lab, n) ->
              let s = slot () in
              emit (Machine.Set s);
              [ x, Loc (Slot s, Some (lab, n)) ])
      | Tree.PAny, _ -> value env e; emit Machine.Drop; []
      | _ ->
          value env e; let s = slot () in emit (Machine.Set s); irrefutably s p)
            bs
    @ env

and irrefutably s p =
  if not (refutable p) then test [] s p 0
  else begin
    let fail = Machine.label () and ok = Machine.label () in
    let bs = test [] s p fail in
    emit (Machine.Jmp ok); emit (Machine.Label fail); match_failure ();
    emit (Machine.Label ok);
    bs
  end

(* a function: its code compiled later; its closure static without
 * free variables, else allocated *)
and closure env name xs b =
  let lab = fun_label name and n = List.length xs in
  let names = free [] (Tree.Fun (xs, b)) [] in
  let fvs = captured env names in
  let benv = body_env env names fvs in
  enqueue (fun () -> compile_fun lab xs benv b);
  if fvs = [] then Closure_static (Machine.static_closure lab n, lab, n)
  else begin
    alloc_closure env lab n fvs;
    Closure_pushed (lab, n)
  end

(* (more than eight names: the block made blank, then each field set
 * through a slot of the frame, so that the names are not all in
 * registers at once; old: always on the stack, and a closure of ten
 * names too deep, tiny-db's parse) *)
and alloc_closure env lab n fvs =
  if List.length fvs <= 8 then begin
    List.iter (var env) (List.rev fvs);
    emit (Machine.Addr lab);
    emit (Machine.Addr (Machine.entry n lab));
    emit (Machine.Alloc (Machine.closure_tag, 2 + List.length fvs))
  end
  else begin
    let s = slot () in
    let field k push = push (); emit (Machine.Get s);
    emit (Machine.SetField k) in
    emit (Machine.Blank (Machine.closure_tag, 2 + List.length fvs));
    emit (Machine.Set s);
    field 0 (fun () -> emit (Machine.Addr (Machine.entry n lab)));
    field 1 (fun () -> emit (Machine.Addr lab));
    List.iteri (fun j y -> field (2 + j) (fun () -> var env y)) fvs;
    emit (Machine.Get s)
  end

(* let rec: static if the functions need nothing but each other; else
 * their closures allocated, then those that name a later one patched *)
and bind_rec env bs =
  let fs =
    List.map
      (function
        | Tree.PVar x, Tree.Fun (xs, b) -> x, xs, b
        | _ -> Lexer.error "let rec: only functions")
      bs
  in
  let labs = List.map (fun (x, xs, _) -> fun_label x, List.length xs) fs in
  let statics =
    List.map2
      (fun (x, _, _) (lab, n) ->
        x, Loc (Static (Machine.closure_sym lab), Some (lab, n)))
      fs labs
    @ env
  in
  let namess = List.map (fun (_, xs, b) -> free [] (Tree.Fun (xs, b)) []) fs in
  if List.for_all (fun names -> captured statics names = []) namess then begin
    List.iter2 (fun ((_, xs, b), names) (lab, n) ->
      ignore (Machine.static_closure lab n);
      let benv = body_env statics names [] in
      enqueue (fun () -> compile_fun lab xs benv b)) (List.combine fs namess)
        labs;
    statics
  end
  else begin
    let slots = List.map (fun _ -> slot ()) fs in
    let env =
      List.map2 (fun (x, _, _) ((lab, n), s) -> x, Loc (Slot s, Some (lab, n)))
        fs (List.combine labs slots)
      @ env
    in
    let names = List.map (fun (x, _, _) -> x) fs in
    let fvss = List.map (captured env) namess in
    List.iteri (fun i ((_, xs, b), fvs) ->
      let lab, n = List.nth labs i in
      let benv = body_env env (List.nth namess i) fvs in
      enqueue (fun () -> compile_fun lab xs benv b);
      alloc_closure env lab n fvs;
      emit (Machine.Set (List.nth slots i))) (List.combine fs fvss);
    fvss |> List.iteri (fun i fvs ->
      fvs |> List.iteri (fun j y ->
        let rec index k = function
          | [] -> None
          | z :: l -> if z = y then Some k else index (k + 1) l in
        match index 0 names with
        | Some m when m >= i ->
            emit (Machine.Get (List.nth slots m));
            emit (Machine.Get (List.nth slots i));
            emit (Machine.SetField (2 + j))
        | _ -> ()));
    env
  end

and compile_fun lab xs benv b =
  start_fun (1 + List.length xs) 0;
  let env =
    List.rev (List.mapi (fun i x -> x, Loc (Slot (i + 1), None)) xs) @ benv in
  tail env b;
  finish_fun lab (List.length xs)

(* ml_curry<n>_<k>: a closure of arity n given its k+1-th argument; a
 * block [the next one; the closure; the k arguments...], or the call *)
let curry_fun n k =
  start_fun 2 0;
  emit (Machine.Get 1);
  for i = k downto 1 do emit (Machine.Get 0); emit (Machine.Field (1 + i)) done;
  emit (Machine.Get 0);
  if k > 0 then emit (Machine.Field 1);
  if k < n - 1 then (
    emit (Machine.Addr (Machine.curry n (k + 1)));
    emit (Machine.Alloc (Machine.closure_tag, k + 3));
    emit Machine.Ret)
  else emit (Machine.Call (Machine.Indirect 1, n, true));
  finish_fun (Machine.curry n k) 1
