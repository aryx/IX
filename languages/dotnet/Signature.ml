(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Signature.mli *)

type t =
  | Void
  | Bool
  | Char
  | I1 | U1 | I2 | U2 | I4 | U4 | I8 | U8
  | R4 | R8
  | I | U
  | String
  | Object
  | TypedRef
  | Class of int
  | ValueType of int
  | Var of int
  | MVar of int
  | Ptr of t
  | ByRef of t
  | SzArray of t
  | Array of t * int
  | GenericInst of t * t list
  | FnPtr of meth

and meth = {
  has_this : bool;
  generic : int;
  vararg : bool;
  ret : t;
  params : t list;
}

exception Bad of string

let type_token (v : int) : int =
  let row = v lsr 2 in
  match v land 3 with
  | 0 -> Metadata.token Metadata.t_type_def row
  | 1 -> Metadata.token Metadata.t_type_ref row
  | 2 -> Metadata.token Metadata.t_type_spec row
  | _ -> raise (Bad "a TypeDefOrRef's tag 3")

(* a reader: the blob and where it is *)
type r = { s : string; mutable p : int }

let byte (r : r) : int = let b = Char.code r.s.[r.p] in r.p <- r.p + 1; b

let number (r : r) : int =
  let b = byte r in
  if b land 0x80 = 0 then b
  else if b land 0xC0 = 0x80 then ((b land 0x3F) lsl 8) lor byte r
  else
    let b1 = byte r in let b2 = byte r in let b3 = byte r in
    ((b land 0x1F) lsl 24) lor (b1 lsl 16) lor (b2 lsl 8) lor b3

let rec typ (r : r) : t =
  match byte r with
  | 0x01 -> Void
  | 0x02 -> Bool
  | 0x03 -> Char
  | 0x04 -> I1 | 0x05 -> U1 | 0x06 -> I2 | 0x07 -> U2
  | 0x08 -> I4 | 0x09 -> U4 | 0x0A -> I8 | 0x0B -> U8
  | 0x0C -> R4 | 0x0D -> R8
  | 0x0E -> String
  | 0x0F -> Ptr (typ r)
  | 0x10 -> ByRef (typ r)
  | 0x11 -> ValueType (type_token (number r))
  | 0x12 -> Class (type_token (number r))
  | 0x13 -> Var (number r)
  | 0x14 ->
      let elt = typ r in
      let rank = number r in
      (* (the sizes and lower bounds: read past) *)
      let nsizes = number r in
      for _i = 1 to nsizes do ignore (number r) done;
      let nlo = number r in
      for _i = 1 to nlo do ignore (number r) done;
      Array (elt, rank)
  | 0x15 ->
      let g = typ r in
      let n = number r in
      let args = List.init n (fun _ -> typ r) in
      GenericInst (g, args)
  | 0x16 -> TypedRef
  | 0x18 -> I | 0x19 -> U
  | 0x1B -> FnPtr (meth r)
  | 0x1C -> Object
  | 0x1D -> SzArray (typ r)
  | 0x1E -> MVar (number r)
  (* a custom modifier (modreq, modopt), pinned: no meaning for us *)
  | 0x1F | 0x20 -> ignore (number r); typ r
  | 0x45 -> typ r
  | b -> raise (Bad (Printf.sprintf "an element type 0x%x" b))

and meth (r : r) : meth =
  let cc = byte r in
  let generic = if cc land 0x10 <> 0 then number r else 0 in
  let n = number r in
  let ret = typ r in
  let params = List.init n (fun _ -> typ r) in
  (* (a vararg call's sentinel, 0x41, before the extra arguments: none
   * in our programs) *)
  { has_this = cc land 0x20 <> 0; generic; vararg = cc land 0xF = 5; ret; params }

let reader (s : string) : r = { s; p = 0 }

let field (s : string) : t =
  let r = reader s in
  if byte r <> 0x06 then raise (Bad "not a field's signature");
  typ r

let method_ (s : string) : meth = meth (reader s)

let locals (s : string) : t list =
  let r = reader s in
  if byte r <> 0x07 then raise (Bad "not the locals' signature");
  let n = number r in
  List.init n (fun _ -> typ r)

let type_spec (s : string) : t = typ (reader s)

let method_spec (s : string) : t list =
  let r = reader s in
  if byte r <> 0x0A then raise (Bad "not a generic method's instantiation");
  let n = number r in
  List.init n (fun _ -> typ r)

let property (s : string) : t =
  let r = reader s in
  ignore (byte r);
  ignore (number r);
  typ r

let rec show (name : int -> string) (t : t) : string =
  match t with
  | Void -> "void" | Bool -> "bool" | Char -> "char"
  | I1 -> "int8" | U1 -> "uint8" | I2 -> "int16" | U2 -> "uint16"
  | I4 -> "int32" | U4 -> "uint32" | I8 -> "int64" | U8 -> "uint64"
  | R4 -> "float32" | R8 -> "float64"
  | I -> "native int" | U -> "native uint"
  | String -> "string" | Object -> "object" | TypedRef -> "typedref"
  | Class tok -> "class " ^ name tok
  | ValueType tok -> "valuetype " ^ name tok
  | Var n -> "!" ^ string_of_int n
  | MVar n -> "!!" ^ string_of_int n
  | Ptr t -> show name t ^ "*"
  | ByRef t -> show name t ^ "&"
  | SzArray t -> show name t ^ "[]"
  | Array (t, rank) -> show name t ^ "[" ^ String.make (rank - 1) ',' ^ "]"
  | GenericInst (g, args) ->
      show name g ^ "<" ^ String.concat ", " (List.map (show name) args) ^ ">"
  | FnPtr m -> "method " ^ show_meth name "*" m

and show_meth (name : int -> string) (what : string) (m : meth) : string =
  (if m.has_this then "instance " else "")
  ^ show name m.ret ^ " " ^ what
  ^ (if m.generic > 0 then "<" ^ String.concat ", " (List.init m.generic (fun i -> "!!" ^ string_of_int i)) ^ ">" else "")
  ^ "(" ^ String.concat ", " (List.map (show name) m.params) ^ ")"
