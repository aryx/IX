(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMLCompile.mli *)
open Common
open TinyMLLexer
open TinyMLTree
open TinyMLTypes
open TinyMLMachine

(*****************************************************************************)
(* From the tree to the stack machine *)
(*****************************************************************************)

(* where a name's value is, and, for a function whose code is known,
 * that code and its arity *)
type loc = Slot of int | Env of int | Glob of string * int | Static of string
type binding = Loc of loc * (string * int) option | Ext of string * int

(* the values' table, as the types' (tglobals) *)
let globals : (string, binding) Hashtbl.t = Hashtbl.create 1024

type fn =
  { mutable code : ir list; mutable nslots : int; mutable ntries : int }

let cur = ref { code = []; nslots = 1; ntries = 0 }
let emit i = (!cur).code <- i :: (!cur).code
let slot () = let s = (!cur).nslots in (!cur).nslots <- s + 1; s
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
  (!unit_name ^ ".f" ^ string_of_int !nfuns ^ "_"
   ^ (String.map (fun c ->
          if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
             || (c >= '0' && c <= '9') || c = '_'
          then c
          else '_')
        x))

let lookup env x =
  match find_name env globals x with
  | Some b -> b
  | None -> error ("unbound " ^ x)

let rec pat_vars = function
  | PAny | PConst _ -> []
  | PVar x -> [ x ]
  | PCon (_, ps) -> List.concat_map pat_vars ps
  | PTuple ps -> List.concat_map pat_vars ps
  | PRecord (fs, _, _) -> List.concat_map (fun (_, p) -> pat_vars p) fs
  | PAlias (p, x) -> x :: pat_vars p
  | PAnnot (p, _) -> pat_vars p
  | POr (p, _) -> pat_vars p

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
  | Const _ -> acc
  | Var (x, _) ->
      if List.mem x bound || List.mem x acc then acc else acc @ [ x ]
  | Con (_, l) -> List.fold_left (fun acc e -> fr e acc) acc l
  | Tuple l -> List.fold_left (fun acc e -> fr e acc) acc l
  | App (f, l) -> List.fold_left (fun acc e -> fr e acc) acc (f :: l)
  | Fun (xs, b) -> free (xs @ bound) b acc
  | Let (r, bs, b) ->
      let vs = List.concat_map (fun (p, _) -> pat_vars p) bs in
      let acc =
        List.fold_left
          (fun acc (_, e) -> free (if r then vs @ bound else bound) e acc)
          acc bs
      in
      free (vs @ bound) b acc
  | Match (e, cs) -> cases e cs
  | Try (e, cs) -> cases e cs
  | If (a, b, c) -> fr c (fr b (fr a acc))
  | Seq (a, b) -> fr b (fr a acc)
  | While (a, b) -> fr b (fr a acc)
  | For (x, a, b, _, body) -> free (x :: bound) body (fr b (fr a acc))
  | Record (fs, _) -> List.fold_left (fun acc (_, e) -> fr e acc) acc fs
  | With (e, fs, _, _) ->
      List.fold_left (fun acc (_, e) -> fr e acc) (fr e acc) fs
  | Dot (e, _, _) -> fr e acc
  | SetDot (e, _, _, v) -> fr v (fr e acc)

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
  | PAny | PVar _ -> false
  | PAlias (p, _) -> refutable p
  | PAnnot (p, _) -> refutable p
  | PTuple ps -> List.exists refutable ps
  | PRecord (fs, _, _) -> List.exists (fun (_, p) -> refutable p) fs
  | PCon (c, ps) ->
      let ci = find_con c in
      ci.nconst + ci.nblock > 1 || ci.kind = KExn || List.exists refutable ps
  | PConst _ | POr _ -> true

(* the tests of p against the value in slot s, each jumping to fail;
 * its names bound to slots *)
