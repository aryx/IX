(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Eval.mli *)

open Ast

exception Error of string
exception Returned of value

let error fmt = Printf.ksprintf (fun s -> raise (Error s)) fmt

(*****************************************************************************)
(* The variables *)
(*****************************************************************************)

(* a variable's binding (acid's Value): its value (None: not set), the
 * complex type complex T v gave it (the binding's: an assignment keeps
 * it, a function's own v has its own) *)
type binding = { bvalue : value option; btype : string option }

(* a name's meanings (acid's Lsym): its bindings' stack, the current
 * first, its function, its members when it names a complex type *)
type var = {
  mutable values : binding list;
  mutable defn : (param list * stmt list) option;
  mutable aggr : member list option;
}

let unset = { bvalue = None; btype = None }

let vars : (string, var) Hashtbl.t = Hashtbl.create 256
let builtins : (string, value list -> value) Hashtbl.t = Hashtbl.create 64

let var name =
  match Hashtbl.find_opt vars name with
  | Some v -> v
  | None -> let v = { values = [ unset ]; defn = None; aggr = None } in Hashtbl.replace vars name v; v

let get name =
  let x = var name in
  match x.values with { bvalue = Some v; btype } :: _ -> { v with comt = btype } | _ -> error "%s used but not set" name

let set name v =
  let x = var name in
  x.values <- (match x.values with b :: rest -> { b with bvalue = Some v } :: rest | [] -> [ { unset with bvalue = Some v } ])

(* the running functions, the innermost first: the names each pushed *)
let frames : string list ref list ref = ref []

let in_function () = !frames <> []

let push name v =
  match !frames with
  | pushed :: _ ->
      if List.mem name !pushed then error "%s declared twice" name;
      let x = var name in
      x.values <- { unset with bvalue = v } :: x.values;
      pushed := name :: !pushed
  | [] -> error "local not in function"

let pop name =
  let x = var name in
  x.values <- (match x.values with _ :: (_ :: _ as rest) -> rest | l -> l)

let reset () = frames := []

let set_global name v =
  let x = var name in
  x.values <- (match List.rev x.values with b :: older -> List.rev ({ b with bvalue = Some v } :: older) | [] -> [ { unset with bvalue = Some v } ])

let is_set name =
  match Hashtbl.find_opt vars name with Some { values = { bvalue = Some _; _ } :: _; _ } -> true | _ -> false

let complex_type name = match (var name).values with b :: _ -> b.btype | [] -> None

let aggr name = (var name).aggr

(*****************************************************************************)
(* Printing *)
(*****************************************************************************)

let out = Buffer.create 4096

(* the locals' complex types, complex T f:v's *)
let frame_types : (string * string, string) Hashtbl.t = Hashtbl.create 64

