(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyCParser.mli *)
open Common
open TinyCTypes
open TinyCLexer
open TinyCTree

(*****************************************************************************)
(* The parser: declarations, and statements *)
(*****************************************************************************)

type storage = Auto | Static | Extern | Typedef

type var = { vty : ty; where : place }

let toks : token array ref = ref (Array.of_list []) and pos = ref 0
(* each token's, for the errors *)
let locs : loc array ref = ref (Array.of_list [])
let peek () = if !pos < Array.length !toks then (!toks).(!pos) else EOF
let next () = let t = peek () in incr pos; t
let accept p = if peek () = P p then (incr pos; true) else false
let expect p = if not (accept p) then error ("expected " ^ p)
let ident () = match next () with Id x -> x | _ -> error "expected a name"

let globals : (string, var) Hashtbl.t = Hashtbl.create 64
let typedefs : (string, ty) Hashtbl.t = Hashtbl.create 16
(* an enum's constants, ints *)
let enums : (string, int64) Hashtbl.t = Hashtbl.create 16
let structs : (string, sdef) Hashtbl.t = Hashtbl.create 16
let scopes : (string, var) Hashtbl.t list ref = ref []
let frame = ref 0                         (* the current function's locals *)
let result = ref Void
let data = Buffer.create 4096             (* the DATA and GLOBL *)

(* a global's name in the assembly: Plan 9's name<> for a static is,
 * the link being one namespace, the file's name and the name *)
let sym s =
  if Filename.check_suffix s "<>" then
    !unit_name ^ "." ^ Filename.chop_suffix s "<>"
  else s

type datum = Bytes of string | Value of int * int64 | Address of string

(* each global's data, at their offsets, until its label is written
 * (a string in an initializer is written before its array) *)
let pending : (string, (int * datum) list) Hashtbl.t = Hashtbl.create 16

let datum name off d =
  Hashtbl.replace pending name
    ((off, d) :: (Hashtbl.find_opt pending name ||| []))

(* a value's low 32 bits, signed, in decimal (old: Printf's %ld of
 * Int64.to_int32) *)
let word v = Int64.to_string (Int64.shift_right (Int64.shift_left v 32) 32)

(* a global of n bytes: its label and its data, the gaps zeros *)
let globl name n =
  let line s = Printf.bprintf data "\t%s\n" s in
  Buffer.add_string data ("\t.align\t4\n" ^ sym name ^ ":\n");
  let bytes l =
    line (".byte\t" ^ String.concat ", " (List.map string_of_int l)) in
  let at = List.fold_left (fun at (off, d) ->
    if off > at then line (Printf.sprintf ".space\t%d" (off - at));
    match d with
    | Bytes b ->
        bytes (List.map Char.code (List.init (String.length b) (String.get b)));
        off + String.length b
    | Value (1, v) -> bytes [ Int64.to_int v land 0xff ]; off + 1
    | Value (2, v) ->
        bytes [ Int64.to_int v land 0xff; (Int64.to_int v lsr 8) land 0xff ];
        off + 2
    | Value (k, v) ->
        line (".word\t" ^ word v);
        if k = 8 then line (".word\t" ^ word (Int64.shift_right v 32));
        off + k
    | Address s -> line (".word\t" ^ sym s); off + 4)
    0 (List.sort (fun (a, _) (b, _) -> compare a b)
         (List.rev (Hashtbl.find_opt pending name ||| []))) in
  if n > at then line (Printf.sprintf ".space\t%d" (n - at));
  Hashtbl.remove pending name
let strings = ref 0
let tags = ref 0                          (* the anonymous structures' *)

let lookup x =
  match List.find_map (fun s -> Hashtbl.find_opt s x) !scopes with
  | Some v -> v
  | None ->
      (match Hashtbl.find_opt globals x with
       | Some v -> v
       | None -> error ("undeclared: " ^ x))

(* a local's place, below SP at its alignment *)
let local t =
  frame := round (!frame + size t) (max 1 (min 8 (align t))); Local !frame

(* a string, as a static array of bytes *)
let string_lit s =
  incr strings;
  let name = Printf.sprintf "s%d<>" !strings in
  let s = s ^ "\000" in
  for i = 0 to (String.length s - 1) / 8 do
    datum name (8 * i)
      (Bytes (String.sub s (8 * i) (min 8 (String.length s - (8 * i)))))
  done;
  globl name (String.length s);
  var (Global name) (Arr (char_t, String.length s))

let is_type () =
  match peek () with
  | Id ("void" | "char" | "short" | "int" | "long" | "unsigned" | "signed"
        | "struct" | "enum" | "static" | "extern" | "const" | "typedef") -> true
  | Id x ->
      Hashtbl.mem typedefs x
      && not (List.exists (fun s -> Hashtbl.mem s x) !scopes)
  | _ -> false

(* the words before a declarator: the type, and static, extern, typedef *)
let rec base_type () =
  let storage = ref Auto and words = ref [] and t = ref None in
  let rec go () =
    match peek () with
    | Id (("static" | "extern" | "typedef") as w) ->
        ignore (next ());
        storage :=
          List.assoc w
            [ "static", Static; "extern", Extern; "typedef", Typedef ];
        go ()
    | Id ("const" | "volatile") -> ignore (next ()); go ()
    | Id (("void" | "char" | "short" | "int" | "long" | "unsigned" | "signed")
          as w) ->
        ignore (next ()); words := w :: !words; go ()
    | Id "struct" -> ignore (next ()); t := Some (struct_type ()); go ()
    | Id "enum" -> ignore (next ()); t := Some (enum_type ()); go ()
    | Id x when !words = [] && !t = None && Hashtbl.mem typedefs x ->
        ignore (next ()); t := Some (Hashtbl.find typedefs x); go ()
    | _ -> ()
  in
  go ();
  let w = !words in
  let signed = not (List.mem "unsigned" w) in
  let longs = List.length (List.filter (( = ) "long") w) in
  let width =
    if List.mem "char" w then 1 else if List.mem "short" w then 2
    else if longs >= 2 then 8 else 4 in
  let t =
    match !t with
    | Some t -> t
    | None -> if List.mem "void" w then Void else Int (width, signed) in
  !storage, t

and struct_type () =
  let tag =
    match peek () with
    | Id x -> ignore (next ()); x
    | _ -> incr tags; Printf.sprintf ".%d" !tags in
  let s =
    match Hashtbl.find_opt structs tag with
    | Some s -> s
    | None ->
        let s = { fields = []; ssize = 0; salign = 1 } in
        Hashtbl.replace structs tag s; s in
  if accept "{" then begin
    (* each member at its size's alignment, the whole rounded to 8, as 7c *)
    let off = ref 0 in
    while not (accept "}") do
      let _, bt = base_type () in
      let rec members () =
        let name, t = declarator bt in
        no_vlong t;
        off := round !off (align t);
        s.fields <- s.fields @ [ name, t, !off ];
        off := !off + size t;
        s.salign <- max s.salign (align t);
        if accept "," then members ()
      in
      members ();
      expect ";"
    done;
    s.ssize <- round !off 8
  end;
  Struct s

(* enum tag { A, B = 5, C }: its constants numbered from 0, or from the
 * last given; the type an int *)
and enum_type () =
  (match peek () with Id _ -> ignore (next ()) | _ -> ());
  if accept "{" then begin
    let rec go v =
      if not (accept "}") then
        (let x = ident () in
         let v = if accept "=" then const_expr () else v in
         Hashtbl.replace enums x v;
         ignore (accept ",");
         go (Int64.succ v)) in
    go Int64.zero
  end;
  int_t

(* * name [n]... or name(params), with the parameters' names *)
and declarator bt = let name, t, _ = declarator3 bt in name, t

and declarator3 bt =
  let name, wrap, pnames = declarator_rec () in
  name, wrap bt, pnames

(* C's declarators, inside out: stars, then a name or a parenthesized
 * declarator, then ( params ) or [ n ]...; the type is built from the
 * base outward, the parenthesized one applied last: int ( *f[3])(int)
 * is an array of pointers to functions. The parameters' names are the
 * innermost function's (a definition's) *)
and declarator_rec () : string * (ty -> ty) * string list =
  let stars = ref 0 in
  while accept "*" do incr stars; ignore (accept "const") done;
  let ptrs t = let t = ref t in for _i = 1 to !stars do t := Ptr !t done; !t in
  let name, inner, inner_names =
    if peek () = P "("
       && (incr pos; let star = peek () = P "*" in decr pos; star)
    then begin
      ignore (next ());
      let r = declarator_rec () in
      expect ")";
      r
    end
    else
      ((match peek () with Id x -> ignore (next ()); x | _ -> ""),
       (fun t -> t), []) in
  if accept "(" then begin
    (* the parameters, named or not, an array's as a pointer; ... *)
    let rec params () =
      if accept ")" then [], false
      else if accept "..." then (expect ")"; [], true)
      else begin
        let _, pt = base_type () in
        let pname, pt = declarator pt in
        let pt = match pt with Arr (e, _) -> Ptr e | t -> t in
        ignore (accept ",");
        let rest, variadic = params () in
        (if pt <> Void || pname <> "" then (pname, pt) :: rest else rest),
        variadic
      end
    in
    let ps, variadic = params () in
    name, (fun t -> inner (Func (ptrs t, List.map snd ps, variadic))),
    (if inner_names <> [] then inner_names else List.map fst ps)
  end
  else begin
    let rec dims () =
      if accept "[" then
        (let n =
           if peek () = P "]" then 0 else Int64.to_int (const_expr ()) in
         expect "]";
         n :: dims ())
      else [] in
    let ds = dims () in
    name,
    (fun t -> inner (List.fold_right (fun n t -> Arr (t, n)) ds (ptrs t))),
    inner_names
  end

(* expressions, by precedence climbing *)
and expr () =
  let e = assign_expr () in
  if accept "," then (let r = expr () in mk (Comma (e, r)) r.t) else e

and assign_expr () =
  let l = cond_expr () in
  match peek () with
  | P "=" -> ignore (next ()); assign false l (assign_expr ())
  | P op when List.mem_assoc op asg_ops ->
      ignore (next ()); asg_op (List.assoc op asg_ops) l (assign_expr ())
  | _ -> l

and cond_expr () =
  let c = binary_expr 0 in
  if accept "?" then begin
    let a = rv (expr ()) in
    expect ":";
    let b = rv (cond_expr ()) in
    let t =
      if is_int a.t && is_int b.t then common a.t b.t
      else if is_ptr a.t then a.t
      else b.t in
    mk (Cond (rv c, conv a t, conv b t)) t
  end
  else c

and binary_expr min =
  let levels = [ [ "||" ]; [ "&&" ]; [ "|" ]; [ "^" ]; [ "&" ]; [ "=="; "!=" ];
                 [ "<"; ">"; "<="; ">=" ]; [ "<<"; ">>" ]; [ "+"; "-" ];
                 [ "*"; "/"; "%" ] ] in
  let rec loop l =
    match peek () with
    | P op -> (
        let rec index i = function
          | [] -> None
          | l :: r -> if List.mem op l then Some i else index (i + 1) r in
        match index 0 levels with
        | Some lv when lv >= min ->
            ignore (next ());
            let r = binary_expr (lv + 1) in
            loop (match op with
                  | "&&" -> both l r
                  | "||" -> either l r
                  | op -> binary (List.assoc op binops) l r)
        | _ -> l)
    | _ -> l
  in
  loop (unary ())

and unary () =
  match peek () with
  | P "-" ->
      ignore (next ());
      let e = rv (unary ()) in
      let t = promote e.t in
      (match e.d with
       | Const v -> num (Int64.neg v) t
       | _ -> mk (Un (Neg, conv e t)) t)
  | P "+" -> ignore (next ()); let e = rv (unary ()) in conv e (promote e.t)
  | P "~" ->
      ignore (next ());
      let e = rv (unary ()) in
      let t = promote e.t in
      mk (Un (Com, conv e t)) t
  | P "!" -> ignore (next ()); lnot (unary ())
  | P "*" -> ignore (next ()); deref (unary ())
  | P "&" -> ignore (next ()); addr (unary ())
  | P (("++" | "--") as op) ->
      ignore (next ());
      asg_op (if op = "++" then Add else Sub) (unary ()) (num Int64.one int_t)
  | Id "sizeof" ->
      ignore (next ());
      let t = if paren_type () then type_name () else (unary ()).t in
      num (Int64.of_int (size t)) (Int (4, false))
  | P "(" when paren_type () -> let t = type_name () in conv (rv (unary ())) t
  | _ -> postfix (primary ())

(* ( type ...: a cast, or sizeof's type *)
and paren_type () =
  peek () = P "(" && (incr pos; let ty = is_type () in decr pos; ty)

(* a type in parentheses: a cast's, sizeof's *)
and type_name () =
  expect "(";
  let _, bt = base_type () in
  let t = snd (declarator bt) in
  expect ")"; t

(* a call's arguments, after its (: each to its declared parameter's
 * type, else promoted *)
and call_args ps =
  let rec go () =
    let a = rv (assign_expr ()) in
    if accept "," then a :: go () else (expect ")"; [ a ]) in
  let args = if accept ")" then [] else go () in
  List.mapi (fun i (a : expr) ->
    match List.nth_opt ps i with
    | Some t -> conv a t
    | None -> conv a (promote a.t)) args

and postfix e =
  match peek () with
  | P "(" ->
      (* a call through a function's address: a pointer, or ( *f ) *)
      ignore (next ());
      let f = rv e in
      let rt, ps =
        match f.t with
        | Ptr (Func (r, p, _)) -> r, p
        | _ -> error "not a function" in
      postfix (mk (ApplyPtr (f, call_args ps)) rt)
  | P "[" ->
      ignore (next ());
      let i = expr () in
      expect "]"; postfix (deref (binary (A Add) e i))
  | P "." -> ignore (next ()); postfix (member e (ident ()))
  | P "->" -> ignore (next ()); postfix (member (deref e) (ident ()))
  | P (("++" | "--") as op) ->
      ignore (next ());
      (* x++ is (x += 1) - 1, and so on *)
      let o, back = if op = "++" then Add, Sub else Sub, Add in
      postfix
        (conv (binary (A back) (asg_op o e (num Int64.one int_t))
                 (num Int64.one int_t)) e.t)
  | _ -> e

and member e f =
  match e.t with
  | Struct s -> (
      match List.find_opt (fun (n, _, _) -> n = f) s.fields with
      | Some (_, t, off) ->
          mk (Deref (mk (Bin (A Add, conv (addr e) long_t,
                              num (Int64.of_int off) long_t)) (Ptr t))) t
      | None -> error ("no member " ^ f))
  | _ -> error "not a structure"

and primary () =
  match next () with
  | Num (v, ll) ->
      num v (if ll || Int64.compare v int_max > 0 then long_t else int_t)
  | Str s -> string_lit s
  | P "(" -> let e = expr () in expect ")"; e
  | Id f when peek () = P "("
              && (match (try Some (lookup f) with Failure _ -> None) with
                  | Some { vty = Func _; _ } | None -> true
                  | _ -> false) ->
      ignore (next ());
      let rt, ps, sym =
        match (try Some (lookup f) with Failure _ -> None) with
        | Some { vty = Func (r, p, _); where = Global s } -> r, p, s
        | _ -> int_t, [], f in
      mk (Apply (sym, call_args ps)) rt
  | Id x when Hashtbl.mem enums x
              && not (List.exists (fun s -> Hashtbl.mem s x) !scopes
                      || Hashtbl.mem globals x) ->
      num (Hashtbl.find enums x) int_t
  | Id x -> let v = lookup x in var v.where v.vty
  | _ -> error "expected an expression"

(* a constant expression, folded: an array's size, a case, an enum's
 * value (NDIRECT + 1, sizeof a / sizeof a[0]); 64-bit arithmetic, as the
 * values are *)
and const_expr () =
  let rec fold (e : expr) =
    match e.d with
    | Const v -> v
    | Conv a -> fold a
    | Un (Neg, a) -> Int64.neg (fold a)
    | Un (Com, a) -> Int64.lognot (fold a)
    | Bin (A o, a, b) ->
        let a = fold a and b = fold b in
        (match o with
         | Add -> Int64.add a b | Sub -> Int64.sub a b | Mul -> Int64.mul a b
         | Div ->
             if b = Int64.zero then error "division by zero" else Int64.div a b
         | Mod ->
             if b = Int64.zero then error "division by zero" else Int64.rem a b
         | And -> Int64.logand a b | Or -> Int64.logor a b
         | Xor -> Int64.logxor a b
         | Shl -> Int64.shift_left a (Int64.to_int b)
         | Shr -> Int64.shift_right a (Int64.to_int b))
    | _ -> error "not a constant" in
  fold (cond_expr ())

(* statements *)
let cond () = expect "("; let c = rv (expr ()) in expect ")"; c

let rec statement () : stmt =
  match next () with
  | P "{" -> block ()
  | P ";" -> Block []
  | Id "if" ->
      let c = cond () in
      let a = statement () in
      If (c, a,
          if peek () = Id "else" then (ignore (next ()); Some (statement ()))
          else None)
  | Id "while" -> let c = cond () in For (None, Some c, None, statement ())
  | Id "do" ->
      let body = statement () in
      ignore (next ());
      let c = cond () in
      expect ";"; Do (body, c)
  | Id "for" ->
      (* an expression, or none, then the token that ends it *)
      let opt close =
        let e = if peek () = P close then None else Some (expr ()) in
        expect close; e in
      expect "(";
      let init = opt ";" in
      let c = Option.map rv (opt ";") in
      let step = opt ")" in
      For (init, c, step, statement ())
  | Id "switch" ->
      let v = conv (cond ()) long_t in
      let tmp = var (local long_t) long_t in
      Switch (tmp, v, statement ())
  | Id "case" ->
      let v = const_expr () in expect ":"; Block [ Case (Some v); statement () ]
  | Id "default" -> expect ":"; Block [ Case None; statement () ]
  | Id "break" -> expect ";"; Break
  | Id "continue" -> expect ";"; Continue
  | Id "return" ->
      if accept ";" then Return None
      else (let e = conv (rv (expr ())) !result in expect ";"; Return (Some e))
  | _ ->
      decr pos;
      if is_type () then Block (locals ())
      else (let e = expr () in expect ";"; Expr e)

and block () =
  scopes := Hashtbl.create 8 :: !scopes;
  let rec go acc =
    if accept "}" then List.rev acc else go (statement () :: acc) in
  let l = go [] in
  scopes := List.tl !scopes;
  Block l

(* a declaration of locals: their initializations *)
and locals () =
  let storage, bt = base_type () in
  let rec go () =
    let name, t = declarator bt in
    let init =
      if storage = Typedef then (Hashtbl.replace typedefs name t; [])
      else begin
        no_vlong t;
        let p = local t in
        Hashtbl.replace (List.hd !scopes) name { vty = t; where = p };
        if accept "=" then [ Expr (assign false (var p t) (assign_expr ())) ]
        else []
      end
    in
    init @ (if accept "," then go () else [])
  in
  let l = go () in
  expect ";";
  l
