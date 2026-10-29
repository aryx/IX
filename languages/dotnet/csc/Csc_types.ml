(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Csc_types.mli *)

module A = Csc_ast

exception Error of string * int

let error (pos : int) (msg : string) = raise (Error (msg, pos))

type ty =
  | Void | Bool | Char | Int | Long | Double | String | Object | Null
  | Class of cls * ty list
  | Array of ty
  | Var of int                       (* a library class's type parameter *)
  | MVar of int                      (* a library method's *)
  | Ref of ty                        (* out, ref: an address *)

and cls = {
  name : string;
  short : string;
  kind : kind;
  user : A.class_decl option;
  spec : Library.spec option;
  mutable parent : ty option;
  mutable ifaces : ty list;
  mutable fields : field list;
  mutable methods : meth list;
  mutable token : int;               (* the writer's: a TypeDef, a TypeRef *)
}

and kind = K_class | K_interface | K_struct

and field = {
  fname : string;
  ftype : ty;
  fstatic : bool;
  fowner : cls;
  finit : A.expr option;
  mutable ftoken : int;
}

and meth = {
  mname : string;
  mowner : cls;
  mstatic : bool;
  mvirtual : bool;                   (* virtual, abstract, override, or an interface's *)
  mabstract : bool;
  moverride : bool;
  mparams : ty list;                 (* as declared: Var for a library class's T *)
  pnames : string list;
  mret : ty;
  mgeneric : int;
  body : A.stmt option;
  init : (bool * A.expr list) option;    (* a constructor's base(...) or this(...) *)
  mutable mtoken : int;
  mutable implements : bool;         (* a class's method an interface asks: virtual final *)
}

(* the classes by name: the program's, the library's when first named *)
let classes : (string, cls) Hashtbl.t = Hashtbl.create 64
let usings : string list ref = ref [ "System" ]

let rec show (t : ty) : string =
  match t with
  | Void -> "void" | Bool -> "bool" | Char -> "char" | Int -> "int" | Long -> "long"
  | Double -> "double" | String -> "string" | Object -> "object" | Null -> "null"
  | Class (c, []) -> c.short
  | Class (c, args) ->
      (match String.index_opt c.short '`' with Some i -> String.sub c.short 0 i | None -> c.short)
      ^ "<" ^ String.concat ", " (List.map show args) ^ ">"
  | Array t -> show t ^ "[]"
  | Var n -> "!" ^ string_of_int n
  | MVar n -> "!!" ^ string_of_int n
  | Ref t -> "ref " ^ show t

let is_value (t : ty) : bool =
  match t with
  | Bool | Char | Int | Long | Double -> true
  | Class (c, _) -> c.kind = K_struct
  | _ -> false

(* the library's keys of the primitives *)
let primitives = [
  "System.Boolean", Bool; "System.Char", Char; "System.Int32", Int; "System.Int64", Long;
  "System.Double", Double; "System.String", String; "System.Object", Object; "System.Void", Void;
]

let short_of (name : string) : string =
  let cut c s = match String.rindex_opt s c with
    | Some i -> String.sub s (i + 1) (String.length s - i - 1) | None -> s in
  cut '+' (cut '.' name)

(* ------------------------------------------------------------------ *)
(* The library's classes, from Library's descriptions *)
(* ------------------------------------------------------------------ *)

let rec lib_class (name : string) : cls option =
  match Hashtbl.find_opt classes name with
  | Some c -> Some c
  | None ->
      match Hashtbl.find_opt Library.specs name with
      | None -> None
      | Some sp ->
          let kind = match sp.skind with
            | Value.Interface -> K_interface | Value.Struct | Value.Enum -> K_struct
            | _ -> K_class in
          let c = { name; short = short_of name; kind; user = None; spec = Some sp;
                    parent = None; ifaces = []; fields = []; methods = []; token = 0 } in
          Hashtbl.replace classes name c;
          if sp.sparent <> "" then c.parent <- Some (parse sp.sparent);
          c.ifaces <- List.map parse sp.sinterfaces;
          c.methods <- List.map (fun (sm : Library.smeth) ->
              { mname = sm.mn; mowner = c; mstatic = sm.mstatic;
                mvirtual = sm.mvirt; mabstract = sm.impl = Library.Abstract; moverride = false;
                mparams = List.map parse sm.mparams; pnames = []; mret = parse sm.mret;
                mgeneric = sm.mgeneric; body = None; init = None; mtoken = 0; implements = false })
              sp.smethods;
          Some c

(* a key of the library's ("System.Int32", "!0", "List`1+Enumerator<!0>") *)
and parse (s : string) : ty =
  let n = String.length s in
  let pos = ref 0 in
  let rec typ () =
    let base =
      if s.[!pos] = '!' then begin
        let mvar = !pos + 1 < n && s.[!pos + 1] = '!' in
        pos := !pos + (if mvar then 2 else 1);
        let start = !pos in
        while !pos < n && s.[!pos] >= '0' && s.[!pos] <= '9' do incr pos done;
        let k = int_of_string (String.sub s start (!pos - start)) in
        if mvar then MVar k else Var k
      end else begin
        let start = !pos in
        while !pos < n && not (List.mem s.[!pos] [ '<'; '>'; ','; '['; '&'; '*' ]) do incr pos done;
        let name = String.sub s start (!pos - start) in
        let args =
          if !pos < n && s.[!pos] = '<' then begin
            incr pos;
            let rec go acc =
              let t = typ () in
              if s.[!pos] = ',' then (incr pos; go (t :: acc)) else (incr pos; List.rev (t :: acc)) in
            go []
          end else [] in
        match List.assoc_opt name primitives with
        | Some t -> t
        | None -> match lib_class name with
          | Some c -> Class (c, args)
          | None -> Object      (* (a type the library names but has not: IntPtr...) *)
      end in
    let rec suffix t =
      if !pos + 1 < n && s.[!pos] = '[' && s.[!pos + 1] = ']' then (pos := !pos + 2; suffix (Array t))
      else if !pos < n && s.[!pos] = '&' then (incr pos; suffix (Ref t))
      else if !pos < n && s.[!pos] = '*' then (incr pos; suffix t)
      else t in
    suffix base in
  typ ()

let rec subst (args : ty list) (margs : ty list) (t : ty) : ty =
  match t with
  | Var k when k < List.length args -> List.nth args k
  | MVar k when k < List.length margs -> List.nth margs k
  | Array e -> Array (subst args margs e)
  | Ref e -> Ref (subst args margs e)
  | Class (c, l) -> Class (c, List.map (subst args margs) l)
  | t -> t

(* ------------------------------------------------------------------ *)
(* Names to types *)
(* ------------------------------------------------------------------ *)

let find_class (pos : int) (names : string list) (nargs : int) : cls =
  let n = String.concat "." names in
  let n = if nargs > 0 then n ^ "`" ^ string_of_int nargs else n in
  let candidates = n :: List.map (fun u -> u ^ "." ^ n) !usings in
  let rec go l = match l with
    | [] -> error pos ("no type " ^ n)
    | x :: rest ->
        match Hashtbl.find_opt classes x with
        | Some c -> c
        | None -> match lib_class x with Some c -> c | None -> go rest in
  go candidates

let rec resolve (pos : int) (t : A.ty) : ty =
  match t with
  | A.Array e -> Array (resolve pos e)
  | A.Byref e -> Ref (resolve pos e)
  | A.Named ([ "int" ], []) -> Int
  | A.Named ([ "bool" ], []) -> Bool
  | A.Named ([ "char" ], []) -> Char
  | A.Named ([ "long" ], []) -> Long
  | A.Named ([ "double" ], []) -> Double
  | A.Named ([ "string" ], []) -> String
  | A.Named ([ "object" ], []) -> Object
  | A.Named ([ "void" ], []) -> Void
  | A.Named (names, args) ->
      let c = find_class pos names (List.length args) in
      (match List.assoc_opt c.name primitives with
       | Some t -> t
       | None -> Class (c, List.map (resolve pos) args))

(* the class of a type, for its members: int's System.Int32 *)
let class_of (t : ty) : (cls * ty list) option =
  match t with
  | Class (c, args) -> Some (c, args)
  | Int -> Option.map (fun c -> (c, [])) (lib_class "System.Int32")
  | Bool -> Option.map (fun c -> (c, [])) (lib_class "System.Boolean")
  | Char -> Option.map (fun c -> (c, [])) (lib_class "System.Char")
  | Long -> Option.map (fun c -> (c, [])) (lib_class "System.Int64")
  | Double -> Option.map (fun c -> (c, [])) (lib_class "System.Double")
  | String -> Option.map (fun c -> (c, [])) (lib_class "System.String")
  | Object | Null -> Option.map (fun c -> (c, [])) (lib_class "System.Object")
  | Array _ -> Option.map (fun c -> (c, [])) (lib_class "System.Array")
  | _ -> None

let parent_of (c : cls) : (cls * ty list) option =
  match c.parent with Some t -> class_of t | None -> None

(* ------------------------------------------------------------------ *)
(* Conversions and overloads *)
(* ------------------------------------------------------------------ *)

let rec same (a : ty) (b : ty) : bool =
  match a, b with
  | Class (c, x), Class (d, y) -> c == d && List.length x = List.length y && List.for_all2 same x y
  | Array x, Array y | Ref x, Ref y -> same x y
  | _ -> a = b

let rec derives (c : cls) (d : cls) : bool =
  c == d
  || List.exists (fun i -> match i with Class (k, _) -> derives k d | _ -> false) c.ifaces
  || (match parent_of c with Some (p, _) -> derives p d | None -> false)

(* an implicit conversion (C#'s 6.1), and what it costs: None if there
 * is none, 0 if the types are the same *)
let convertible (from : ty) (to_ : ty) : int option =
  if same from to_ then Some 0
  else match from, to_ with
    | Null, (String | Object | Class _ | Array _) when not (is_value to_) -> Some 1
    | (Int | Char), Long | (Int | Char | Long), Double | Char, Int -> Some 1
    | _, Object -> Some 2
    | Class (c, _), Class (d, _) when derives c d -> Some 1
    | String, Class (d, _) -> (match lib_class "System.String" with Some c when derives c d -> Some 1 | _ -> None)
    | Array _, Class (d, _) when d.name = "System.Array" -> Some 1
    | _ -> None

(* the best of the methods for these arguments: the one whose
 * conversions cost least, the first of those that cost the same *)
let best (pos : int) (what : string) (cands : (meth * ty list) list) (args : ty list) : meth * ty list =
  let scored = List.filter_map (fun (m, ps) ->
      if List.length ps <> List.length args then None
      else
        let costs = List.map2 convertible args ps in
        if List.for_all (fun c -> c <> None) costs then
          Some ((m, ps), List.fold_left (fun a c -> a + Option.get c) 0 costs)
        else None) cands in
  match List.sort (fun (_, a) (_, b) -> compare a b) scored with
  | (x, _) :: _ -> x
  | [] ->
      error pos (Printf.sprintf "no %s for (%s)%s" what (String.concat ", " (List.map show args))
                   (if cands = [] then "" else Printf.sprintf ": %d of that name" (List.length cands)))

(* the methods of a name in a class and its parents, their parameters
 * instantiated; a method overridden is found once, the most derived *)
let methods (t : ty) (name : string) : (meth * ty list) list =
  let rec go (c : cls) (args : ty list) (acc : (meth * ty list) list) =
    let own = List.filter (fun m -> m.mname = name) c.methods in
    let own = List.map (fun m -> (m, List.map (subst args []) m.mparams)) own in
    let fresh = List.filter (fun (m, ps) ->
        not (List.exists (fun ((n : meth), qs) -> n.mstatic = m.mstatic
                                                 && List.length ps = List.length qs
                                                 && List.for_all2 same ps qs) acc)) own in
    let acc = acc @ fresh in
    let acc = List.fold_left (fun acc i -> match i with
        | Class (k, a) when c.kind = K_interface -> go k a acc | _ -> acc) acc c.ifaces in
    match parent_of c with
    | Some (p, a) when name <> ".ctor" -> go p a acc
    | _ -> acc in
  match class_of t with
  | Some (c, args) -> go c args []
  | None -> []

let field (t : ty) (name : string) : field option =
  let rec go (c : cls) =
    match List.find_opt (fun f -> f.fname = name) c.fields with
    | Some f -> Some f
    | None -> match parent_of c with Some (p, _) -> go p | None -> None in
  match class_of t with Some (c, _) -> go c | None -> None
