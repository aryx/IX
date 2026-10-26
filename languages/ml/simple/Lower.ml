(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Lower.mli *)

open Ir

(* the runtime's function for a relation between two values that are not
 * both integers: not compare, whose order has a nan equal to itself,
 * when = and < have it equal to and below nothing *)
let poly_function = function
  | Eq -> "ml_equal" | Ne -> "ml_notequal" | Lt -> "ml_lessthan" | Le -> "ml_lessequal"
  | Gt -> "ml_greaterthan" | Ge -> "ml_greaterequal"

let error fmt = Printf.ksprintf failwith fmt
let closure_tag = 247

let mangle s =
  String.concat ""
    (List.map (function ('a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '.') as c -> String.make 1 c | c -> "$" ^ string_of_int (Char.code c))
       (List.init (String.length s) (String.get s)))

(*****************************************************************************)
(* The unit's state *)
(*****************************************************************************)

(* where a variable's value is; for a function whose code is known,
 * that code and its arity *)
type loc = Slot of int | Env of int | Static of string
type binding = { loc : loc; known : (string * int) option }

type fn = { mutable code : Ir.t list; mutable nslots : int; mutable ntries : int }

let cur = ref { code = []; nslots = 1; ntries = 0 }
let emit i = !cur.code <- i :: !cur.code
let slot () = let s = !cur.nslots in !cur.nslots <- s + 1; s
let labels = ref 0
let label () = incr labels; !labels
let queue : (unit -> unit) Queue.t = Queue.create ()
let funcs : func list ref = ref []
let data = ref []
let arities = ref []
let file = ref ""

(* this unit's globals whose value is a known function *)
let known_globals : (string, binding) Hashtbl.t = Hashtbl.create 64

(* OPTIMIZATION (inline): a known function small enough that a call of
 * it with all its arguments is its body, by its code's label: its
 * parameters, its body, the variables its body sees (where it was
 * defined), and the frame they are slots of (None: no slot, a function
 * that captures nothing, which may be copied anywhere in the unit). A
 * toplevel function names only its parameters, globals and primitives
 * (Scope: a toplevel value is a global for the definitions after it);
 * a local one that captures variables is copied only into its own
 * function, where they are the same slots. The typing's tables
 * (immediates, float_cmps...) are by the place in the text: the copy
 * is the same text. Not a body with a handler (ssa's Unbox leaves such
 * a function's floats boxed), nor a recursive one. Only with -ssa:
 * Gen's stack is arm's 8 registers, and a body copied into an
 * expression is deeper than the call was.
 * old: every known function called *)
let inline_most = ref 0
type inline = { iparams : Scope.pattern list; ibody : Scope.expr; ienv : (int * binding) list; iframe : fn option; isize : int }
let inlines : (string, inline) Hashtbl.t = Hashtbl.create 64
(* the same of other units' toplevel functions, by their globals
 * (imports, below) *)
let imported : (string, inline) Hashtbl.t = Hashtbl.create 64

let nfuns = ref 0
let fun_label x = incr nfuns; Printf.sprintf "f%d_%s<>" !nfuns (String.map (function ('a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_') as c -> c | _ -> '_') x)
(* (the curry functions are the program's, one of each in its start
 * object (curry_funcs): a call compares a closure's first field with
 * one, below (calls_whole).
 * old: each unit's own, "ml_curry%d_%d<>", those of the arities it has)
 * (of the arities up to 16 only: a function of more parameters, rare,
 * has its unit's own curry functions, as before, the start object not
 * knowing the units' arities; and calls_whole is not for it.
 * old: 7, arm's registers less the closure's, the most a curry
 * function's block on the stack machine holds; mini-doom's columns,
 * drawn by a function of 10 parameters from another unit, were then a
 * closure per argument, 7% of a frame in ml_curry10_k and ml_curry8_k) *)
let shared_most = 16
let curry n k = if n <= shared_most then Printf.sprintf "ml_curry%d_%d" n k else Printf.sprintf "ml_curry%d_%d<>" n k
let entry n lab = if n = 1 then lab else (if not (List.mem n !arities) then arities := n :: !arities; curry n 0)

(* (off: mini-ml -calls) *)
let calls_whole = ref true

let static_closure lab n = let sym = "c" ^ lab and e = entry n lab in data := Closure (sym, e, lab) :: !data; sym

let strings = Hashtbl.create 16
let string_block s =
  match Hashtbl.find_opt strings s with
  | Some sym -> sym
  | None -> let sym = Printf.sprintf "s%d<>" (Hashtbl.length strings) in Hashtbl.replace strings s sym; data := String (sym, s) :: !data; sym

(* a float, boxed: a static block of its bits; its operations the
 * runtime's, which for now fail (floats: phase 7) *)
(* a float's, an int32's or an int64's: one block for the literals of
 * one value in a unit, as OCaml's (a value marshalled then has the
 * same blocks shared) *)
let shared key make =
  match Hashtbl.find_opt strings key with
  | Some sym -> sym
  | None -> let sym = make (Hashtbl.length strings) in Hashtbl.replace strings key sym; sym

let float_block f =
  shared (Printf.sprintf "\000float%Lx" (Int64.bits_of_float (float_of_string f))) (fun n ->
    let sym = Printf.sprintf "d%d<>" n in data := Float (sym, f) :: !data; sym)

let boxed_int_block bits n =
  shared (Printf.sprintf "\000int%d %Ld" bits (Int64.of_string n)) (fun k ->
    let sym = Printf.sprintf "i%d<>" k in data := Boxed_int (sym, bits, n) :: !data; sym)

let fresh = ref 0
let new_var x : Scope.var = decr fresh; { vname = x; vid = !fresh }

(*****************************************************************************)
(* Free variables *)
(*****************************************************************************)

let rec pvars (p : Scope.pattern) =
  match p with
  | Pvar v -> [ v ]
  | Palias (p, v) -> v :: pvars p
  | Ptuple ps | Pcons (_, ps) -> List.concat_map pvars ps
  | Precord fs -> List.concat_map (fun (_, p) -> pvars p) fs
  | Por (a, _) | Pconstraint (a, _) -> pvars a
  | Pany | Pconst _ | Prange _ -> []

(* the local variables free in e, each once, in their order *)
let rec free bound (e : Scope.expr) acc =
  let fr = free bound in
  let all l acc = List.fold_left (fun acc e -> fr e acc) acc l in
  let cases cs acc =
    List.fold_left (fun acc ((p : Scope.pattern), g, b) ->
      let bound = List.map (fun (v : Scope.var) -> v.vid) (pvars p) @ bound in
      free bound b (match g with Some g -> free bound g acc | None -> acc)) acc cs
  in
  match e.e with
  | Evar (Local v) -> if List.mem v.vid bound || List.mem v.vid acc then acc else acc @ [ v.vid ]
  | Evar _ | Econst _ -> acc
  | Elet (r, bs, b) ->
      let vs = List.concat_map (fun (p, _) -> List.map (fun (v : Scope.var) -> v.vid) (pvars p)) bs in
      let acc = List.fold_left (fun acc (_, e) -> free (if r then vs @ bound else bound) e acc) acc bs in
      free (vs @ bound) b acc
  | Efunction cs -> cases cs acc
  | Eapply (f, args) -> all (f :: args) acc
  | Ematch (e, cs) | Etry (e, cs) -> cases cs (fr e acc)
  | Etuple l | Econs (_, l) | Earray l -> all l acc
  | Erecord (_, fs) -> all (List.map snd fs) acc
  | Ewith (e, _, fs) -> all (e :: List.map snd fs) acc
  | Efield (e, _) | Eassert e -> fr e acc
  | Esetfield (a, _, b) | Eseq (a, b) | Ewhile (a, b) -> fr b (fr a acc)
  | Eif (a, b, c) -> all (a :: b :: Option.to_list c) acc
  | Efor (v, a, b, _, body) -> free (v.vid :: bound) body (fr b (fr a acc))
  | Econstraint (e, _) -> fr e acc

let lookup env (v : Scope.var) = match List.assoc_opt v.vid env with Some b -> b | None -> error "%s: unbound in its function" v.vname

(* the free variables a closure holds: the enclosing function's *)
let captured env e = List.filter (fun id -> match List.assoc_opt id env with Some { loc = Slot _ | Env _; _ } -> true | _ -> false) (free [] e [])

(* a function's variables: its closure's fields, then what isn't local *)
let body_env env fvs =
  List.mapi (fun j id -> id, { (List.assoc id env) with loc = Env j }) fvs
  @ List.filter (fun (_, b) -> match b.loc with Slot _ | Env _ -> false | _ -> true) env

(* fun p q -> e: the parameters, and the body; function | ... | ... a
 * last parameter matched *)
let rec params (e : Scope.expr) =
  match e.e with
  | Efunction [ (p, None, body) ] -> let ps, b = params body in p :: ps, b
  | Efunction cs ->
      let v = new_var "param" in
      [ Scope.Pvar v ], { e with e = Ematch ({ e with e = Evar (Local v) }, cs) }
  | _ -> [], e

(* a body's size, its nodes and those of the copies it makes (a call of
 * a function inlined, env's or a global, is that function's size), up
 * to most + 1: a copy is never larger than most. A handler or a
 * function in it, too big (its code would be copied with it) *)
exception Big
let size env most (e : Scope.expr) =
  let n = ref 0 in
  let copied (f : Scope.expr) =
    let b =
      match f.e with
      | Evar (Local x) -> List.assoc_opt x.vid env
      | Evar (Global g) -> Hashtbl.find_opt known_globals g.gsym
      | _ -> None
    in
    match Option.bind b (fun b -> b.known), f.e with
    | Some (lab, _), _ -> (match Hashtbl.find_opt inlines lab with Some i -> i.isize | None -> 0)
    | None, Evar (Global g) -> (match Hashtbl.find_opt imported g.gsym with Some i -> i.isize | None -> 0)
    | None, _ -> 0
  in
  let rec go (e : Scope.expr) =
    incr n;
    if !n > most then raise Big;
    let cases cs = List.iter (fun (_, g, b) -> Option.iter go g; go b) cs in
    match e.e with
    | Evar _ | Econst _ -> ()
    (* (an assertion's failure says the unit's file: not another's) *)
    | Etry _ | Efunction _ | Eassert _ -> raise Big
    | Elet (_, bs, b) -> List.iter (fun (_, e) -> go e) bs; go b
    | Eapply (f, es) -> n := !n + copied f; go f; List.iter go es
    | Ematch (e, cs) -> go e; cases cs
    | Etuple es | Econs (_, es) | Earray es -> List.iter go es
    | Erecord (_, fs) -> List.iter (fun (_, e) -> go e) fs
    | Ewith (e, _, fs) -> go e; List.iter (fun (_, e) -> go e) fs
    | Efield (e, _) | Econstraint (e, _) -> go e
    | Esetfield (a, _, b) | Eseq (a, b) | Ewhile (a, b) -> go a; go b
    | Eif (c, a, b) -> go c; go a; Option.iter go b
    | Efor (_, a, b, _, body) -> go a; go b; go body
  in
  match go e with () -> !n | exception Big -> most + 1

(* the function e of code lab, defined in env, inlined where it is
 * called when small; frame: the function whose slots it captures *)
let inline_candidate env frame lab (e : Scope.expr) =
  if !inline_most > 0 then begin
    let ps, body = params e in
    let k = size env !inline_most body in
    if k <= !inline_most then
      Hashtbl.replace inlines lab { iparams = ps; ibody = body; ienv = env; iframe = frame; isize = k }
  end

(*****************************************************************************)
(* Patterns *)
(*****************************************************************************)

let rec refutable (p : Scope.pattern) =
  match p with
  | Pany | Pvar _ -> false
  | Palias (p, _) | Pconstraint (p, _) -> refutable p
  | Ptuple ps -> List.exists refutable ps
  | Precord fs -> List.exists (fun (_, p) -> refutable p) fs
  | Pcons (c, ps) -> (match c.kind with Exn _ -> true | _ -> c.nconst + c.nblock > 1) || List.exists refutable ps
  | Pconst _ | Prange _ | Por _ -> true

(* the tests of p against the value in slot s, each jumping to fail;
 * its variables bound: to s, or copied to their slot when an
 * or-pattern gave them one *)
let rec test (acc : (int * binding) list) own s (p : Scope.pattern) fail =
  let check l = emit (Get s); List.iter emit l; emit (Jz fail) in
  (* s rel n: n pushed first, the first operand on top *)
  let rel r n = emit (Int n); emit (Get s); emit (Op (Cmp r)); emit (Jz fail) in
  let bind (v : Scope.var) acc =
    match List.assoc_opt v.vid own with
    | Some slot -> emit (Get s); emit (Set slot); (v.vid, { loc = Slot slot; known = None }) :: acc
    | None -> (v.vid, { loc = Slot s; known = None }) :: acc
  in
  let field k p acc =
    match p with
    | Scope.Pany -> acc
    | p -> let s' = slot () in emit (Get s); emit (Field k); emit (Set s'); test acc own s' p fail
  in
  match p with
  | Pany -> acc
  | Pvar v -> bind v acc
  | Palias (p, v) -> test (bind v acc) own s p fail
  | Pconstraint (p, _) -> test acc own s p fail
  | Pconst (Int n) -> rel Eq n; acc
  | Pconst (Char c) -> rel Eq (Char.code c); acc
  | Pconst (String str) -> check [ Block (string_block str); Op (Poly Eq) ]; acc
  | Pconst (Float f) -> check [ Block (float_block f); Op (Poly Eq) ]; acc
  | Pconst (Int32 n) -> check [ Block (boxed_int_block 32 n); Op (Poly Eq) ]; acc
  | Pconst (Int64 n) -> check [ Block (boxed_int_block 64 n); Op (Poly Eq) ]; acc
  | Prange (a, b) -> rel Ge (Char.code a); rel Le (Char.code b); acc
  | Ptuple ps -> fst (List.fold_left (fun (acc, k) p -> field k p acc, k + 1) (acc, 0) ps)
  | Precord fs -> List.fold_left (fun acc ((l : Scope.label), p) -> field l.pos p acc) acc fs
  | Pcons (c, ps) ->
      (match c.kind with
       | Const n -> if c.nconst + c.nblock > 1 then rel Eq n
       | Block t ->
           if c.nconst > 0 then (emit (Get s); emit (Op IsInt); emit (Jnz fail));
           if c.nblock > 1 then check [ Op Tag; Int t; Op (Cmp Eq) ]
       | Exn g -> check [ Field 0; Block (mangle g.gsym); Op (Cmp Eq) ]);
      let base = match c.kind with Exn _ -> 1 | _ -> 0 in
      fst (List.fold_left (fun (acc, k) p -> field k p acc, k + 1) (acc, base) ps)
  | Por (a, b) ->
      (* the variables in slots of their own, which both sides fill *)
      let own = List.map (fun (v : Scope.var) -> v.vid, match List.assoc_opt v.vid own with Some s -> s | None -> slot ()) (pvars a) @ own in
      let other = label () and ok = label () in
      let acc' = test acc own s a other in
      emit (Jmp ok);
      emit (Label other);
      ignore (test acc own s b fail);
      emit (Label ok);
      acc'

let raise_failure exn line =
  (* Match_failure and Assert_failure: (file, line, column) *)
  emit (Int 0); emit (Int line); emit (Block (string_block !file)); emit (Alloc (0, 3));
  emit (Block ("caml_exn_" ^ exn)); emit (Alloc (0, 2)); emit Raise

(*****************************************************************************)
(* Primitives *)
(*****************************************************************************)

(* OPTIMIZATION (immediates): the comparisons that the type checker saw
 * on ints, chars, booleans or () (Typing.immediates), by their place
 * in the text: the integers' comparison, a CMP and its branch, not
 * Poly's test of both operands then compare's call for others. fib's
 * n < 2 was 11 instructions on arm, 2 now. And the stores of such
 * values (a.(i) <- v, r := v, r.f <- v): no write barrier (Ir's
 * SetField's and SetIndex's bool), as no pointer is stored.
 * old: every =, <... Poly (empty with mini-ml -unsafe-types); every
 * store with its barrier *)
let immediates : (Ast.span, unit) Hashtbl.t = Hashtbl.create 64
(* OPTIMIZATION (string_eqs): = and <> on strings (Typing.strings): the
 * runtime's string equality, its words compared, not compare's walk
 * (its tag tested, the lengths computed, a byte at a time).
 * old: Poly Eq, Poly Ne *)
let string_eqs : (Ast.span, unit) Hashtbl.t = Hashtbl.create 64
(* OPTIMIZATION (float_cmps): a comparison of floats (Typing.floats): the
 * processor's (Ir.FloatCmp), not compare's call, which finds what its
 * operands are (14% of mini-doom's frame, its walls' and planes' tests).
 * old: Poly r (simple's Gen tested for two floats at run time, ssa's
 * Emit called the runtime) *)
let float_cmps : (Ast.span, unit) Hashtbl.t = Hashtbl.create 64

(* OPTIMIZATION (min_max): min and max on ints or floats (their place
 * in immediates or float_cmps): the comparison and the choice here,
 * not Pervasives' function, a call, and in it compare's (mini-doom's
 * columns and spans clamped, 2% of a frame) *)
let min_max = [ "Pervasives.min", Le; "Pervasives.max", Ge; "Int.min", Le; "Int.max", Ge ]
(* the globals that are one of them (Typing.min_max_globals) *)
let min_max_aliases : (string, string) Hashtbl.t = Hashtbl.create 8

(* (off: mini-ml -calls) *)
let strings_in_place = ref true
let floats_in_place = ref true

let ops =
  [ "%addint", Add; "%subint", Sub; "%mulint", Mul; "%divint", Div; "%modint", Mod; "%andint", And; "%orint", Or;
    "%xorint", Xor; "%lslint", Lsl; "%lsrint", Lsr; "%asrint", Asr; "%negint", Neg; "%boolnot", Not; "%eq", Cmp Eq;
    "%noteq", Cmp Ne; "%equal", Poly Eq; "%notequal", Poly Ne; "%lessthan", Poly Lt; "%lessequal", Poly Le;
    "%greaterthan", Poly Gt; "%greaterequal", Poly Ge; "%array_length", Size; "%obj_size", Size; "%obj_is_int", IsInt ]

(* the operands are pushed, the first on top; imm: the value a store
 * writes is an immediate (Typing.immediates: no barrier) *)
let prim imm p n =
  let incr d =
    let t = slot () in
    emit (Set t); emit (Int d); emit (Get t); emit (Field 0); emit (Op Add); emit (Get t); emit (SetField (0, true)); emit (Int 0) in
  match p with
  | _ when List.mem_assoc p ops -> emit (Op (List.assoc p ops))
  | "%identity" -> ()
  | "%ignore" -> emit Drop; emit (Int 0)
  | "%succint" -> emit (Int 1); emit (Op Add)
  | "%predint" -> emit (Int (-1)); emit (Op Add)
  | "%makemutable" -> emit (Alloc (0, 1))
  | "%field0" -> emit (Field 0)
  | "%field1" -> emit (Field 1)
  | "%setfield0" -> emit (SetField (0, imm)); emit (Int 0)
  | "%incr" -> incr 1
  | "%decr" -> incr (-1)
  | "%raise" -> emit Raise
  | "%array_safe_get" | "%array_unsafe_get" | "%obj_field" -> emit Index
  | "%array_safe_set" | "%array_unsafe_set" | "%obj_set_field" ->
      emit (SetIndex imm); emit (Int 0)
  (* OPTIMIZATION (strings_in_place): a byte of a string that the program
   * said not to check, and a string's length, are instructions here, not
   * calls of the runtime (which checked the index of the unchecked ones
   * too). A loop that stores a byte was 73 instructions a byte on arm,
   * some 45 of them the call (docs/plans/plan_playground_speed.md, M1b:
   * a pixel is four bytes, a message to the draw device forty).
   * old: every one of the five a CallC *)
  | "%string_length" when !strings_in_place -> emit StrLen
  | "%string_unsafe_get" when !strings_in_place -> emit (ByteGet false)
  | "%string_unsafe_set" when !strings_in_place -> emit (ByteSet false); emit (Int 0)
  (* OPTIMIZATION (strings_in_place): the checked ones too, the index
   * compared with the length there (ocamlopt's way). mini-ml compiling
   * its Typing.ml spent 7% of its instructions in ml_string_get's
   * calls, the lexer's and the strings' functions' (String.get, the
   * other's Bytes.get: s.[i]).
   * old: (below) the runtime's ml_string_get and ml_string_set *)
  | "%string_safe_get" when !strings_in_place -> emit (ByteGet true)
  | "%string_safe_set" when !strings_in_place -> emit (ByteSet true); emit (Int 0)
  | "%string_length" -> emit (CallC ("ml_string_length", 1))
  | "%string_safe_get" | "%string_unsafe_get" -> emit (CallC ("ml_string_get", 2))
  | "%string_safe_set" | "%string_unsafe_set" -> emit (CallC ("ml_string_set", 3))
  (* OPTIMIZATION (floats_in_place): a float's arithmetic is the
   * processor's instructions and a block taken from the heap here (Gen),
   * not a call of the runtime: x *. y was 65 instructions on arm, 14
   * now (docs/plans/plan_playground_speed.md, M4a: a shape's place is
   * forty of them, a wall's column of a game as many).
   * old: every one a CallC *)
  | "%addfloat" | "%subfloat" | "%mulfloat" | "%divfloat" when !floats_in_place -> emit (Float2 ("caml_" ^ String.sub p 1 (String.length p - 1)))
  | "%negfloat" | "%absfloat" when !floats_in_place -> emit (Float1 ("caml_" ^ String.sub p 1 (String.length p - 1)))
  | "%floatofint" when !floats_in_place -> emit FloatOfInt
  | "%intoffloat" when !floats_in_place -> emit IntOfFloat
  | "%negfloat" | "%absfloat" | "%floatofint" | "%intoffloat" | "%addfloat" | "%subfloat" | "%mulfloat" | "%divfloat" ->
      emit (CallC ("caml_" ^ String.sub p 1 (String.length p - 1), n))
  (* Float.Array's: Ir's own, which ssa's Unbox makes a double's load
   * and store; its length the runtime's (two words a float on arm) *)
  | "%floatarray_safe_get" | "%floatarray_unsafe_get" -> emit (FloatIndex (p = "%floatarray_safe_get"))
  | "%floatarray_safe_set" | "%floatarray_unsafe_set" ->
      emit (FloatSetIndex (p = "%floatarray_safe_set")); emit (Int 0)
  | "%floatarray_length" -> emit (CallC ("ml_floatarray_length", 1))
  (* floor and ceil: Ir's own, a call still in simple's code, the
   * processor's in ssa's on doubles (Emit's round) *)
  | "floor_float" | "ceil_float" when !floats_in_place -> emit (FloatRound (p = "ceil_float"))
  | _ when p.[0] = '%' -> error "unknown primitive %s" p
  | _ -> emit (CallC (p, n))

(*****************************************************************************)
(* Expressions *)
(*****************************************************************************)

(* an operand: an expression, or what pushes a value already known *)
type operand = E of Scope.expr | F of (unit -> unit)

(* a closure: static, its symbol, when it captures nothing, else
 * built on the stack; each with its code's label and arity *)
type closure = Closure_static of string * string * int | Closure_pushed of string * int

(* e's value pushed *)
let rec value env (e : Scope.expr) =
  match e.e with
  | Econst (Int n) -> emit (Int n)
  | Econst (Char c) -> emit (Int (Char.code c))
  | Econst (String s) -> emit (Block (string_block s))
  | Econst (Float f) -> emit (Block (float_block f))
  | Econst (Int32 n) -> emit (Block (boxed_int_block 32 n))
  | Econst (Int64 n) -> emit (Block (boxed_int_block 64 n))
  | Evar v -> var env v
  | Econs (c, args) -> (
      match c.kind with
      | Const n -> emit (Int n)
      | Block t -> block env t (List.map (fun e -> E e) args)
      | Exn g -> block env 0 (F (fun () -> emit (Block (mangle g.gsym))) :: List.map (fun e -> E e) args))
  | Etuple es -> block env 0 (List.map (fun e -> E e) es)
  | Earray [] -> emit (Block "caml_atom0")
  | Earray es -> block env 0 (List.map (fun e -> E e) es)
  | Erecord (size, fs) ->
      block env 0
        (List.init size (fun pos ->
          match List.find_opt (fun ((l : Scope.label), _) -> l.pos = pos) fs with
          | Some (_, e) -> E e
          | None -> error "a record without its field %d" pos))
  | Ewith (r, size, fs) ->
      value env r;
      let s = slot () in
      emit (Set s);
      block env 0
        (List.init size (fun pos ->
          match List.find_opt (fun ((l : Scope.label), _) -> l.pos = pos) fs with
          | Some (_, e) -> E e
          | None -> F (fun () -> emit (Get s); emit (Field pos))))
  | Efield (r, l) -> value env r; emit (Field l.pos)
  | Esetfield (r, l, v) ->
      value env v; value env r;
      emit (SetField (l.pos, Hashtbl.mem immediates e.span)); emit (Int 0)
  | Eapply (f, args) -> ignore (app env f args false)
  | Efunction _ -> (match closure env "fun" e with Closure_static (sym, _, _) -> emit (Block sym) | Closure_pushed _ -> ())
  | Elet _ | Ematch _ | Eif _ | Eseq _ -> control env e false
  | Etry (b, cases) ->
      let k = !cur.ntries in
      !cur.ntries <- k + 1;
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
      match_cases env s cases false e.loc (fun () -> emit (Get s); emit Raise);
      emit (Label out)
  | Ewhile (c, b) ->
      let top = label () and out = label () in
      emit (Label top); value env c; emit (Jz out); value env b; emit Drop; emit (Jmp top); emit (Label out); emit (Int 0)
  | Efor (v, a, b, dir, body) ->
      value env a;
      let i = slot () in
      emit (Set i);
      value env b;
      let lim = slot () in
      emit (Set lim);
      let top = label () and out = label () in
      emit (Label top);
      emit (Get lim); emit (Get i); emit (Op (Cmp (if dir = Upto then Gt else Lt))); emit (Jnz out);
      value ((v.vid, { loc = Slot i; known = None }) :: env) body;
      emit Drop;
      emit (Int (if dir = Upto then 1 else -1)); emit (Get i); emit (Op Add); emit (Set i);
      emit (Jmp top);
      emit (Label out);
      emit (Int 0)
  | Econstraint (e, _) -> value env e
  | Eassert c ->
      let ok = label () in
      value env c; emit (Jnz ok); raise_failure "Assert_failure" e.loc; emit (Label ok); emit (Int 0)

(* a block of the fields' values, each pushed by its function, the last
 * first; a big one allocated empty then filled, so that the stack
 * machine's depth stays small *)
and block env tag fields =
  let n = List.length fields in
  if n <= 4 then (operands env (List.rev fields); emit (Alloc (tag, n)))
  else begin
    emit (Int n); emit (Int tag); emit (CallC ("obj_block", 2));
    let b = slot () in
    emit (Set b);
    List.iteri (fun i f -> let pos = n - 1 - i in operands env [ f ]; emit (Get b); emit (SetField (pos, false))) (List.rev fields);
    emit (Get b)
  end

(* operands pushed in their order (the last argument first); two or
 * more of them allocating or calling are computed into slots first,
 * in that order, so that the depth is the operands', not their
 * nesting's (boyer's terms: 9 on arm's 8 registers) *)
and operands env ops =
  let complex = function
    | E { e = Econst _ | Evar _ | Econs (_, []); _ } | F _ -> false
    | E _ -> true
  in
  if List.length (List.filter complex ops) < 2 then List.iter (function E e -> value env e | F f -> f ()) ops
  else begin
    let slots =
      List.map (fun o ->
        match o with
        | E e when complex o -> value env e; let s = slot () in emit (Set s); Some s
        | _ -> None) ops
    in
    List.iter2 (fun o s -> match o, s with _, Some s -> emit (Get s) | E e, None -> value env e | F f, None -> f ()) ops slots
  end

(* e as a function's last: its value returned, or a call made a jump *)
and tail env (e : Scope.expr) =
  match e.e with
  | Eapply (f, args) -> if not (app env f args true) then emit Ret
  | Elet _ | Ematch _ | Eif _ | Eseq _ -> control env e true
  | Econstraint (e, _) -> tail env e
  | _ -> value env e; emit Ret

and control env (e : Scope.expr) tl =
  let k env e = if tl then tail env e else value env e in
  match e.e with
  | Eseq (a, b) -> value env a; emit Drop; k env b
  | Eif (c, a, b) ->
      let b = match b with Some b -> b | None -> { e with e = Econs ({ cname = "()"; kind = Const 0; arity = 0; nconst = 1; nblock = 0; ctype = [], [], Resolve.unit_t; cinline = [] }, []) } in
      let other = label () in
      value env c;
      emit (Jz other);
      k env a;
      if tl then (emit (Label other); k env b)
      else (let out = label () in emit (Jmp out); emit (Label other); k env b; emit (Label out))
  | Elet (r, bs, body) -> k (bind env r bs) body
  | Ematch (scrut, cases) ->
      value env scrut;
      let s = slot () in
      emit (Set s);
      match_cases env s cases tl e.loc (fun () -> raise_failure "Match_failure" e.loc)
  | _ -> assert false

(* the clauses in order, each tests then its body; after an irrefutable
 * one, nothing *)
and match_cases env s cases tl _loc on_fail =
  let out = label () in
  let rec go = function
    | [] -> on_fail ()
    | ((p : Scope.pattern), g, body) :: rest ->
        let fail = label () in
        let env = test env [] s p fail in
        Option.iter (fun g -> value env g; emit (Jz fail)) g;
        if tl then tail env body else (value env body; emit (Jmp out));
        if refutable p || Option.is_some g then (emit (Label fail); go rest)
  in
  go cases;
  if not tl then emit (Label out)

and var env (v : Scope.value) =
  match v with
  | Local x -> (
      match (lookup env x).loc with
      | Slot s -> emit (Get s)
      | Env j -> emit (Get 0); emit (Field (2 + j))
      | Static sym -> emit (Block sym))
  | Global g -> (
      match Hashtbl.find_opt known_globals g.gsym with
      | Some { loc = Static sym; _ } -> emit (Block sym)
      | _ -> emit (GetG (mangle g.gsym)))
  | Prim (p, n, t) ->
      (* a primitive as a value: the function that applies it *)
      let xs = List.init n (fun i -> new_var (Printf.sprintf "prim%d" i)) in
      let mk (e : Scope.exp) : Scope.expr = { e; loc = 0; span = 0, 0 } in
      let body = mk (Eapply (mk (Evar (Prim (p, n, t))), List.map (fun x -> mk (Evar (Local x))) xs)) in
      value env (List.fold_right (fun x b -> mk (Efunction [ Scope.Pvar x, None, b ])) xs body)

(* f args: a primitive, a known function's code called with its
 * arguments, or the closure applied to one at a time; whether it ended
 * in a tail call *)
and app env (f : Scope.expr) args tl =
  let m = List.length args in
  let first k = List.filteri (fun i _ -> i < k) args and later k = List.filteri (fun i _ -> i >= k) args in
  (* the arguments in slots, the last computed first *)
  let slots es = List.rev (List.map (to_slot env) (List.rev es)) in
  (* the result on the stack applied to the arguments in slots, one at a time *)
  let rest ss =
    let n = List.length ss in
    List.iteri (fun i a -> let r = slot () in emit (Set r); emit (Call (Code 0, [ r; a ], tl && i = n - 1))) ss;
    tl && n > 0
  in
  let known =
    match f.e with
    | Evar (Local x) -> (lookup env x).known
    | Evar (Global g) -> Option.bind (Hashtbl.find_opt known_globals g.gsym) (fun b -> b.known)
    | _ -> None
  in
  (* (inline: a copy in its own function, or one that captures
   * nothing; another unit's by its global) *)
  let copy =
    match known, f.e with
    | Some (lab, _), _ -> (
        match Hashtbl.find_opt inlines lab with
        | Some ({ iframe = None; _ } as i) -> Some i
        | Some ({ iframe = Some fr; _ } as i) when fr == !cur -> Some i
        | _ -> None)
    | None, Evar (Global g) -> Hashtbl.find_opt imported g.gsym
    | None, _ -> None
  in
  match f.e, known, args with
  (* a && b, a || b: an if, whose b is in tail position when the
   * whole is (OCaml's rule: is_utf_8's ok, "valid d && ok (i + n)", a
   * frame a character of a page of 1.3 MB, overflowed the stack) *)
  | Evar (Prim ("%sequand", _, _)), _, [ a; b ] ->
      let e = { f with e = Eif (a, b, Some { f with e = Econst (Int 0) }) } in
      if tl then (control env e true; true) else (value env e; false)
  | Evar (Prim ("%sequor", _, _)), _, [ a; b ] ->
      let e = { f with e = Eif (a, { f with e = Econst (Int 1) }, Some b) } in
      if tl then (control env e true; true) else (value env e; false)
  | Evar (Global g), _, [ a; b ]
    when Hashtbl.mem min_max_aliases g.gsym
         && (Hashtbl.mem immediates f.span
             || (Hashtbl.mem float_cmps f.span && !floats_in_place)) ->
      (* if a <= b then a else b (Pervasives'), b computed first *)
      let sb = to_slot env b in
      let sa = to_slot env a in
      let r = List.assoc (Hashtbl.find min_max_aliases g.gsym) min_max in
      emit (Get sb); emit (Get sa);
      emit (if Hashtbl.mem immediates f.span then Op (Cmp r) else FloatCmp r);
      let other = label () and out = label () in
      emit (Jz other); emit (Get sa); emit (Jmp out);
      emit (Label other); emit (Get sb); emit (Label out);
      false
  | Evar (Prim (p, n, _)), _, _ when m >= n ->
      let ls = slots (later n) in
      operands env (List.map (fun e -> E e) (List.rev (first n)));
      (match List.assoc_opt p ops with
       | Some (Poly r) when Hashtbl.mem immediates f.span -> emit (Op (Cmp r))
       | Some (Poly r) when Hashtbl.mem float_cmps f.span && !floats_in_place ->
           emit (FloatCmp r)
       | Some (Poly Eq) when Hashtbl.mem string_eqs f.span ->
           emit (CallC ("caml_string_equal", 2))
       | Some (Poly Ne) when Hashtbl.mem string_eqs f.span ->
           emit (CallC ("caml_string_notequal", 2))
       | _ -> prim (Hashtbl.mem immediates f.span) p n);
      rest ls
  | Evar _, _, _ when (match copy with Some i -> List.length i.iparams = m | None -> false) ->
      let i = Option.get copy in
      let ss = slots args in
      let env =
        List.fold_left2 (fun env s (p : Scope.pattern) ->
          match p with
          | Pvar x -> (x.vid, { loc = Slot s; known = None }) :: env
          | p -> irrefutably s p @ env) i.ienv ss i.iparams
      in
      if tl then (tail env i.ibody; true) else (value env i.ibody; false)
  | Evar _, Some (lab, n), _ when m >= n ->
      let ss = slots args in
      let c = to_slot env f in
      emit (Call (Direct lab, c :: List.filteri (fun i _ -> i < n) ss, tl && m = n));
      if m = n then tl else rest (List.filteri (fun i _ -> i >= n) ss)
  (* OPTIMIZATION (calls_whole): a function that is not known here (one
   * of another unit, a parameter, a field) called with m arguments, 2
   * or more: when it is a function of exactly m, which its closure's
   * first field says (the curry function of m: no function of another
   * arity has it), its code is called with them all, as a known one's.
   * Otherwise, and before, one argument at a time: a closure made for
   * each but the last, then the code called from the last curry
   * function. Every call of a library's function of two arguments was
   * so: a sixth of a game's instructions were curry functions
   * (docs/plans/plan_playground_speed.md). *)
  | _, _, _ :: _ when !calls_whole && m >= 2 && m <= shared_most ->
      let ss = slots args in
      let c = to_slot env f in
      let slow = label () and out = label () in
      emit (Get c); emit (Field 0); emit (Sym (curry m 0)); emit (Op (Cmp Eq)); emit (Jz slow);
      emit (Call (Code 1, c :: ss, tl));
      if not tl then emit (Jmp out);
      emit (Label slow);
      emit (Call (Code 0, [ c; List.hd ss ], false));
      let t = rest (List.tl ss) in
      if not tl then emit (Label out);
      t
  | _, _, a :: _ ->
      let ss = slots args in
      let c = to_slot env f in
      emit (Call (Code 0, [ c; List.hd ss ], tl && m = 1));
      ignore a;
      if m = 1 then tl else rest (List.tl ss)
  | _, _, [] -> value env f; false

(* e's value in a slot: a local already in one is its own *)
and to_slot env (e : Scope.expr) =
  match e.e with
  | Evar (Local x) when (match (lookup env x).loc with Slot _ -> true | _ -> false) -> (match (lookup env x).loc with Slot s -> s | _ -> assert false)
  | _ -> value env e; let s = slot () in emit (Set s); s

(* let: the values in env, then their names *)
and bind env r bs =
  if r then bind_rec env bs
  else
    List.concat_map (fun ((p : Scope.pattern), (e : Scope.expr)) ->
      match p, e.e with
      | Pvar x, Efunction _ -> (
          match closure env x.vname e with
          | Closure_static (sym, lab, n) ->
              inline_candidate env None lab e;
              [ x.vid, { loc = Static sym; known = Some (lab, n) } ]
          | Closure_pushed (lab, n) ->
              inline_candidate env (Some !cur) lab e;
              let s = slot () in emit (Set s); [ x.vid, { loc = Slot s; known = Some (lab, n) } ])
      | Pany, _ -> value env e; emit Drop; []
      | _ -> value env e; let s = slot () in emit (Set s); irrefutably s p) bs
    @ env

and irrefutably s p =
  if not (refutable p) then test [] [] s p 0
  else begin
    let fail = label () and ok = label () in
    let bs = test [] [] s p fail in
    emit (Jmp ok); emit (Label fail); raise_failure "Match_failure" 0; emit (Label ok);
    bs
  end

(* a function: its code compiled later; its closure static without
 * free variables, else allocated *)
and closure env name (e : Scope.expr) =
  let lab = fun_label name in
  let ps, body = params e in
  let n = List.length ps in
  let fvs = captured env e in
  let benv = body_env env fvs in
  Queue.add (fun () -> compile_fun lab ps benv body) queue;
  if fvs = [] then Closure_static (static_closure lab n, lab, n)
  else begin
    alloc_closure env lab n fvs;
    Closure_pushed (lab, n)
  end

and alloc_closure env lab n fvs =
  let e = entry n lab in
  block env closure_tag (F (fun () -> emit (Sym e)) :: F (fun () -> emit (Sym lab)) :: List.map (fun id -> F (fun () -> var env (Local { vname = ""; vid = id }))) fvs)

(* let rec: static if the functions need nothing but each other; else
 * their closures allocated, then those that name a later one patched *)
and bind_rec env bs =
  (* let rec f : t = function ...: the function under its annotation *)
  let rec bare (e : Scope.expr) : Scope.expr = match e.e with Econstraint (e, _) -> bare e | _ -> e in
  let fs = List.map (function (Scope.Pvar x, (e : Scope.expr)) -> (match (bare e).e with Efunction _ -> x, bare e | _ -> error "let rec %s: only functions" x.vname) | _ -> error "let rec: a name") bs in
  let labs = List.map (fun ((x : Scope.var), e) -> fun_label x.vname, List.length (fst (params e))) fs in
  let statics = List.map2 (fun ((x : Scope.var), _) (lab, n) -> x.vid, { loc = Static ("c" ^ lab); known = Some (lab, n) }) fs labs @ env in
  if List.for_all (fun (_, e) -> captured statics e = []) fs then begin
    List.iter2 (fun (_, e) (lab, n) ->
      ignore (static_closure lab n);
      let ps, body = params e in
      Queue.add (fun () -> compile_fun lab ps (body_env statics []) body) queue) fs labs;
    statics
  end
  else begin
    let slots = List.map (fun _ -> slot ()) fs in
    let env = List.map2 (fun ((x : Scope.var), _) ((lab, n), s) -> x.vid, { loc = Slot s; known = Some (lab, n) }) fs (List.combine labs slots) @ env in
    let ids = List.map (fun ((x : Scope.var), _) -> x.vid) fs in
    let fvss = List.map (fun (_, e) -> captured env e) fs in
    List.iteri (fun i ((_, e), fvs) ->
      let lab, n = List.nth labs i in
      let ps, body = params e in
      let benv = body_env env fvs in
      Queue.add (fun () -> compile_fun lab ps benv body) queue;
      alloc_closure env lab n fvs;
      emit (Set (List.nth slots i))) (List.combine fs fvss);
    List.iteri (fun i fvs ->
      List.iteri (fun j id ->
        let rec index k = function [] -> None | z :: l -> if z = id then Some k else index (k + 1) l in
        match index 0 ids with
        | Some m when m >= i -> emit (Get (List.nth slots m)); emit (Get (List.nth slots i)); emit (SetField (2 + j, false))
        | _ -> ()) fvs) fvss;
    env
  end

(* a function's code: its closure in slot 0, its parameters after *)
and compile_fun lab ps benv body =
  cur := { code = []; nslots = 1 + List.length ps; ntries = 0 };
  let env =
    List.fold_left (fun env (i, (p : Scope.pattern)) ->
      match p with
      | Pvar x -> (x.vid, { loc = Slot i; known = None }) :: env
      | p -> irrefutably i p @ env) benv (List.mapi (fun i p -> i + 1, p) ps)
  in
  tail env body;
  funcs := { name = lab; nparams = List.length ps; nslots = !cur.nslots; code = List.rev !cur.code } :: !funcs

(* ml_curry<n>_<k>: a closure of arity n given its k+1-th argument; a
 * block [the next one; the closure; the k arguments...], or the call;
 * the block's fields on the stack machine, or for more than arm's
 * registers hold, stored one by one (as a big block's) *)
let curry_fun n k =
  cur := { code = []; nslots = 2; ntries = 0 };
  (* (the block on the stack machine when its k + 3 fields fit arm's 8
   * registers: every arity up to 7's) *)
  if k < n - 1 && k + 3 <= 8 then begin
    emit (Get 1);
    for i = k downto 1 do emit (Get 0); emit (Field (1 + i)) done;
    emit (Get 0);
    if k > 0 then emit (Field 1);
    emit (Sym (curry n (k + 1))); emit (Alloc (closure_tag, k + 3)); emit Ret
  end
  else if k < n - 1 then begin
    emit (Int (k + 3)); emit (Int closure_tag); emit (CallC ("obj_block", 2));
    let b = slot () in
    emit (Set b);
    (* (no write barrier: the block just made is young, as ssa's Emit
     * says of obj_block's, fresh; these are the start object's, Gen's,
     * which had it at each field: a curry function of 8 arguments' 59
     * instructions 109, and twice the minor collections' copies) *)
    let set pos = emit (Get b); emit (SetField (pos, true)) in
    emit (Sym (curry n (k + 1))); set 0;
    emit (Get 0); if k > 0 then emit (Field 1); set 1;
    for i = 2 to k + 1 do emit (Get 0); emit (Field i); set i done;
    emit (Get 1); set (k + 2);
    emit (Get b); emit Ret
  end
  else begin
    let field i = emit (Get 0); emit (Field i); let s = slot () in emit (Set s); s in
    let args = List.init k (fun i -> field (2 + i)) in
    let orig = if k > 0 then field 1 else 0 in
    emit (Call (Code 1, (orig :: args) @ [ 1 ], true))
  end;
  funcs := { name = curry n k; nparams = 1; nslots = !cur.nslots; code = List.rev !cur.code } :: !funcs

(* the curry functions of every arity up to shared_most, for the start
 * object *)
let curry_funcs () =
  funcs := [];
  for n = 2 to shared_most do for k = 0 to n - 1 do curry_fun n k done done;
  let fs = List.rev !funcs in
  funcs := [];
  fs

(*****************************************************************************)
(* Other units' functions *)
(*****************************************************************************)

(* OPTIMIZATION (inline, across units): the small toplevel functions of
 * the units this one names, from their summaries (CLI: X.inline, their
 * places in the text made apart from this unit's), inlined where this
 * unit calls them with all their arguments, as its own are. A
 * toplevel function's body names its parameters, globals and
 * primitives only, which are the same here. *)
let imports (es : Summary.entry list) =
  Hashtbl.reset imported;
  List.iter (fun (e : Summary.entry) ->
    if e.size <= !inline_most then
      Hashtbl.replace imported e.global { iparams = e.params; ibody = e.body; ienv = []; iframe = None; isize = e.size }) es

(* the unit's own toplevel functions that its calls copy, for its
 * summary: after unit_, whose tables say which *)
let exports (items : Scope.item list) : Summary.entry list =
  List.concat_map (fun (it : Scope.item) ->
    match it with
    | Ivalue (false, _, gs) ->
        List.filter_map (fun ((_ : Scope.var), (g : Scope.global)) ->
          match Option.bind (Hashtbl.find_opt known_globals g.gsym) (fun b -> b.known) with
          | Some (lab, _) -> (
              match Hashtbl.find_opt inlines lab with
              | Some { iframe = None; iparams; ibody; isize; _ } ->
                  Some { Summary.global = g.gsym; params = List.map Summary.strip_pattern iparams; body = Summary.strip ibody; size = isize }
              | _ -> None)
          | None -> None) gs
    | _ -> []) items

(*****************************************************************************)
(* A unit *)
(*****************************************************************************)

let unit_ name (items : Scope.item list) =
  cur := { code = []; nslots = 1; ntries = 0 };
  funcs := []; data := []; arities := []; Hashtbl.reset strings; Hashtbl.reset known_globals; Hashtbl.reset inlines;
  file := String.uncapitalize_ascii name ^ ".ml";
  let globals = ref [] in
  List.iter (fun (it : Scope.item) ->
    match it with
    | Ieval e -> value [] e; emit Drop
    | Iexception (g, c) -> let name = string_block c in data := Exception (mangle g.gsym, name) :: !data
    | Iexternal (g, p, n, t) ->
        (* the primitive as a function, a static closure *)
        let sym = mangle g.gsym in
        globals := sym :: !globals;
        var [] (Prim (p, n, t));
        emit (SetG sym);
        data := Global (sym, None) :: !data
    | Ivalue (r, bs, gs) ->
        let env = bind [] r bs in
        List.iter (fun ((v : Scope.var), (g : Scope.global)) ->
          let sym = mangle g.gsym in
          globals := sym :: !globals;
          let b = List.assoc v.vid env in
          (match b.loc with
           | Static s -> data := Global (sym, Some s) :: !data
           | _ -> data := Global (sym, None) :: !data; var env (Local v); emit (SetG sym));
          if b.known <> None then Hashtbl.replace known_globals g.gsym b) gs) items;
  emit (Int 0);
  emit Ret;
  funcs := { name = mangle name ^ ".Init"; nparams = 0; nslots = !cur.nslots; code = List.rev !cur.code } :: !funcs;
  while not (Queue.is_empty queue) do (Queue.pop queue) () done;
  (* old: List.iter (fun n -> for k = 0 to n - 1 do curry_fun n k done) !arities; *)
  List.iter (fun n -> if n > shared_most then for k = 0 to n - 1 do curry_fun n k done) !arities;
  data := Roots (mangle name ^ ".Roots", List.rev !globals) :: !data;
  { funcs = List.rev !funcs; data = List.rev !data }
