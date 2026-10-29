(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Value.mli *)

type typ =
  | T_void | T_bool | T_char
  | T_i1 | T_u1 | T_i2 | T_u2 | T_i4 | T_u4 | T_i8 | T_u8
  | T_r4 | T_r8 | T_i | T_u
  | T_class of cls
  | T_value of cls
  | T_array of typ
  | T_byref of typ
  | T_ptr of typ
  | T_var of int
  | T_mvar of int

and cls = {
  name : string;
  short : string;
  kind : kind;
  args : typ array;
  mutable parent : cls option;
  mutable interfaces : cls list;
  mutable fields : field list;
  mutable methods : meth list;
  mutable vtable : meth array;
  mutable nbytes : int;
  mutable nrefs : int;
  mutable statics : store option;
  mutable init : init;
  mutable element : typ option;
  imap : (string, meth) Hashtbl.t;
  origin : origin;
}

and kind = Class | Interface | Struct | Enum | Delegate

and init = Not_run | Running | Done

and origin =
  | From of image * int
  | Builtin

and field = {
  fname : string;
  fcls : cls;
  ftype : typ;
  fstatic : bool;
  mutable off : int;
  mutable roff : int;
}

and meth = {
  mname : string;
  mcls : cls;
  static : bool;
  virt : bool;
  abstract : bool;
  newslot : bool;
  params : typ list;
  ret : typ;
  generic : int;
  margs : typ array;
  key : string;
  mutable slot : int;
  mutable body : body;
  def : (image * int) option;
  cache : (int, resolved) Hashtbl.t;
}

and body =
  | Il_body of int
  | Decoded of code
  | Native of (value array -> value)
  | Runtime
  | No_body

and code = {
  instrs : Il.instr array;
  clauses : clause array;
  locals : typ array;
  max_stack : int;
}

and clause = {
  ckind : int;
  tstart : int; tend : int;
  hstart : int; hend : int;
  catch : cls option;
  filter : int;
}

and resolved =
  | R_type of typ
  | R_field of field
  | R_meth of meth
  | R_string of value

and store = {
  cls : cls;
  s : Bytes.t;
  r : value array;
  len : int;
  mutable native : native;
}

and native =
  | No_native
  | N_list of vec
  | N_dict of dict
  | N_buffer of Buffer.t
  | N_type of typ
  | N_delegate of value * meth
  | N_message of string

and vec = { mutable items : value array; mutable count : int }

and dict = {
  index : (int, int) Hashtbl.t;
  mutable keys : value array;
  mutable vals : value array;
  mutable used : int;
}

and value =
  | Null
  | I4 of int32
  | I8 of int64
  | R8 of float
  | Obj of store
  | Str of string
  | Vt of store
  | Ptr of place
  | Fn of meth
  | Handle of typ
  | Data of string * int

and place =
  | Slot of value array * int
  | Bytes of store * int * typ
  | Inside of store * int * int * cls

and image = {
  img : Image.t;
  aname : string;
  types : (int, cls) Hashtbl.t;
  strings : (int, value) Hashtbl.t;
}

exception Thrown of store

let scalar_size (t : typ) : int =
  match t with
  | T_bool | T_i1 | T_u1 -> 1
  | T_char | T_i2 | T_u2 -> 2
  | T_i4 | T_u4 | T_r4 | T_i | T_u -> 4
  | T_i8 | T_u8 | T_r8 -> 8
  | _ -> 0

let is_ref (t : typ) : bool =
  match t with
  | T_class _ | T_array _ | T_byref _ | T_ptr _ -> true
  | _ -> false

let rec typ_key (t : typ) : string =
  match t with
  | T_void -> "System.Void" | T_bool -> "System.Boolean" | T_char -> "System.Char"
  | T_i1 -> "System.SByte" | T_u1 -> "System.Byte"
  | T_i2 -> "System.Int16" | T_u2 -> "System.UInt16"
  | T_i4 -> "System.Int32" | T_u4 -> "System.UInt32"
  | T_i8 -> "System.Int64" | T_u8 -> "System.UInt64"
  | T_r4 -> "System.Single" | T_r8 -> "System.Double"
  | T_i -> "System.IntPtr" | T_u -> "System.UIntPtr"
  | T_class c | T_value c -> c.name
  | T_array e -> typ_key e ^ "[]"
  | T_byref e -> typ_key e ^ "&"
  | T_ptr e -> typ_key e ^ "*"
  | T_var n -> "!" ^ string_of_int n
  | T_mvar n -> "!!" ^ string_of_int n

