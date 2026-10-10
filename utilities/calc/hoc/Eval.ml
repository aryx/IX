(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Eval.mli *)
open Ast

type caps = < Input.caps; Cap.stdout >

let error msg = raise (Symbol.Error msg)

(* a return, up to its call (the C's flag returning, which each loop tests) *)
exception Returned of float option

(* the calls being run: the C's frames, 100 with the one never used *)
let depth = ref 0
let max_depth = 99

let number v =
  if v <> v then "NaN" else if v = infinity then "+Inf" else if v = neg_infinity then "-Inf"
  else if v = 0. then "0"
  else Printf.sprintf "%.12g" v

(* as Plan 9's print: written at once, before what an error says *)
let print (caps : < caps; .. >) s =
  let out = Console.stdout caps in
  output_string out s;
  flush out

let truth b = if b then 1. else 0.

let variable (s : symbol) =
  match s.value with
  | Var v -> v
  | Undef -> error ("undefined variable " ^ s.name)
  | Builtin _ | Func _ | Proc _ -> error ("attempt to evaluate non-variable " ^ s.name)

let rec eval (caps : < caps; .. >) (e : expr) : float =
  match e with
  | Number v -> v
  | Variable s -> variable s
  | Assign (s, op, e) ->
      let v = eval caps e in
      (* (x += 1 for a new x: 1) *)
      let old = match s.value with Var old -> old | Undef -> 0. | Builtin _ | Func _ | Proc _ -> error ("assignment to non-variable " ^ s.name) in
      let v = match op with
        | Set -> v
        | Add_to -> old +. v
        | Sub_to -> old -. v
        | Mul_to -> old *. v
        (* no check, unlike /: an infinity *)
        | Div_to -> old /. v
        (* of the integers, unlike %. (The C divides by 0 here: what
         * the machine does of it, a trap or a number.) *)
        | Mod_to -> if truncate v = 0 then error "division by zero"; float_of_int (truncate old mod truncate v) in
      s.value <- Var v;
      v
  | Binary (left, op, right) ->
      let a = eval caps left in
      let b = eval caps right in
      (match op with
       | Add -> a +. b
       | Sub -> a -. b
       | Mul -> a *. b
       | Div -> if b = 0. then error "division by zero"; a /. b
       | Mod -> if b = 0. then error "division by zero"; mod_float a b
       | Power -> Symbol.check "exponentiation" (a ** b)
       | Gt -> truth (a > b)
       | Ge -> truth (a >= b)
       | Lt -> truth (a < b)
       | Le -> truth (a <= b)
       | Eq -> truth (a = b)
       | Ne -> truth (a <> b)
       | And -> truth (a <> 0. && b <> 0.)
       | Or -> truth (a <> 0. || b <> 0.))
  | Negate e -> -. (eval caps e)
  | Not e -> truth (eval caps e = 0.)
  | Step (s, delta, new_value) ->
      let old = variable s in
      s.value <- Var (old +. delta);
      if new_value then old +. delta else old
  | Call (s, args) -> (match call caps s args with Some v -> v | None -> error (s.name ^ " returns no value"))
  | Apply (f, e) -> f (eval caps e)
  | Read s -> read caps s

and exec (caps : < caps; .. >) (s : stmt) : unit =
  match s with
  | Expr e -> ignore (eval caps e)
  | Return None -> raise (Returned None)
  | Return (Some e) -> raise (Returned (Some (eval caps e)))
  | Call_proc (s, args) -> ignore (call caps s args)
  | Print items -> List.iter (function Value e -> print caps (number (eval caps e) ^ " ") | Text s -> print caps s) items
  | While (cond, body) -> while eval caps cond <> 0. do exec caps body done
  | For (init, cond, step, body) ->
      ignore (eval caps init);
      while eval caps cond <> 0. do exec caps body; ignore (eval caps step) done
  | If (cond, yes, no) -> if eval caps cond <> 0. then exec caps yes else Option.iter (exec caps) no
  | Block stmts -> List.iter (exec caps) stmts

(* the arguments first, then the checks; None: a procedure's return *)
and call (caps : < caps; .. >) (s : symbol) (args : expr list) : float option =
  let values = List.rev (List.fold_left (fun acc e -> eval caps e :: acc) [] args) in
  if !depth >= max_depth then error (s.name ^ " call nested too deeply");
  let def, is_func =
    match s.value with
    | Func def -> (def, true)
    | Proc def -> (def, false)
    (* (it was one when the call was read; the C runs what is there) *)
    | Undef | Var _ | Builtin _ -> error (s.name ^ " is not a function") in
  if List.length values <> List.length def.formals then error (s.name ^ " called with wrong number of arguments");
  (* each formal in turn: of a name given twice, the second keeps the
   * first's argument, and leaves it *)
  let saved = List.rev (List.fold_left2 (fun acc (f : symbol) v -> let old = f.value in f.value <- Var v; (f, old) :: acc) [] def.formals values) in
  incr depth;
  let leave () = decr depth; List.iter (fun ((f : symbol), old) -> f.value <- old) saved in
  let result = try exec caps def.body; None with Returned v -> v | e -> leave (); raise e in
  leave ();
  match result, is_func with
  | Some _, false -> error (s.name ^ " (proc) returns value")
  | None, true -> error (s.name ^ " (func) returns no value")
  | _ -> result

(* the input's next number, from the next file at the end of this one *)
and read (caps : < caps; .. >) (s : symbol) : float =
  let rec skip () = let c = Input.getc () in if c = Char.code ' ' || c = Char.code '\t' || c = Char.code '\n' then skip () else c in
  let rec next () =
    let c = skip () in
    if c < 0 then at_end ()
    else begin
      if not (String.contains "+-.0123456789" (Char.chr c)) then error ("non-number read into " ^ s.name);
      Input.ungetc ();
      let v, ended = Input.number Input.getc in
      if ended < 0 then at_end () else (Input.ungetc (); s.value <- Var v; 1.)
    end
  and at_end () = if Input.more caps then next () else (s.value <- Var 0.; 0.) in
  next ()

(* _, made at the first value printed *)
let last : symbol option ref = ref None

let run (caps : < caps; .. >) (line : line) =
  match line with
  | Run s -> exec caps s
  | Show e ->
      let v = eval caps e in
      print caps (number v ^ "\n");
      let s = match !last with Some s -> s | None -> let s = Symbol.install "_" Undef in last := Some s; s in
      s.value <- Var v
  | Nothing | End -> ()