let rec test acc s p fail =
  let check l = emit (Get s); List.iter emit l; emit (Jz fail) in
  let fields base ps acc =
    fst (List.fold_left (fun (acc, k) p ->
      (match p with
       | PAny -> acc
       | p ->
           let s' = slot () in
           emit (Get s); emit (Field k); emit (Set s');
           test acc s' p fail), k + 1)
      (acc, base) ps)
  in
  match p with
  | PAny -> acc
  | PVar x -> (x, Loc (Slot s, None)) :: acc
  | PAlias (p, x) -> test ((x, Loc (Slot s, None)) :: acc) s p fail
  | PAnnot (p, _) -> test acc s p fail
  | PConst (CInt n) -> check [ Imm (tagged n); Op (Cmp Eq) ]; acc
  | PConst (CChar n) -> check [ Imm (tagged n); Op (Cmp Eq) ]; acc
  | PConst (CStr str) ->
      check [ Addr (static_string str, 8); CallC ("ml_equal", 2) ]; acc
  | PTuple ps -> fields 0 ps acc
  (* a record is a tuple: the fields not named are _ *)
  | PRecord (fs, idxs, n) ->
      let at = List.combine !idxs (List.map snd fs) in
      fields 0 (List.init !n (fun k -> List.assoc_opt k at ||| PAny)) acc
  | PCon (c, ps) ->
      let ci = find_con c in
      (match ci.kind with
       | KConst n ->
           if ci.nconst + ci.nblock > 1 then check [ Imm (tagged n); Op (Cmp Eq) ]
       | KBlock t ->
           if ci.nconst > 0 then (emit (Get s); emit (Op IsInt); emit (Jnz fail));
           if ci.nblock > 1 then check [ Op Tag; Imm (tagged t); Op (Cmp Eq) ]
       | KExn -> check [ Field 0; Addr (exn_id c, 8); Op (Cmp Eq) ]);
      fields (if ci.kind = KExn then 1 else 0) ps acc
  | POr (a, b) ->
      let other = label () and ok = label () in
      ignore (test acc s a other);
      emit (Jmp ok);
      emit (Label other);
      ignore (test acc s b fail);
      emit (Label ok);
      acc

let match_failure () = emit (Addr (exn_const "Match_failure", 8)); emit Raise

(* a primitive: an instruction, or a call of the runtime; a comparison
 * of integers inlined, the others the runtime's compare *)
let prim p n ty =
  let int_arg =
    match repr ty with
    | TCon ("->", [ a; _ ]) ->
        (match repr a with
         | TCon (("int" | "char" | "bool" | "unit"), []) -> true
         | _ -> false)
    | _ -> false
  in
  let rel r =
    if int_arg then emit (Op (Cmp r))
    else
      match r with
      | Eq -> emit (CallC ("ml_equal", 2))
      | Ne -> emit (CallC ("ml_equal", 2)); emit (Op Not)
      | r ->
          (* compare's result r 0 is 0 r' compare's result *)
          emit (CallC ("ml_compare", 2)); emit (Imm (tagged 0));
          emit (Op (Cmp (match r with
            | Lt -> Gt | Gt -> Lt | Le -> Ge | Ge -> Le | r -> r)))
  in
  let ops = [ "%add", Add; "%sub", Sub; "%mul", Mul; "%div", Div; "%mod", Mod;
              "%and", And; "%or", Or; "%xor", Xor; "%lsl", Lsl; "%lsr", Lsr;
              "%asr", Asr; "%neg", Neg; "%lnot", Lnot; "%not", Not ] in
  let rels = [ "%eq", Eq; "%neq", Ne; "%lt", Lt; "%le", Le; "%gt", Gt; "%ge", Ge ] in
  match p with
  | _ when List.mem_assoc p ops -> emit (Op (List.assoc p ops))
  | _ when List.mem_assoc p rels -> rel (List.assoc p rels)
  | "%physeq" -> emit (Op (Cmp Eq))
  | "%physneq" -> emit (Op (Cmp Ne))
  | "%ref" -> emit (Alloc (0, 1))
  | "%field0" -> emit (Field 0)
  | "%field1" -> emit (Field 1)
  | "%setfield0" -> emit (SetField 0); emit (Imm (tagged 0))
  | "%raise" -> emit Raise
  | "%identity" -> ()
  | "%ignore" -> emit Drop; emit (Imm (tagged 0))
  | _ when p.[0] = '%' -> error ("unknown primitive " ^ p)
  | _ -> emit (CallC (p, n))

(* a closure: static, its symbol, when it captures nothing, else
 * built on the stack; each with its code's label and arity *)
type closure =
  | Closure_static of string * string * int
  | Closure_pushed of string * int

(* e's value pushed *)
let rec value env e =
  match e with
  | Const (CInt n) -> emit (Imm (tagged n))
  | Const (CChar n) -> emit (Imm (tagged n))
  | Const (CStr s) -> emit (Addr (static_string s, 8))
  | Var (x, _) -> var env x
  | Con (c, args) -> (
      match (find_con c).kind with
      | KConst n -> emit (Imm (tagged n))
      | KBlock t ->
          List.iter (value env) (List.rev args);
          emit (Alloc (t, List.length args))
      | KExn when args = [] -> emit (Addr (exn_const c, 8))
      | KExn ->
          List.iter (value env) (List.rev args);
          emit (Addr (exn_id c, 8));
          emit (Alloc (0, 1 + List.length args)))
  | Tuple es -> fields_block (List.map (fun e () -> value env e) es)
  (* a record is a tuple of its fields in their declaration's order,
   * evaluated as ocamlopt does, right to left *)
  | Record (fs, order) ->
      value env
        (Tuple
           (List.map snd
              (List.sort (fun (a, _) (b, _) -> compare a b)
                 (List.combine !order (List.map snd fs)))))
  (* the record copied first, kept in a slot (unless it is a variable,
   * read again for each field); then the fields, the new ones and the
   * copied ones, right to left as in a record *)
  | With (e, fs, idxs, n) ->
      let base = match e with
        | Var _ -> (fun () -> value env e)
        | _ ->
            value env e;
            let s = slot () in
            emit (Set s);
            (fun () -> emit (Get s)) in
      let given = List.combine !idxs (List.map snd fs) in
      fields_block (List.init !n (fun k () ->
        match List.assoc_opt k given with
        | Some v -> value env v
        | None -> base (); emit (Field k)))
  | Dot (e, _, i) -> value env e; emit (Field !i)
  | SetDot (e, _, i, v) ->
      value env v; value env e; emit (SetField !i); emit (Imm (tagged 0))
  | App (f, args) -> ignore (app env f args false)
  | Fun (xs, b) ->
      (match closure env "fun" xs b with
       | Closure_static (sym, _, _) -> emit (Addr (sym, 8))
       | Closure_pushed _ -> ())
  | Let _ | Match _ | If _ | Seq _ -> control env e false
  | Try (b, cases) ->
      let k = (!cur).ntries in
      (!cur).ntries <- k + 1;
      let handler = label () and out = label () in
      emit (TryEnter (k, handler));
      value env b;
      emit (TryExit k);
      emit (Jmp out);
      emit (Label handler);
      emit (Catch k);
      let s = slot () in
      emit (Set s);
      (* no clause matches: raised again *)
      match_cases env s cases false (fun () -> emit (Get s); emit Raise);
      emit (Label out)
  | While (c, b) ->
      let top = label () and out = label () in
      emit (Label top); value env c; emit (Jz out); value env b; emit Drop;
      emit (Jmp top); emit (Label out); emit (Imm (tagged 0))
  | For (x, a, b, up, body) ->
      value env a;
      let i = slot () in
      emit (Set i);
      value env b;
      let lim = slot () in
      emit (Set lim);
      let top = label () and out = label () in
      emit (Label top);
      emit (Get lim); emit (Get i); emit (Op (Cmp (if up then Gt else Lt)));
      emit (Jnz out);
      value ((x, Loc (Slot i, None)) :: env) body;
      emit Drop;
      emit (Imm (tagged 1)); emit (Get i); emit (Op (if up then Add else Sub));
      emit (Set i);
      emit (Jmp top);
      emit (Label out);
      emit (Imm (tagged 0))

(* e as a function's last: its value returned, or a call made a jump *)
(* A block of the fields given in their order, computed right to left
 * (ocamlopt's order): each on the stack of registers, then allocated
 * and filled. Past 11 fields there are not the registers: the block
 * allocated first, blank, kept in a slot, each field stored in it as
 * it is computed (a process of tiny-kernel's, 12) *)
and fields_block fields =
  let n = List.length fields in
  if n <= 11 then (List.iter (fun f -> f ()) (List.rev fields); emit (Alloc (0, n)))
  else begin
    emit (Blank (0, n));
    let s = slot () in
    emit (Set s);
    List.iteri (fun k f ->
      let k = n - 1 - k in
      f (); emit (Get s); emit (SetField k)) (List.rev fields);
    emit (Get s)
  end

and tail env e =
  match e with
  | App (f, args) -> if not (app env f args true) then emit Ret
  | Let _ | Match _ | If _ | Seq _ -> control env e true
  | _ -> value env e; emit Ret

and control env e tl =
  let k env e = if tl then tail env e else value env e in
  match e with
  | Seq (a, b) -> value env a; emit Drop; k env b
  | If (c, a, b) ->
      let other = label () in
      value env c;
      emit (Jz other);
      k env a;
      if tl then (emit (Label other); k env b)
      else (
        let out = label () in
        emit (Jmp out); emit (Label other); k env b; emit (Label out))
  | Let (r, bs, body) -> k (bind env r bs) body
  | Match (e, cases) ->
      value env e;
      let s = slot () in
      emit (Set s);
      match_cases env s cases tl match_failure
  | _ -> invalid_arg "control"

(* the clauses in order, each tests then its body; after an irrefutable
 * one, nothing *)
and match_cases env s cases tl on_fail =
  let out = label () in
  let rec go = function
    | [] -> on_fail ()
    | (p, g, body) :: rest ->
        let fail = label () in
        let env = test env s p fail in
        Option.iter (fun g -> value env g; emit (Jz fail)) g;
        if tl then tail env body else (value env body; emit (Jmp out));
        if refutable p || g <> None then (emit (Label fail); go rest)
  in
  go cases;
  if not tl then emit (Label out)

and var env x =
  match lookup env x with
  | Loc (Slot s, _) -> emit (Get s)
  | Loc (Env j, _) -> emit (Get 0); emit (Field (2 + j))
  | Loc (Glob (t, g), _) -> emit (GetG (t, g))
  | Loc (Static sym, _) -> emit (Addr (sym, 8))
  | Ext (_, n) ->
      (* a primitive as a value: the function that applies it *)
      let xs = List.init n (fun i -> Printf.sprintf "%%e%d" i) in
      value env (Fun (xs, App (var_ x, List.map var_ xs)))

and var_ x = Var (x, ref (tcon "?"))

(* f args: a primitive, a known function's code called with its
 * arguments, or the closure applied to one at a time; whether it ended
 * in a tail call *)
and app env f args tl =
  let m = List.length args in
  let rest k =
    let n = m - k in
    for i = 1 to n do emit (Call (Code 0, 1, tl && i = n)) done;
    tl && n > 0
  in
  let args_in k =
    let first = List.filteri (fun i _ -> i < k) args
    and later = List.filteri (fun i _ -> i >= k) args in
    List.iter (value env) (List.rev later);
    List.iter (value env) (List.rev first)
  in
  match f with
  | Var (x, ty) -> (
      match lookup env x with
      | Ext (p, n) when m >= n -> args_in n; prim p n !ty; rest n
      | Loc (_, Some (lab, n)) when m >= n ->
          args_in n;
          var env x;
          emit (Call (Direct lab, n, tl && m = n));
          if m = n then tl else rest n
      | _ -> args_in m; value env f; rest 0)
  | _ -> args_in m; value env f; rest 0

(* let: the values in env, then their names *)
and bind env r bs =
  if r then bind_rec env bs
  else
    List.concat_map (fun (p, e) ->
      match p, e with
      | PVar x, Fun (xs, b) -> (
          match closure env x xs b with
          | Closure_static (sym, lab, n) ->
              [ x, Loc (Static sym, Some (lab, n)) ]
          | Closure_pushed (lab, n) ->
              let s = slot () in
              emit (Set s);
              [ x, Loc (Slot s, Some (lab, n)) ])
      | PAny, _ -> value env e; emit Drop; []
      | _ ->
          value env e; let s = slot () in emit (Set s); irrefutably s p) bs
    @ env

and irrefutably s p =
  if not (refutable p) then test [] s p 0
  else begin
    let fail = label () and ok = label () in
    let bs = test [] s p fail in
    emit (Jmp ok); emit (Label fail); match_failure (); emit (Label ok);
    bs
  end

(* a function: its code compiled later; its closure static without
 * free variables, else allocated *)
and closure env name xs b =
  let lab = fun_label name and n = List.length xs in
  let names = free [] (Fun (xs, b)) [] in
  let fvs = captured env names in
  let benv = body_env env names fvs in
  enqueue (fun () -> compile_fun lab xs benv b);
  if fvs = [] then Closure_static (static_closure lab n, lab, n)
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
    emit (Addr (lab, 0));
    emit (Addr (entry n lab, 0));
    emit (Alloc (closure_tag, 2 + List.length fvs))
  end
  else begin
    let s = slot () in
    let field k push = push (); emit (Get s); emit (SetField k) in
    emit (Blank (closure_tag, 2 + List.length fvs));
    emit (Set s);
    field 0 (fun () -> emit (Addr (entry n lab, 0)));
    field 1 (fun () -> emit (Addr (lab, 0)));
    List.iteri (fun j y -> field (2 + j) (fun () -> var env y)) fvs;
    emit (Get s)
  end

(* let rec: static if the functions need nothing but each other; else
 * their closures allocated, then those that name a later one patched *)
and bind_rec env bs =
  let fs =
    List.map
      (function
        | PVar x, Fun (xs, b) -> x, xs, b
        | _ -> error "let rec: only functions")
      bs
  in
  let labs = List.map (fun (x, xs, _) -> fun_label x, List.length xs) fs in
  let statics =
    List.map2
      (fun (x, _, _) (lab, n) ->
        x, Loc (Static (closure_sym lab), Some (lab, n)))
      fs labs
    @ env
  in
  let namess = List.map (fun (_, xs, b) -> free [] (Fun (xs, b)) []) fs in
  if List.for_all (fun names -> captured statics names = []) namess then begin
    List.iter2 (fun ((_, xs, b), names) (lab, n) ->
      ignore (static_closure lab n);
      let benv = body_env statics names [] in
      enqueue (fun () -> compile_fun lab xs benv b)) (List.combine fs namess) labs;
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
      emit (Set (List.nth slots i))) (List.combine fs fvss);
    List.iteri (fun i fvs ->
      List.iteri (fun j y ->
        let rec index k = function
          | [] -> None
          | z :: l -> if z = y then Some k else index (k + 1) l in
        match index 0 names with
        | Some m when m >= i ->
            emit (Get (List.nth slots m));
            emit (Get (List.nth slots i));
            emit (SetField (2 + j))
        | _ -> ()) fvs) fvss;
    env
  end

and compile_fun lab xs benv b =
  cur := { code = []; nslots = 1 + List.length xs; ntries = 0 };
  let env =
    List.rev (List.mapi (fun i x -> x, Loc (Slot (i + 1), None)) xs) @ benv in
  tail env b;
  machine lab (List.length xs) (!cur).nslots (List.rev (!cur).code)

(* ml_curry<n>_<k>: a closure of arity n given its k+1-th argument; a
 * block [the next one; the closure; the k arguments...], or the call *)
let curry_fun n k =
  cur := { code = []; nslots = 2; ntries = 0 };
  emit (Get 1);
  for i = k downto 1 do emit (Get 0); emit (Field (1 + i)) done;
  emit (Get 0);
  if k > 0 then emit (Field 1);
  if k < n - 1 then (
    emit (Addr (curry n (k + 1), 0));
    emit (Alloc (closure_tag, k + 3));
    emit Ret)
  else emit (Call (Code 1, n, true));
  machine (curry n k) 1 (!cur).nslots (List.rev (!cur).code)