let meth_key (name : string) (params : typ list) (ret : typ) : string =
  name ^ "(" ^ String.concat "," (List.map typ_key params) ^ ")" ^ typ_key ret

let load (b : Bytes.t) (at : int) (t : typ) : value =
  match t with
  | T_bool | T_u1 -> I4 (Int32.of_int (Bytes.get_uint8 b at))
  | T_i1 -> I4 (Int32.of_int (Bytes.get_int8 b at))
  | T_char | T_u2 -> I4 (Int32.of_int (Bytes.get_uint16_le b at))
  | T_i2 -> let n = Bytes.get_uint16_le b at in I4 (Int32.of_int (if n >= 0x8000 then n - 0x10000 else n))
  | T_i4 | T_u4 | T_i | T_u -> I4 (Bytes.get_int32_le b at)
  | T_i8 | T_u8 -> I8 (Bytes.get_int64_le b at)
  | T_r4 -> R8 (Int32.float_of_bits (Bytes.get_int32_le b at))
  | T_r8 -> R8 (Int64.float_of_bits (Bytes.get_int64_le b at))
  | _ -> invalid_arg "Value.load: not a number"

let to_i32 (v : value) : int32 =
  match v with
  | I4 n -> n
  | I8 n -> Int64.to_int32 n
  | R8 f -> Int32.of_float f
  | _ -> invalid_arg "Value.store_at: not a number"

let store_at (b : Bytes.t) (at : int) (t : typ) (v : value) : unit =
  match t with
  | T_bool | T_u1 | T_i1 -> Bytes.set_uint8 b at (Int32.to_int (to_i32 v) land 0xFF)
  | T_char | T_u2 | T_i2 -> Bytes.set_uint16_le b at (Int32.to_int (to_i32 v) land 0xFFFF)
  | T_i4 | T_u4 | T_i | T_u -> Bytes.set_int32_le b at (to_i32 v)
  | T_i8 | T_u8 ->
      Bytes.set_int64_le b at (match v with I8 n -> n | I4 n -> Int64.of_int32 n
                                           | R8 f -> Int64.of_float f
                                           | _ -> invalid_arg "Value.store_at: not a number")
  | T_r4 ->
      Bytes.set_int32_le b at (Int32.bits_of_float (match v with R8 f -> f | _ -> invalid_arg "Value.store_at: not a float"))
  | T_r8 ->
      Bytes.set_int64_le b at (Int64.bits_of_float (match v with R8 f -> f | _ -> invalid_arg "Value.store_at: not a float"))
  | _ -> invalid_arg "Value.store_at: not a number"

(* an element's or a field's room: (bytes, references) *)
let footprint (t : typ) : int * int =
  match t with
  | T_value c -> (c.nbytes, c.nrefs)
  | t when is_ref t -> (0, 1)
  | t -> (scalar_size t, 0)

let make_store (c : cls) (n : int) : store =
  match c.element with
  | Some e ->
      let b, r = footprint e in
      { cls = c; s = Bytes.make (b * n) '\000'; r = Array.make (r * n) Null; len = n; native = No_native }
  | None ->
      { cls = c; s = Bytes.make c.nbytes '\000'; r = Array.make c.nrefs Null; len = 0; native = No_native }

let copy (st : store) : store =
  { st with s = Bytes.copy st.s; r = Array.copy st.r }

let zero (t : typ) : value =
  match t with
  | T_i8 | T_u8 -> I8 Int64.zero
  | T_r4 | T_r8 -> R8 0.0
  | T_value c -> Vt (make_store c 0)
  | t when is_ref t -> Null
  | T_class _ | T_array _ | T_byref _ | T_ptr _ | T_var _ | T_mvar _ | T_void -> Null
  | _ -> I4 Int32.zero

let rec subclass (c : cls) (d : cls) : bool =
  c == d
  || List.exists (fun i -> subclass i d) c.interfaces
  || (match c.parent with Some p -> subclass p d | None -> false)