(* f:v's address, Proc's (libmach's localaddr) *)
let local_addr : (string -> string -> int64) ref = ref (fun _ _ -> error "colon: no process")

let load : (bool -> int64 -> int -> string) ref = ref (fun core _ _ -> (if core then error "no map for *" else error "no map for @"))
let store : (int64 -> string -> unit) ref = ref (fun _ _ -> error "no map for *")

(* without the program's symbols, an address is its number *)
let symbol = ref (fun i -> Printf.sprintf "0x%Lx" i)

let show v = Value.show ~symbol:(fun i -> !symbol i) v


let whatis = function
  | None -> Hashtbl.iter (fun name x -> if x.defn <> None then Buffer.add_string out (name ^ "\n")) vars
  | Some name ->
      let x = var name in
      let said = ref false in
      (match x.values with
       | { bvalue = Some v; btype } :: _ ->
           Buffer.add_string out (Value.type_name v ^ " variable");
           (match v.kind with Int _ | Float _ -> Buffer.add_string out (Printf.sprintf " format %c" v.fmt) | _ -> ());
           (match btype with Some t -> Buffer.add_string out (" complex " ^ t) | None -> ());
           Buffer.add_char out '\n';
           said := true
       | _ -> ());
      (match x.aggr with
       | Some ms ->
           Buffer.add_string out (Printf.sprintf "complex %s {\n" name);
           List.iter (fun m ->
             Buffer.add_string out (match m.mtype with
               | Some t when m.mfmt = 'a' -> Printf.sprintf "\t%s %d %s;\n" t m.moffset m.mname
               | Some t -> Printf.sprintf "\t'%c' %s %d %s;\n" m.mfmt t m.moffset m.mname
               | None -> Printf.sprintf "\t'%c' %d %s;\n" m.mfmt m.moffset m.mname)) ms;
           Buffer.add_string out "};\n";
           said := true
       | None -> ());
      (match x.defn with
       | Some (ps, body) ->
           Buffer.add_string out (Printf.sprintf "defn %s(%s) {\n%s}\n" name
             (String.concat "," (List.map (fun p -> if p.by_name then "*" ^ p.pname else p.pname) ps))
             (Code.stmts 1 body));
           said := true
       | None -> ());
      if Hashtbl.mem builtins name then (Buffer.add_string out "builtin function\n"; said := true);
      if not !said then Buffer.add_string out (name ^ " is undefined\n")

(*****************************************************************************)
(* The expressions *)
(*****************************************************************************)

let int fmt i = { kind = Int i; fmt; comt = None }
let truth = Value.truth

(* a rune added to a string: its UTF-8 *)
let utf8 c =
  let b = Buffer.create 4 in
  Buffer.add_utf_8_uchar b (Uchar.of_int (Int64.to_int c land 0x1fffff));
  Buffer.contents b

let rec last (c : cell) = match c.next with Some d -> last d | None -> c

(* + on lists: the right one linked at the left one's end, in place *)
let addlist a b = match a with None -> b | Some c -> (last c).next <- b; a

let to_float (v : value) = match v.kind with Int i -> Int64.to_float i | Float f -> f | _ -> 0.

let name_of_op = function
  | Mul -> "*" | Div -> "/" | Mod -> "%" | Add -> "+" | Sub -> "-" | Rsh -> ">>" | Lsh -> "<<"
  | Lt -> "<" | Gt -> ">" | Leq -> "<=" | Geq -> ">=" | Eq -> "==" | Neq -> "!="
  | Land -> "&" | Xor -> "^" | Lor -> "|"

(* (acid's words for a wrong operand: bad lhs type, bad rhs type, or
 * bad expr type for the integers' operators, and <='s) *)
let binop op (l : value) (r : value) =
  let number (v : value) = match v.kind with Int _ | Float _ -> true | _ -> false in
  let numbers = number l && number r in
  let bad () =
    match op with
    | Mod | Rsh | Lsh | Land | Xor | Lor | Leq -> error "bad expr type %s" (name_of_op op)
    | _ -> if number l then error "bad rhs type %s" (name_of_op op) else error "bad lhs type %s" (name_of_op op) in
  match op with
  | Add | Sub | Mul | Div | Mod ->
      (match op, l.kind, r.kind with
       | Add, String a, String b -> { kind = String (a ^ b); fmt = 's'; comt = None }
       | Add, String a, Int c -> { kind = String (a ^ utf8 c); fmt = 's'; comt = None }
       | Add, String _, _ -> error "bad rhs for +"
       | Add, List a, List b -> { kind = List (addlist a b); fmt = l.fmt; comt = None }
       | Add, List a, _ -> { kind = List (addlist a (Some { value = r; next = None })); fmt = l.fmt; comt = None }
       | (Div | Mod), Int _, Int 0L -> error "zero divide"
       | Div, _, Float 0. -> error "zero divide"
       | _, Int a, Int b ->
           let f = match op with Add -> Int64.add | Sub -> Int64.sub | Mul -> Int64.mul | Div -> Int64.div | _ -> Int64.rem in
           { kind = Int (f a b); fmt = l.fmt; comt = None }
       | (Add | Sub | Mul | Div), _, _ when numbers ->
           let a = to_float l and b = to_float r in
           let f = match op with Add -> a +. b | Sub -> a -. b | Mul -> a *. b | _ -> a /. b in
           { kind = Float f; fmt = l.fmt; comt = None }
       | _ -> bad ())
  | Rsh | Lsh | Land | Xor | Lor ->
      (match l.kind, r.kind with
       | Int a, Int b ->
           let v = match op with
             | Rsh -> Int64.shift_right_logical a (Int64.to_int b)
             | Lsh -> Int64.shift_left a (Int64.to_int b)
             | Land -> Int64.logand a b
             | Xor -> Int64.logxor a b
             | _ -> Int64.logor a b in
           { kind = Int v; fmt = l.fmt; comt = None }
       | _ -> bad ())
  | Eq | Neq ->
      let e = Value.equal l r in
      int 'D' (if (if op = Eq then e else not e) then 1L else 0L)
  | Lt | Gt | Leq | Geq ->
      if not numbers then bad ();
      let c = match l.kind, r.kind with Int a, Int b -> compare a b | _ -> compare (to_float l) (to_float r) in
      let b = match op with Lt -> c < 0 | Gt -> c > 0 | Leq -> c <= 0 | _ -> c >= 0 in
      int (match op with Lt | Gt -> l.fmt | _ -> 'D') (if b then 1L else 0L)

(* acid's indir: what is at an address, read as its format says (a
 * byte, a half, a word, 8 bytes, a string to its NUL, an instruction
 * as its text), little-endian; an address is 4 bytes on arm (a, A, W:
 * geta), 8 on arm64 (a, A: addr_size) *)
let addr_size = ref 4

let width = function
  | 'c' | 'C' | 'b' -> 1
  | 'x' | 'd' | 'u' | 'o' | 'q' | 'r' -> 2
  | 'a' | 'A' -> !addr_size
  | 'W' | 'B' | 'X' | 'D' | 'U' | 'O' | 'Q' -> 4
  | 'V' | 'Y' | 'Z' -> 8
  | c -> error "bad pointer format '%c' for *" c

let indir core addr fmt =
  match fmt with
  | 's' ->
      let b = Buffer.create 32 in
      let rec go a = if Buffer.length b < 511 then (let c = !load core a 1 in if c <> "\000" then (Buffer.add_string b c; go (Int64.add a 1L))) in
      go addr;
      { kind = String (if Buffer.length b = 0 then "(null)" else Buffer.contents b); fmt = 's'; comt = None }
  | 'f' | 'F' ->
      (* a float, a double (acid's 'f' and 'F') *)
      let n = if fmt = 'f' then 4 else 8 in
      let s = !load core addr n in
      let v = ref 0L in
      for i = n - 1 downto 0 do v := Int64.logor (Int64.shift_left !v 8) (Int64.of_int (Char.code s.[i])) done;
      { kind = Float (if n = 4 then Int32.float_of_bits (Int64.to_int32 !v) else Int64.float_of_bits !v); fmt; comt = None }
  | 'i' | 'I' ->
      (match !Value.das core addr with
       | Some s -> { kind = String s; fmt = 's'; comt = None }
       | None -> error "indir: can't read instruction")
  | _ ->
      let n = width fmt in
      let s = !load core addr n in
      let v = ref 0L in
      for i = n - 1 downto 0 do v := Int64.logor (Int64.shift_left !v 8) (Int64.of_int (Char.code s.[i])) done;
      { kind = Int !v; fmt; comt = None }

(* windir: a value written at an address, as many bytes as its format
 * says (a string: its bytes) *)
let windir addr (v : value) =
  match v.kind with
  | String s -> !store addr s
  | Int i ->
      let n = width v.fmt in
      !store addr (String.init n (fun k -> Char.chr (Int64.to_int (Int64.logand (Int64.shift_right_logical i (8 * k)) 0xffL))))
  | _ -> error "bad type for *"

let rec eval (e : expr) : value =
  match e with
  | Const v -> v
  | Name s -> get s
  | Bin (op, a, b) -> let l = eval a in binop op l (eval b)
  | Cand (a, b) -> int 'D' (if truth (eval a) && truth (eval b) then 1L else 0L)
  | Cor (a, b) -> int 'D' (if truth (eval a) || truth (eval b) then 1L else 0L)
  | Assign (Name s, r) -> let v = eval r in set s v; v
  | Assign (Indm a, r) ->
      let l = eval a in
      let v = eval r in
      (match l.kind with Int addr -> windir addr { v with fmt = l.fmt }; v | _ -> error "bad type for *")
  | Assign (Indc _, _) -> error "no map for @"
  | Assign _ -> error "need l-value"
  | Fmt (a, c) -> { (eval a) with fmt = c }
  | Plus a -> eval a
  | Not a -> let v = eval a in { kind = Int (if truth v then 0L else 1L); fmt = v.fmt; comt = None }
  | Preinc a -> step a 1 true
  | Predec a -> step a (-1) true
  | Postinc a -> step a 1 false
  | Postdec a -> step a (-1) false
  | Head a ->
      (match (eval a).kind with
       | List (Some c) -> c.value
       | List None -> Value.empty
       | _ -> error "head needs list")
  | Tail a ->
      (match (eval a).kind with
       | List (Some c) -> { kind = List c.next; fmt = 'X'; comt = None }
       | List None -> Value.empty
       | _ -> error "tail needs list")
  | Append (a, b) ->
      let l = eval a in
      let r = eval b in
      let cell = Some { value = r; next = None } in
      (match l.kind, a with
       | List None, Name s -> let v = { kind = List cell; fmt = l.fmt; comt = None } in set s v; v
       | List None, _ -> { kind = List cell; fmt = l.fmt; comt = None }
       | List (Some c), _ -> (last c).next <- cell; l
       | _ -> error "must append to list")
  | Delete (a, b) ->
      let l = eval a in
      let r = eval b in
      (match l.kind, r.kind with
       | List cells, Int n ->
           if n < 0L then error "negative index in delete";
           let rec drop prev (c : cell option) n =
             match c with
             | None -> error "element beyond end of list"
             | Some (c : cell) when n = 0L ->
                 (match prev with
                  | None -> { l with kind = List c.next }
                  | Some (p : cell) -> p.next <- c.next; l)
             | Some c -> drop (Some c) c.next (Int64.sub n 1L) in
           drop None cells n
       | List _, _ -> error "delete index must be integer"
       | _ -> error "must delete from list")
  | Eval a -> (match (eval a).kind with Code c -> eval c | _ -> error "bad type for eval")
  | Index (a, b) ->
      let l = eval a in
      let r = eval b in
      (match l.kind, r.kind with
       | List cells, Int n ->
           if n < 0L then error "negative index in []";
           let rec nth (c : cell option) n = match c with
             | None -> Value.empty
             | Some (c : cell) -> if n = 0L then c.value else nth c.next (Int64.sub n 1L) in
           nth cells n
       | String s, Int n ->
           int 'c' (if n >= 0L && n < Int64.of_int (String.length s) then Int64.of_int (Char.code s.[Int64.to_int n]) else 0L)
       | Int addr, Int n -> { (indir true (Int64.add addr (Int64.mul n (Int64.of_int (Value.size l.fmt)))) l.fmt) with fmt = l.fmt; comt = l.comt }
       | _, Int _ -> error "lhs[] has bad type"
       | _ -> error "bad type for []")
  | Construct es -> Value.list (List.map eval es)
  | What n -> whatis n; Value.empty
  | Call (f, args, builtin) -> call f args builtin
  | Indm a -> (match eval a with { kind = Int addr; fmt; comt } -> { (indir true addr fmt) with comt } | _ -> error "bad type for *")
  | Indc a -> (match eval a with { kind = Int addr; fmt; comt } -> { (indir false addr fmt) with comt } | _ -> error "bad type for @")
  | Cast (t, a) ->
      if (var t).aggr = None then error "%s is not a complex type" t;
      { (eval a) with comt = Some t; fmt = 'a' }
  | Dot (a, m) -> dot (eval a) m
  | Frame (f, v) ->
      (* a local's address in the innermost frame of f, typed as complex
       * f:v said (acid's Frtype) *)
      let addr = !local_addr f v in
      (match Hashtbl.find_opt frame_types (f, v) with
       | Some t -> { kind = Int addr; fmt = 'a'; comt = Some t }
       | None -> { kind = Int addr; fmt = 'X'; comt = None })

(* e.m (acid's odot): the member's address, the value's and its offset;
 * an aggregate there is its address (format a), else what is there read
 * by the member's format; the member's own complex type kept *)
and dot (v : value) m =
  let t = match v.comt with Some t -> t | None -> error "no type specified for (expr).%s" m in
  let addr = match v.kind with Int i -> i | _ -> error "pointer must be integer for (expr).%s" m in
  let ms = match (var t).aggr with Some ms -> ms | None -> [] in
  match List.find_opt (fun mb -> mb.mname = m) ms with
  | None -> error "no tag for (expr).%s" m
  | Some mb ->
      let a = Int64.add addr (Int64.of_int mb.moffset) in
      if mb.mfmt = 'a' then { kind = Int a; fmt = 'a'; comt = mb.mtype }
      else { (indir true a mb.mfmt) with comt = mb.mtype }

(* ++ and --: an integer moved by its format's size (a pointer's step),
 * a float by 1; the new value or the old *)
and step a delta pre =
  match a with
  | Name s ->
      let v = get s in
      let nv = match v.kind with
        | Int i -> { v with kind = Int (Int64.add i (Int64.of_int (delta * Value.size v.fmt))) }
        | Float f -> { v with kind = Float (f +. float_of_int delta) }
        | _ -> error "bad type for ++ or --" in
      set s nv;
      if pre then nv else v
  | _ -> error "need l-value"

and call f args builtin =
  let x = var f in
  match Hashtbl.find_opt builtins f, x.defn with
  | None, _ when builtin -> error "no builtin %s" f
  | Some b, d when builtin || d = None -> b (List.map eval args)
  | _, Some (params, body) -> apply f params args body
  | _ -> error "no function %s" f

and apply f params args body =
  let np = List.length args and nf = List.length params in
  if np < nf then error "%s: too few arguments" f;
  if np > nf then error "%s: too many arguments" f;
  let pushed = ref [] in
  frames := pushed :: !frames;
  let unwind () = List.iter pop !pushed; frames := List.tl !frames in
  match
    List.iter2 (fun (p : param) a ->
      let v = if p.by_name then { kind = Code a; fmt = 'X'; comt = None } else eval a in
      if List.mem p.pname !pushed then error "%s already declared at this scope" p.pname;
      push p.pname (Some v)) params args;
    List.iter exec body
  with
  | () -> unwind (); Value.empty
  | exception Returned v -> unwind (); v
  | exception e -> unwind (); raise e

(* print: a complex type's address by the library's pcomplex(addr,
 * "T") if it has one (ix's: by the aggr's members), else by its
 * function, if one (acid's comx: Node(addr), the one 5c -a writes),
 * else its type's name before it *)
and print vs =
  List.iter (fun (v : value) ->
    match v.comt with
    | Some t when (v.fmt = 'a' || v.fmt = 'A') && (var "pcomplex").defn <> None && (var t).aggr <> None ->
        (match (var "pcomplex").defn with
         | Some (ps, body) -> ignore (apply "pcomplex" ps [ Const v; Const (Value.string t) ] body)
         | None -> ())
    | Some t when (v.fmt = 'a' || v.fmt = 'A') && (var t).defn <> None ->
        (match (var t).defn with Some (ps, body) -> ignore (apply t ps [ Const v ] body) | None -> ())
    | Some t when v.fmt = 'a' || v.fmt = 'A' -> Buffer.add_string out ("(" ^ t ^ ")" ^ show v)
    | _ -> Buffer.add_string out (show v)) vs;
  if not (in_function ()) then Buffer.add_char out '\n'

(*****************************************************************************)
(* The statements *)
(*****************************************************************************)

and exec (s : stmt) =
  match s with
  | Expr None -> ()
  | Expr (Some ((Assign _ | Call _) as e)) -> ignore (eval e)
  | Expr (Some e) ->
      let v = eval e in
      let empty = match v.kind, e with List None, Bin (Add, _, _) -> false | List None, _ -> true | _ -> false in
      if not (in_function ()) && not empty then print [ v ]
  | Block ss -> List.iter exec ss
  | If (c, a, b) -> if truth (eval c) then exec a else (match b with Some b -> exec b | None -> ())
  | While (c, b) -> while truth (eval c) do exec b done
  | Loop (a, b, body) ->
      let s = match (eval a).kind with Int i -> i | _ -> error "loop must have integer start" in
      let e = match (eval b).kind with Int i -> i | _ -> error "loop must have integer end" in
      let i = ref s in
      while !i <= e do exec body; i := Int64.add !i 1L done
  | Return e -> if not (in_function ()) then error "return not in function" else raise (Returned (eval e))
  | Local names -> List.iter (fun n -> push n None) names
  | Complex (t, Name v) ->
      (* (acid's decl: the variable's type, its format a) *)
      if (var t).aggr = None then error "%s is not a complex type" t;
      let x = var v in
      x.values <- (match x.values with
        | b :: rest -> { bvalue = Option.map (fun (w : value) -> { w with fmt = 'a' }) b.bvalue; btype = Some t } :: rest
        | [] -> [ { unset with btype = Some t } ])
  | Complex (t, Frame (f, v)) ->
      if (var t).aggr = None then error "%s is not a complex type" t;
      Hashtbl.replace frame_types (f, v) t
  | Complex (t, _) -> if (var t).aggr = None then error "%s is not a complex type" t

let ran = ref (fun () -> ())

let call_if_defined f args =
  match (var f).defn with
  | Some (params, body) -> ignore (apply f params (List.map (fun v -> Const v) args) body)
  | None -> ()

let toplevel = function
  | Stmt s -> exec s
  | Defn (f, ps, body) -> (var f).defn <- Some (ps, body)
  | Undefn f -> (var f).defn <- None
  | Aggr (t, ms) -> (var t).aggr <- Some ms
