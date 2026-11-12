(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Parser.mli *)
open Common

(*****************************************************************************)
(* The parser: declarations, and statements *)
(*****************************************************************************)

type storage = Auto | Static | Extern | Typedef

type var = { vty : Types.ty; where : Tree.place }

let toks : Lexer.token array ref = ref (Array.of_list []) and pos = ref 0
(* each token's, for the errors *)
let locs : Lexer.loc array ref = ref (Array.of_list [])
(* the file's tokens to read *)
let start (ts : Lexer.located list) =
  toks := Array.of_list (List.map fst ts);
  locs := Array.of_list (List.map snd ts);
  pos := 0
(* where the last token read is, for an error: a missing ; is then on
 * its line, not the next one's (None: no token yet) *)
let last_loc () : Lexer.loc option =
  let ls = !locs in
  if Array.length ls = 0 then None
  else Some ls.(max 0 (min (!pos - 1) (Array.length ls - 1)))
let peek () = if !pos < Array.length !toks then (!toks).(!pos) else Lexer.EOF
let at_end () = peek () = Lexer.EOF
let next () = let t = peek () in incr pos; t
let accept p = if peek () = Lexer.P p then (incr pos; true) else false
let accept_word w = if peek () = Lexer.Id w then (incr pos; true) else false
let expect p = if not (accept p) then Types.error ("expected " ^ p)
let ident () =
  match next () with Lexer.Id x -> x | _ -> Types.error "expected a name"

let globals : (string, var) Hashtbl.t = Hashtbl.create 64
let typedefs : (string, Types.ty) Hashtbl.t = Hashtbl.create 16
(* an enum's constants, ints *)
let enums : (string, int64) Hashtbl.t = Hashtbl.create 16
let structs : (string, Types.sdef) Hashtbl.t = Hashtbl.create 16
let scopes : (string, var) Hashtbl.t list ref = ref []
let frame = ref 0                         (* the current function's locals *)
let result = ref Types.Void
(* the definitions of the declaration being read, the last first: a
 * string literal's data before the function or the global it is in *)
let defs : Tree.def list ref = ref []

let strings = ref 0
let tags = ref 0                          (* the anonymous structures' *)

let lookup x =
  match List.find_map (fun s -> Hashtbl.find_opt s x) !scopes with
  | Some v -> v
  | None ->
      (match Hashtbl.find_opt globals x with
       | Some v -> v
       | None -> Types.error ("undeclared: " ^ x))

(* a local's place, below SP at its alignment *)
let local t =
  frame := Types.round (!frame + Types.size t) (max 1 (min 8 (Types.align t)));
  Tree.Local !frame

(* a string, as a static array of bytes *)
let string_lit s =
  incr strings;
  let name = Types.static_sym (Printf.sprintf "s%d" !strings) in
  let s = s ^ "\000" in
  let n = String.length s in
  let pieces =
    List.init (((n - 1) / 8) + 1) (fun i ->
      8 * i, Tree.Bytes (String.sub s (8 * i) (min 8 (n - (8 * i))))) in
  defs := Tree.Data (name, n, pieces) :: !defs;
  Tree.var (Tree.Global name) (Types.Arr (Types.char_t, n))

let is_type () =
  match peek () with
  | Lexer.Id ("void" | "char" | "short" | "int" | "long" | "unsigned" | "signed"
        | "struct" | "enum" | "static" | "extern" | "const" | "volatile"
        | "typedef") -> true
  | Lexer.Id x ->
      Hashtbl.mem typedefs x
      && not (List.exists (fun s -> Hashtbl.mem s x) !scopes)
  | _ -> false

(* the words before a declarator: the type, and static, extern, typedef *)
let rec base_type () =
  let storage = ref Auto and words = ref [] and t = ref None in
  let rec go () =
    match peek () with
    | Lexer.Id (("static" | "extern" | "typedef") as w) ->
        ignore (next ());
        storage :=
          List.assoc w
            [ "static", Static; "extern", Extern; "typedef", Typedef ];
        go ()
    | Lexer.Id ("const" | "volatile") -> ignore (next ()); go ()
    | Lexer.Id
        (("void" | "char" | "short" | "int" | "long" | "unsigned" | "signed")
         as w) ->
        ignore (next ()); words := w :: !words; go ()
    | Lexer.Id "struct" -> ignore (next ()); t := Some (struct_type ()); go ()
    | Lexer.Id "enum" -> ignore (next ()); t := Some (enum_type ()); go ()
    | Lexer.Id x when !words = [] && !t = None && Hashtbl.mem typedefs x ->
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
    | None ->
        if List.mem "void" w then Types.Void else Types.Int (width, signed) in
  !storage, t

and struct_type () =
  let tag =
    match peek () with
    | Lexer.Id x -> ignore (next ()); x
    | _ -> incr tags; Printf.sprintf ".%d" !tags in
  let s =
    match Hashtbl.find_opt structs tag with
    | Some s -> s
    | None ->
        let s : Types.sdef = { fields = []; ssize = 0; salign = 1 } in
        Hashtbl.replace structs tag s; s in
  if accept "{" then begin
    (* each member at its size's alignment, the whole rounded to 8, as 7c *)
    let off = ref 0 in
    while not (accept "}") do
      let _, bt = base_type () in
      let rec members () =
        let name, t = declarator bt in
        Types.no_vlong t;
        off := Types.round !off (Types.align t);
        s.fields <- s.fields @ [ { fname = name; fty = t; foff = !off } ];
        off := !off + Types.size t;
        s.salign <- max s.salign (Types.align t);
        if accept "," then members ()
      in
      members ();
      expect ";"
    done;
    s.ssize <- Types.round !off 8
  end;
  Types.Struct s

(* enum tag { A, B = 5, C }: its constants numbered from 0, or from the
 * last given; the type an int *)
and enum_type () =
  (match peek () with Lexer.Id _ -> ignore (next ()) | _ -> ());
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
  Types.int_t

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
and declarator_rec () : string * (Types.ty -> Types.ty) * string list =
  let stars = ref 0 in
  while accept "*" do incr stars; ignore (accept "const") done;
  let ptrs t =
    let t = ref t in for _i = 1 to !stars do t := Types.Ptr !t done; !t in
  let name, inner, inner_names =
    if peek () = Lexer.P "("
       && (incr pos; let star = peek () = Lexer.P "*" in decr pos; star)
    then begin
      ignore (next ());
      let r = declarator_rec () in
      expect ")";
      r
    end
    else
      ((match peek () with Lexer.Id x -> ignore (next ()); x | _ -> ""),
       (fun t -> t), []) in
  if accept "(" then begin
    (* the parameters, named or not, an array's as a pointer; ... *)
    let rec params () =
      if accept ")" then [], false
      else if accept "..." then (expect ")"; [], true)
      else begin
        let _, pt = base_type () in
        let pname, pt = declarator pt in
        let pt = match pt with Types.Arr (e, _) -> Types.Ptr e | t -> t in
        (* a , or the ) next: else the list is not closed (old: the
         * comma optional, and on { or at the file's end params called
         * itself on no token taken, until the stack was gone: a
         * segmentation fault) *)
        if not (accept ",") && peek () <> Lexer.P ")" then
          Types.error "expected )";
        let rest, variadic = params () in
        (if pt <> Types.Void || pname <> "" then (pname, pt) :: rest else rest),
        variadic
      end
    in
    let ps, variadic = params () in
    name, (fun t -> inner (Types.Func (ptrs t, List.map snd ps, variadic))),
    (if inner_names <> [] then inner_names else List.map fst ps)
  end
  else begin
    let rec dims () =
      if accept "[" then
        (let n =
           if peek () = Lexer.P "]" then 0 else Int64.to_int (const_expr ()) in
         expect "]";
         n :: dims ())
      else [] in
    let ds = dims () in
    name,
    (fun t ->
      inner (List.fold_right (fun n t -> Types.Arr (t, n)) ds (ptrs t))),
    inner_names
  end

(* expressions, by precedence climbing *)
and expr () =
  let e = assign_expr () in
  if accept "," then (let r = expr () in Tree.mk (Tree.Comma (e, r)) r.t) else e

and assign_expr () =
  let l = cond_expr () in
  match peek () with
  | Lexer.P "=" -> ignore (next ()); Tree.assign Tree.Asg_set l (assign_expr ())
  | Lexer.P op when List.mem_assoc op Tree.asg_ops ->
      ignore (next ());
      Tree.asg_op (List.assoc op Tree.asg_ops) l (assign_expr ())
  | _ -> l

and cond_expr () =
  let c = binary_expr 0 in
  if accept "?" then begin
    let a = Tree.rv (expr ()) in
    expect ":";
    let b = Tree.rv (cond_expr ()) in
    let t =
      if Types.is_int a.t && Types.is_int b.t then Tree.common a.t b.t
      else if Types.is_ptr a.t then a.t
      else b.t in
    Tree.mk (Tree.Cond (Tree.rv c, Tree.conv a t, Tree.conv b t)) t
  end
  else c

and binary_expr min =
  let levels = [ [ "||" ]; [ "&&" ]; [ "|" ]; [ "^" ]; [ "&" ]; [ "=="; "!=" ];
                 [ "<"; ">"; "<="; ">=" ]; [ "<<"; ">>" ]; [ "+"; "-" ];
                 [ "*"; "/"; "%" ] ] in
  let rec loop l =
    match peek () with
    | Lexer.P op -> (
        let rec index i = function
          | [] -> None
          | l :: r -> if List.mem op l then Some i else index (i + 1) r in
        match index 0 levels with
        | Some lv when lv >= min ->
            ignore (next ());
            let r = binary_expr (lv + 1) in
            loop (match op with
                  | "&&" -> Tree.both l r
                  | "||" -> Tree.either l r
                  | op -> Tree.binary (List.assoc op Tree.binops) l r)
        | _ -> l)
    | _ -> l
  in
  loop (unary ())

and unary () =
  match peek () with
  | Lexer.P "-" ->
      ignore (next ());
      let e = Tree.rv (unary ()) in
      let t = Tree.promote e.t in
      Tree.un Tree.Neg (Tree.conv e t) t
  | Lexer.P "+" ->
      ignore (next ());
      let e = Tree.rv (unary ()) in
      Tree.conv e (Tree.promote e.t)
  | Lexer.P "~" ->
      ignore (next ());
      let e = Tree.rv (unary ()) in
      let t = Tree.promote e.t in
      Tree.un Tree.Com (Tree.conv e t) t
  | Lexer.P "!" -> ignore (next ()); Tree.lnot (unary ())
  | Lexer.P "*" -> ignore (next ()); Tree.deref (unary ())
  | Lexer.P "&" -> ignore (next ()); Tree.addr (unary ())
  | Lexer.P (("++" | "--") as op) ->
      ignore (next ());
      Tree.asg_op (if op = "++" then Tree.Add else Tree.Sub) (unary ())
        (Tree.num Int64.one Types.int_t)
  | Lexer.Id "sizeof" ->
      ignore (next ());
      let t = if paren_type () then type_name () else (unary ()).t in
      Tree.num (Int64.of_int (Types.size t)) (Types.Int (4, false))
  | Lexer.P "(" when paren_type () ->
      let t = type_name () in
      Tree.conv (Tree.rv (unary ())) t
  | _ -> postfix (primary ())

(* ( type ...: a cast, or sizeof's type *)
and paren_type () =
  peek () = Lexer.P "(" && (incr pos; let ty = is_type () in decr pos; ty)

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
    let a = Tree.rv (assign_expr ()) in
    if accept "," then a :: go () else (expect ")"; [ a ]) in
  let args = if accept ")" then [] else go () in
  List.mapi (fun i (a : Tree.expr) ->
    match List.nth_opt ps i with
    | Some t -> Tree.conv a t
    | None -> Tree.conv a (Tree.promote a.t)) args

and postfix e =
  match peek () with
  | Lexer.P "(" ->
      (* a call through a function's address: a pointer, or ( *f ) *)
      ignore (next ());
      let f = Tree.rv e in
      let rt, ps =
        match f.t with
        | Types.Ptr (Types.Func (r, p, _)) -> r, p
        | _ -> Types.error "not a function" in
      postfix (Tree.mk (Tree.ApplyPtr (f, call_args ps)) rt)
  | Lexer.P "[" ->
      ignore (next ());
      let i = expr () in
      expect "]"; postfix (Tree.deref (Tree.binary (Tree.A Tree.Add) e i))
  | Lexer.P "." -> ignore (next ()); postfix (member e (ident ()))
  | Lexer.P "->" -> ignore (next ()); postfix (member (Tree.deref e) (ident ()))
  | Lexer.P (("++" | "--") as op) ->
      ignore (next ());
      (* x++ is (x += 1) - 1, and so on *)
      let o, back =
        if op = "++" then Tree.Add, Tree.Sub else Tree.Sub, Tree.Add in
      let one () = Tree.num Int64.one Types.int_t in
      postfix
        (Tree.conv
           (Tree.binary (Tree.A back) (Tree.asg_op o e (one ())) (one ())) e.t)
  | _ -> e

and member (e : Tree.expr) f =
  match e.t with
  | Types.Struct s -> (
      match List.find_opt (fun (m : Types.field) -> m.fname = f) s.fields with
      | Some { fty = t; foff = off; _ } ->
          let w = Types.vlong_t in
          let at =
            Tree.Bin (Tree.A Tree.Add, Tree.conv (Tree.addr e) w,
                      Tree.num (Int64.of_int off) w) in
          Tree.mk (Tree.Deref (Tree.mk at (Types.Ptr t))) t
      | None -> Types.error ("no member " ^ f))
  | _ -> Types.error "not a structure"

and primary () =
  match next () with
  | Lexer.Num (v, u, ll) ->
      (* C's rule, shortened: the first of int, long long that holds the
       * value (unsigned ones with a u), an int being 4 bytes *)
      let max = if u then Types.uint_max else Types.int_max in
      let bytes = if ll || Int64.compare v max > 0 then 8 else 4 in
      Tree.num v (Types.Int (bytes, not u))
  | Lexer.Str s -> string_lit s
  | Lexer.P "(" -> let e = expr () in expect ")"; e
  | Lexer.Id f when peek () = Lexer.P "("
              && (match (try Some (lookup f) with Error _ -> None) with
                  | Some { vty = Types.Func _; _ } | None -> true
                  | _ -> false) ->
      ignore (next ());
      let rt, ps, sym =
        match (try Some (lookup f) with Error _ -> None) with
        | Some { vty = Types.Func (r, p, _); where = Tree.Global s } -> r, p, s
        | _ -> Types.int_t, [], f in
      Tree.mk (Tree.Apply (sym, call_args ps)) rt
  | Lexer.Id x when Hashtbl.mem enums x
              && not (List.exists (fun s -> Hashtbl.mem s x) !scopes
                      || Hashtbl.mem globals x) ->
      Tree.num (Hashtbl.find enums x) Types.int_t
  | Lexer.Id x -> let v = lookup x in Tree.var v.where v.vty
  | _ -> Types.error "expected an expression"

(* a constant expression: an array's size, a case, an enum's value
 * (NDIRECT + 1, sizeof a / sizeof a[0]), folded by the tree as it was
 * built (old: folded here, in 64 bits, an operator at a time) *)
and const_expr () =
  let e = cond_expr () in
  match e.d with
  | Tree.Const v -> v
  | Tree.Bin (Tree.A (Tree.Div | Tree.Mod), _, b) when b.d = Tree.Const Int64.zero ->
      Types.error "division by zero"
  | _ -> Types.error "not a constant"

(* statements *)
let cond () = expect "("; let c = Tree.rv (expr ()) in expect ")"; c

let rec statement () : Tree.stmt =
  match next () with
  | Lexer.P "{" -> block ()
  | Lexer.P ";" -> Tree.Block []
  | Lexer.Id "if" ->
      let c = cond () in
      let a = statement () in
      let b =
        if accept_word "else" then Some (statement ()) else None in
      Tree.If (c, a, b)
  | Lexer.Id "while" ->
      let c = cond () in
      Tree.For (None, Some c, None, statement ())
  | Lexer.Id "do" ->
      let body = statement () in
      if next () <> Lexer.Id "while" then Types.error "expected while";
      let c = cond () in
      expect ";"; Tree.Do (body, c)
  | Lexer.Id "for" ->
      (* an expression, or none, then the token that ends it *)
      let opt close =
        let e = if peek () = Lexer.P close then None else Some (expr ()) in
        expect close; e in
      expect "(";
      let init = opt ";" in
      let c = Option.map Tree.rv (opt ";") in
      let step = opt ")" in
      Tree.For (init, c, step, statement ())
  | Lexer.Id "switch" ->
      let v = Tree.conv (cond ()) Types.vlong_t in
      let tmp = Tree.var (local Types.vlong_t) Types.vlong_t in
      Tree.Switch (tmp, v, statement ())
  | Lexer.Id "case" ->
      let v = const_expr () in
      expect ":";
      Tree.Block [ Tree.Case (Some v); statement () ]
  | Lexer.Id "default" ->
      expect ":"; Tree.Block [ Tree.Case None; statement () ]
  | Lexer.Id "break" -> expect ";"; Tree.Break
  | Lexer.Id "continue" -> expect ";"; Tree.Continue
  | Lexer.Id "return" ->
      if accept ";" then Tree.Return None
      else begin
        let e = Tree.conv (Tree.rv (expr ())) !result in
        expect ";";
        Tree.Return (Some e)
      end
  | _ ->
      decr pos;
      if is_type () then Tree.Block (locals ())
      else (let e = expr () in expect ";"; Tree.Expr e)

and block () =
  scopes := Hashtbl.create 8 :: !scopes;
  let rec go acc =
    if accept "}" then List.rev acc else go (statement () :: acc) in
  let l = go [] in
  scopes := List.tl !scopes;
  Tree.Block l

(* a declaration of locals: their initializations *)
and locals () =
  let storage, bt = base_type () in
  let rec go () =
    let name, t = declarator bt in
    let init =
      if storage = Typedef then (Hashtbl.replace typedefs name t; [])
      else begin
        Types.no_vlong t;
        let p = local t in
        Hashtbl.replace (List.hd !scopes) name { vty = t; where = p };
        if accept "=" then
          [ Tree.Expr
              (Tree.assign Tree.Asg_set (Tree.var p t) (assign_expr ())) ]
        else []
      end
    in
    init @ (if accept "," then go () else [])
  in
  let l = go () in
  expect ";";
  l

(*****************************************************************************)
(* The file: its declarations *)
(*****************************************************************************)

let sym_of storage name : Types.sym =
  if storage = Static then Types.static_sym name else name

(* a global's initializer: its data added to ds, at their offsets; how
 * many elements it has, for an array whose size it gives *)
let rec init_data (name : Types.sym) (ds : (int * Tree.datum) list ref) t off =
  let add off d = ds := (off, d) :: !ds in
  match t, peek () with
  | Types.Arr (e, _), Lexer.P "{" ->
      ignore (next ());
      (* the elements, counted *)
      let rec elems i =
        if accept "}" then i
        else
          (ignore (init_data name ds e (off + (i * Types.size e)));
           ignore (accept ",");
           elems (i + 1)) in
      elems 0
  | Types.Arr (Types.Int (1, _), n), Lexer.Str s ->
      ignore (next ());
      String.iteri (fun i c ->
        add (off + i) (Tree.Value (1, Int64.of_int (Char.code c)))) s;
      max n (String.length s + 1)
  | _ ->
      let e = Tree.rv (assign_expr ()) in
      (match e.d, e.t with
       | Tree.Const v, _ -> add off (Tree.Value (Types.size t, v))
       | Tree.Addr (Tree.Global s), _ -> add off (Tree.Address s)
       | _ -> Types.error (name ^ ": not a constant initializer"));
      1

(* a declaration of the file's: what it defines, in their order *)
let declaration () : Tree.def list =
  defs := [];
  let storage, bt = base_type () in
  let rec go () =
    let name, t, pnames = declarator3 bt in
    if storage <> Typedef then Types.no_vlong t;
    let sym = sym_of storage name in
    match t with
    | Types.Func (rt, ps, _) when storage <> Typedef && peek () = Lexer.P "{" ->
        (* a definition *)
        Hashtbl.replace globals name { vty = t; where = Tree.Global sym };
        ignore (next ());
        scopes := [ Hashtbl.create 8 ];
        List.iteri (fun i (p, pt) ->
          Hashtbl.replace (List.hd !scopes) p
            { vty = pt; where = Tree.Param (4 * i) })
          (List.combine pnames ps);
        frame := 0;
        result := rt;
        let body = block () in
        defs := Tree.Function (sym, Types.round !frame 8, body) :: !defs;
        scopes := []
    | _ ->
        (match storage, t with
         | Typedef, _ -> Hashtbl.replace typedefs name t
         | _, Types.Func _ ->
             Hashtbl.replace globals name { vty = t; where = Tree.Global sym }
         | _ ->
             let ds = ref [] in
             let t =
               if accept "=" then
                 (match t with
                  | Types.Arr (e, 0) -> Types.Arr (e, init_data sym ds t 0)
                  | _ -> ignore (init_data sym ds t 0); t)
               else t in
             Hashtbl.replace globals name { vty = t; where = Tree.Global sym };
             if storage <> Extern then
               defs := Tree.Data (sym, Types.size t, List.rev !ds) :: !defs);
        if accept "," then go () else expect ";"
  in
  if not (accept ";") then go ();
  List.rev !defs
