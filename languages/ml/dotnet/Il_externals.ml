(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Il_externals.mli *)

module S = Signature
module W = Writer
open Il_code

type member = { tok : int; static : bool; into : S.t list; from : S.t list; ret : S.t; ml_ret : S.t }

let prefix = "dotnet:"
let is_dotnet (p : string) : bool = String.length p > 7 && String.sub p 0 7 = prefix

(* a class of .NET's library by its full name: System.Console and
 * System.Security.Cryptography's in their own assemblies, the others
 * in System.Runtime (its facade forwards them, not those) *)
let assembly_of (cls : string) : string =
  let under (ns : string) = String.length cls > String.length ns && String.sub cls 0 (String.length ns) = ns in
  if cls = "System.Console" then "System.Console"
  else if under "System.Security.Cryptography." then "System.Security.Cryptography"
  else "System.Runtime"

let class_ref (c : c) (cls : string) : int =
  memo c ("type " ^ cls) (fun () ->
      let ns, name =
        match String.rindex_opt cls '.' with
        | Some i -> (String.sub cls 0 i, String.sub cls (i + 1) (String.length cls - i - 1))
        | None -> ("", cls) in
      W.type_ref c.w (W.assembly_ref c.w (assembly_of cls)) ns name)

let rec type_of_name (c : c) (loc : int) (n : string) : S.t =
  match String.trim n with
  | "int32" -> S.I4
  | "int64" -> S.I8
  | "float64" -> S.R8
  | "float32" -> S.R4
  | "string" -> S.String
  | "bool" -> S.Bool
  | "char" -> S.Char
  | "uint8" -> S.U1
  | "object" -> S.Object
  | "void" -> S.Void
  | n when String.length n > 2 && String.sub n (String.length n - 2) 2 = "[]" ->
      S.SzArray (type_of_name c loc (String.sub n 0 (String.length n - 2)))
  | n when String.contains n '.' -> S.Class (class_ref c n)
  | n -> refuse loc ("a .NET type an external names: " ^ n) "3b"

(* the ML type's arguments and result *)
let rec arrows (t : Scope.ty) : Scope.ty list * Scope.ty =
  match t with
  | Tarrow (a, b) -> let args, r = arrows b in (a :: args, r)
  | t -> ([], t)

let member (c : c) (loc : int) (p : string) (ty : Scope.ty) : member =
  let bad (what : string) = refuse loc ("an external " ^ p ^ ": " ^ what) "3b" in
  let spec = String.sub p 7 (String.length p - 7) in
  let kind, rest =
    match String.index_opt spec ' ' with
    | Some i -> (String.sub spec 0 i, String.sub spec (i + 1) (String.length spec - i - 1))
    | None -> bad "static or instance, then the member" in
  let is_static = match kind with "static" -> true | "instance" -> false | _ -> bad "static or instance" in
  (* its result's .NET type after ->, when it is not the ML one's *)
  let rest, result =
    match String.index_opt rest '>' with
    | Some i when i > 0 && rest.[i - 1] = '-' ->
        (String.trim (String.sub rest 0 (i - 1)), Some (type_of_name c loc (String.sub rest (i + 1) (String.length rest - i - 1))))
    | _ -> (String.trim rest, None) in
  (* Class::Method, then its parameters' .NET types in parentheses *)
  let path, given =
    match String.index_opt rest '(' with
    | Some i ->
        let inside = String.sub rest (i + 1) (String.length rest - i - 2) in
        (String.sub rest 0 i, Some (if String.trim inside = "" then [] else List.map (type_of_name c loc) (String.split_on_char ',' inside)))
    | None -> (rest, None) in
  let cls, name =
    match String.index_opt path ':' with
    | Some i -> (String.sub path 0 i, String.sub path (i + 2) (String.length path - i - 2))
    | None -> bad "Class::Method" in
  let cls_tok = class_ref c cls in
  let args, res = arrows ty in
  (* the ML arguments' .NET types (unit's none): an instance method's
   * first its this, the others its parameters *)
  let from = List.filter (fun (t : S.t) -> t <> S.Void) (List.map (Il_types.cts c loc) args) in
  (* (a this of an abstract type, an object, cast to the class) *)
  let this, params =
    if is_static then ([], from)
    else (match from with t :: r -> ([ (if t = S.Object then S.Class cls_tok else t) ], r) | [] -> bad "its this") in
  let into = match given with Some ts -> ts | None -> params in
  if List.length into <> List.length params then bad "its parameters and its ML type's arguments";
  let ml_ret = Il_types.cts c loc res in
  let ret = match result with Some t -> t | None -> ml_ret in
  let sg = if is_static then static into ret else instance into ret in
  let tok = memo c ("member " ^ cls ^ "::" ^ name ^ S.encode_method sg) (fun () -> W.member_ref c.w cls_tok name sg) in
  { tok; static = is_static; into = this @ into; from; ret; ml_ret }

let convert (c : c) (k : code) (from : S.t) (into : S.t) : unit =
  match from, into with
  (* (an ML abstract type's value, an object: the class .NET's member
   * wants, checked) *)
  | S.Object, (S.Class _ | S.SzArray _) -> emit k (Il.Castclass (Il_types.type_token c into))
  (* (Obj.magic between two references, lib_core's untyped code: cast,
   * so that it verifies; wrong, it fails where it runs) *)
  | (S.String | S.Class _ | S.GenericInst _ | S.SzArray _), (S.String | S.Class _ | S.GenericInst _ | S.SzArray _ | S.Var _ | S.MVar _)
    when from <> into ->
      (match into with
       | S.Var _ | S.MVar _ -> emit k (Il.Unbox_any (Il_types.type_token c into))
       | _ -> emit k (Il.Castclass (Il_types.type_token c into)))
  | S.I8, S.I4 -> emit k (Il.Conv (Il.K_i4, false, false))
  | S.I4, S.I8 | S.Char, S.I8 -> emit k (Il.Conv (Il.K_i8, false, false))
  | S.I4, S.Char -> emit k (Il.Conv (Il.K_u2, false, false))
  | S.I8, S.Char -> emit k (Il.Conv (Il.K_u2, false, false))
  | S.R8, S.R4 -> emit k (Il.Conv (Il.K_r4, false, false))
  | S.R4, S.R8 -> emit k (Il.Conv (Il.K_r8, false, false))
  | _ -> ()

let is_value (t : S.t) : bool =
  match t with S.I4 | S.I8 | S.R8 | S.Bool | S.Char -> true | _ -> false
