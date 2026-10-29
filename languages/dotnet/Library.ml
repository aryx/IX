(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Library.mli *)

open Value

type impl =
  | Impl of (value array -> value)
  | By_runtime
  | Abstract

type smeth = {
  mn : string;
  mstatic : bool;
  mvirt : bool;
  mparams : string list;
  mret : string;
  mgeneric : int;
  impl : impl;
}

type spec = {
  sname : string;
  sparent : string;
  skind : kind;
  sgeneric : int;
  sinterfaces : string list;
  sfields : (string * string) list;
  smethods : smeth list;
}

type hooks = {
  mutable out : string -> unit;
  mutable read : unit -> int;
  mutable to_string : value -> string;
  mutable equals : value -> value -> bool;
  mutable hash : value -> int;
  mutable throw : string -> string -> value;
  mutable instance : string -> typ array -> cls;
}

let hooks = {
  out = (fun _ -> ());
  read = (fun () -> -1);
  to_string = (fun _ -> failwith "Library.hooks: no machine");
  equals = (fun _ _ -> failwith "Library.hooks: no machine");
  hash = (fun _ -> failwith "Library.hooks: no machine");
  throw = (fun _ _ -> failwith "Library.hooks: no machine");
  instance = (fun _ _ -> failwith "Library.hooks: no machine");
}

(* the keys of the types the members name *)
let void = "System.Void"
let int = "System.Int32"
let long = "System.Int64"
let double = "System.Double"
let bool = "System.Boolean"
let char = "System.Char"
let string = "System.String"
let obj = "System.Object"

(* the members, by kind *)
let inst mn mparams mret f =
  { mn; mstatic = false; mvirt = false; mparams; mret; mgeneric = 0; impl = Impl f }
let stat mn mparams mret f =
  { mn; mstatic = true; mvirt = false; mparams; mret; mgeneric = 0; impl = Impl f }
let virt mn mparams mret f =
  { mn; mstatic = false; mvirt = true; mparams; mret; mgeneric = 0; impl = Impl f }

(* a class: its name and members after what differs from [d]'s, a
 * class of Object's: spec { d with skind = Struct } "System.Foo" [...] *)
let d = { sname = ""; sparent = obj; skind = Class; sgeneric = 0; sinterfaces = [];
          sfields = []; smethods = [] }
let spec (h : spec) (sname : string) (smethods : smeth list) : spec = { h with sname; smethods }

(* ------------------------------------------------------------------ *)
(* The values *)
(* ------------------------------------------------------------------ *)

let i4 (n : int) : value = I4 (Int32.of_int n)
let bool_v (b : bool) : value = I4 (if b then Int32.one else Int32.zero)

let to_int (v : value) : int =
  match v with
  | I4 n -> Int32.to_int n
  | I8 n -> Int64.to_int n
  | _ -> invalid_arg "Library: not an integer"

let to_str (v : value) : string =
  match v with
  | Str s -> s
  | Null -> ignore (hooks.throw "System.NullReferenceException" "Object reference not set to an instance of an object."); ""
  | _ -> invalid_arg "Library: not a string"

(* the object a reference or `this` points to: its store, and where in
 * it (a struct's `this` is a pointer, maybe into another object) *)
let view (v : value) : store * int * int =
  match v with
  | Obj st | Vt st -> (st, 0, 0)
  | Ptr (Slot (a, i)) -> (match a.(i) with Vt st | Obj st -> (st, 0, 0)
                                           | _ -> invalid_arg "Library.view: not a struct")
  | Ptr (Inside (st, so, ro, _)) -> (st, so, ro)
  | Null -> ignore (hooks.throw "System.NullReferenceException" "Object reference not set to an instance of an object."); invalid_arg "null"
  | _ -> invalid_arg "Library.view: not an object"

(* a primitive's value from `this`: a pointer to it, or its box *)
let number (v : value) : value =
  match v with
  | I4 _ | I8 _ | R8 _ -> v
  | Ptr (Slot (a, i)) -> a.(i)
  | Ptr (Bytes (st, off, t)) -> load st.s off t
  | Ptr (Inside (st, so, _, c)) -> let f = List.hd c.fields in load st.s (so + f.off) f.ftype
  | Obj st -> let f = List.hd st.cls.fields in load st.s f.off f.ftype
  | _ -> invalid_arg "Library.number"

let field_of (c : cls) (name : string) : field =
  let rec go (c : cls) =
    match List.find_opt (fun (f : field) -> f.fname = name && not f.fstatic) c.fields with
    | Some f -> f
    | None -> (match c.parent with Some p -> go p | None -> invalid_arg ("Library: no field " ^ name)) in
  go c

(* a field of a library object by its name: a reference's or a number's *)
let get (v : value) (name : string) : value =
  let st, so, ro = view v in
  let c = match v with Ptr (Inside (_, _, _, c)) -> c | _ -> st.cls in
  let f = field_of c name in
  if is_ref f.ftype then st.r.(ro + f.roff) else load st.s (so + f.off) f.ftype

let set (v : value) (name : string) (x : value) : unit =
  let st, so, ro = view v in
  let c = match v with Ptr (Inside (_, _, _, c)) -> c | _ -> st.cls in
  let f = field_of c name in
  if is_ref f.ftype then st.r.(ro + f.roff) <- x else store_at st.s (so + f.off) f.ftype x


(* ------------------------------------------------------------------ *)
(* Numbers as text *)
(* ------------------------------------------------------------------ *)

(* .NET Core 3.0's double.ToString(): the shortest digits that read
 * back the same, written plainly from 1E-05 to 1E+15, else with E *)
let format_double (f : float) : string =
  if Float.is_nan f then "NaN"
  else if f = infinity then "\xe2\x88\x9e"
  else if f = neg_infinity then "-\xe2\x88\x9e"
  else if f = 0.0 then (if 1.0 /. f < 0.0 then "-0" else "0")
  else begin
    (* the shortest %e that reads back *)
    let rec shortest p =
      let s = Printf.sprintf "%.*e" p f in
      if p >= 16 || float_of_string s = f then s else shortest (p + 1) in
    let s = shortest 0 in
    let neg = s.[0] = '-' in
    let s = if neg then String.sub s 1 (String.length s - 1) else s in
    let e = String.index s 'e' in
    let mant = String.sub s 0 e in
    let exp = int_of_string (String.sub s (e + 1) (String.length s - e - 1)) in
    let digits = String.concat "" (String.split_on_char '.' mant) in
    let n = String.length digits in
    let body =
      if exp >= 15 || exp < -5 then
        (if n = 1 then digits else String.sub digits 0 1 ^ "." ^ String.sub digits 1 (n - 1))
        ^ "E" ^ (if exp < 0 then "-" else "+") ^ Printf.sprintf "%02d" (abs exp)
      else if exp < 0 then "0." ^ String.make (- exp - 1) '0' ^ digits
      else if n <= exp + 1 then digits ^ String.make (exp + 1 - n) '0'
      else String.sub digits 0 (exp + 1) ^ "." ^ String.sub digits (exp + 1) (n - exp - 1) in
    (if neg then "-" else "") ^ body
  end

let format_char (c : int) : string =
  if c < 256 then String.make 1 (Char.chr c) else "?"

let format (t : typ) (v : value) : string =
  match t, v with
  | T_bool, _ -> if to_int v <> 0 then "True" else "False"
  | T_char, _ -> format_char (to_int v)
  | (T_u4 | T_u), I4 n -> Int64.to_string (Int64.logand (Int64.of_int32 n) 0xFFFFFFFFL)
  | _, I4 n -> Int32.to_string n
  | _, I8 n -> Int64.to_string n
  | (T_r4 | T_r8), R8 f -> format_double f
  | _, R8 f -> format_double f
  | _ -> hooks.to_string v

(* ------------------------------------------------------------------ *)
(* System: Object, the primitives, String, Console *)
(* ------------------------------------------------------------------ *)

let object_ =
  spec { d with sparent = "" } obj [
    inst ".ctor" [] void (fun _ -> Null);
    virt "ToString" [] string (fun a ->
        match a.(0) with
        | Str s -> Str s
        | v -> let st, _, _ = view v in
            Str (match v with Ptr (Inside (_, _, _, c)) -> c.name | _ -> st.cls.name));
    virt "Equals" [obj] bool (fun a ->
        bool_v (match a.(0), a.(1) with
            | Str x, Str y -> x = y
            | Obj x, Obj y -> x == y
            | _ -> false));
    virt "GetHashCode" [] int (fun a ->
        match a.(0) with
        | Str s -> i4 (Hashtbl.hash s)
        | v -> let st, _, _ = view v in i4 (Hashtbl.hash st.cls.name));
    inst "GetType" [] "System.Type" (fun a ->
        let st, _, _ = view a.(0) in
        let t = Obj (make_store (hooks.instance "System.Type" [||]) 0) in
        (match t with Obj ts -> ts.native <- N_type (T_class st.cls) | _ -> ());
        t);
  ]

(* a primitive: a struct of one field, its ToString, Equals,
 * GetHashCode *)
let primitive (name : string) (field : string) (extra : smeth list) =
  let ty = match name with
    | "System.Int32" -> T_i4 | "System.Int64" -> T_i8 | "System.Double" -> T_r8
    | "System.Single" -> T_r4 | "System.Boolean" -> T_bool | "System.Char" -> T_char
    | "System.Byte" -> T_u1 | "System.SByte" -> T_i1 | "System.Int16" -> T_i2
    | "System.UInt16" -> T_u2 | "System.UInt32" -> T_u4 | "System.UInt64" -> T_u8
    | "System.IntPtr" -> T_i | _ -> T_u in
  spec { d with sparent = "System.ValueType"; skind = Struct; sfields = ["m_value", field] }
    name ([
    virt "ToString" [] string (fun a -> Str (format ty (number a.(0))));
    virt "Equals" [obj] bool (fun a ->
        bool_v (match a.(1) with
            | Obj st when st.cls.name = name -> number a.(0) = number (Obj st)
            | _ -> false));
    virt "GetHashCode" [] int (fun a ->
        i4 (match number a.(0) with I4 n -> Int32.to_int n | v -> Hashtbl.hash v));
  ] @ extra)

(* Int32.Parse: a sign and digits, blanks around *)
let parse_int (s : string) : value =
  let t = String.trim s in
  let n = String.length t in
  let start = if n > 0 && (t.[0] = '-' || t.[0] = '+') then 1 else 0 in
  let digits = ref (n > start) in
  for i = start to n - 1 do if t.[i] < '0' || t.[i] > '9' then digits := false done;
  if not !digits then
    hooks.throw "System.FormatException" ("The input string '" ^ s ^ "' was not in a correct format.")
  else begin
    let v = ref 0L in
    for i = start to n - 1 do
      if Int64.compare !v 0x80000000L <= 0 then
        v := Int64.add (Int64.mul !v 10L) (Int64.of_int (Char.code t.[i] - 48))
    done;
    let v = if t.[0] = '-' then Int64.neg !v else !v in
    if Int64.compare v 0x7FFFFFFFL > 0 || Int64.compare v (-0x80000000L) < 0 then
      hooks.throw "System.OverflowException" "Value was either too large or too small for an Int32."
    else I4 (Int64.to_int32 v)
  end

let primitives = [
  spec { d with sparent = "System.ValueType"; skind = Struct } "System.Void" [];
  primitive int int [
    stat "Parse" [string] int (fun a -> parse_int (to_str a.(0)));
  ];
  primitive long long [];
  primitive double double [];
  primitive "System.Single" "System.Single" [];
  primitive bool bool [];
  primitive char char [
    stat "ToString" [char] string (fun a -> Str (format_char (to_int a.(0))));
  ];
  primitive "System.Byte" "System.Byte" [];
  primitive "System.SByte" "System.SByte" [];
  primitive "System.Int16" "System.Int16" [];
  primitive "System.UInt16" "System.UInt16" [];
  primitive "System.UInt32" "System.UInt32" [];
  primitive "System.UInt64" "System.UInt64" [];
  primitive "System.IntPtr" "System.IntPtr" [];
  primitive "System.UIntPtr" "System.UIntPtr" [];
  spec d "System.ValueType" [];
  spec { d with sparent = "System.ValueType" } "System.Enum" [];
  spec d "System.Array" [
    inst "get_Length" [] int (fun a -> let st, _, _ = view a.(0) in i4 st.len);
  ];
]

(* Environment.Exit: the program stops there, its status said *)
exception Exit of int

let encoding =
  spec d "System.Text.Encoding" [
    stat "get_Latin1" [] "System.Text.Encoding" (fun _ ->
        let st = make_store (hooks.instance "System.Text.Encoding" [||]) 0 in
        st.native <- N_message "Latin1";
        Obj st);
  ]

let environment =
  spec d "System.Environment" [
    stat "Exit" [int] void (fun a -> raise (Exit (to_int a.(0))));
  ]

let concat (l : value list) : value =
  Str (String.concat "" (List.map (fun v -> match v with Str s -> s | v -> hooks.to_string v) l))

let index_of (s : string) (sub : string) (from : int) : int =
  let n = String.length s and m = String.length sub in
  let rec go i = if i + m > n then -1 else if String.sub s i m = sub then i else go (i + 1) in
  go from

let range_error () =
  hooks.throw "System.ArgumentOutOfRangeException" "Index and length must refer to a location within the string."

let string_ =
  spec d string [
    inst "get_Length" [] int (fun a -> i4 (String.length (to_str a.(0))));
    inst "get_Chars" [int] char (fun a ->
        let s = to_str a.(0) and i = to_int a.(1) in
        if i < 0 || i >= String.length s then
          hooks.throw "System.IndexOutOfRangeException" "Index was outside the bounds of the array."
        else i4 (Char.code s.[i]));
    inst "Substring" [int] string (fun a ->
        let s = to_str a.(0) and i = to_int a.(1) in
        if i < 0 || i > String.length s then range_error ()
        else Str (String.sub s i (String.length s - i)));
    inst "Substring" [int; int] string (fun a ->
        let s = to_str a.(0) and i = to_int a.(1) and n = to_int a.(2) in
        if i < 0 || n < 0 || i + n > String.length s then range_error ()
        else Str (String.sub s i n));
    inst "IndexOf" [string] int (fun a -> i4 (index_of (to_str a.(0)) (to_str a.(1)) 0));
    inst "IndexOf" [char] int (fun a -> i4 (index_of (to_str a.(0)) (format_char (to_int a.(1))) 0));
    inst "Contains" [string] bool (fun a -> bool_v (index_of (to_str a.(0)) (to_str a.(1)) 0 >= 0));
    inst "StartsWith" [string] bool (fun a ->
        let s = to_str a.(0) and p = to_str a.(1) in
        bool_v (String.length p <= String.length s && String.sub s 0 (String.length p) = p));
    inst "ToUpper" [] string (fun a -> Str (String.uppercase_ascii (to_str a.(0))));
    inst "ToLower" [] string (fun a -> Str (String.lowercase_ascii (to_str a.(0))));
    inst "Trim" [] string (fun a -> Str (String.trim (to_str a.(0))));
    virt "ToString" [] string (fun a -> a.(0));
    virt "Equals" [obj] bool (fun a -> bool_v (match a.(1) with Str t -> to_str a.(0) = t | _ -> false));
    virt "GetHashCode" [] int (fun a -> i4 (Hashtbl.hash (to_str a.(0))));
    inst "CompareTo" [string] int (fun a -> i4 (compare (to_str a.(0)) (to_str a.(1))));
    stat "Compare" [string; string] int (fun a -> i4 (compare (to_str a.(0)) (to_str a.(1))));
    stat "CompareOrdinal" [string; string] int (fun a -> i4 (compare (to_str a.(0)) (to_str a.(1))));
    stat "op_Equality" [string; string] bool (fun a ->
        bool_v (match a.(0), a.(1) with Str x, Str y -> x = y | Null, Null -> true | _ -> false));
    stat "op_Inequality" [string; string] bool (fun a ->
        bool_v (not (match a.(0), a.(1) with Str x, Str y -> x = y | Null, Null -> true | _ -> false)));
    stat "IsNullOrEmpty" [string] bool (fun a -> bool_v (match a.(0) with Str "" | Null -> true | _ -> false));
    stat "Concat" [string; string] string (fun a -> concat [a.(0); a.(1)]);
    stat "Concat" [string; string; string] string (fun a -> concat [a.(0); a.(1); a.(2)]);
    stat "Concat" [string; string; string; string] string (fun a -> concat [a.(0); a.(1); a.(2); a.(3)]);
    stat "Concat" [obj] string (fun a -> concat [a.(0)]);
    stat "Concat" [obj; obj] string (fun a -> concat [a.(0); a.(1)]);
    stat "Concat" [obj; obj; obj] string (fun a -> concat [a.(0); a.(1); a.(2)]);
    stat "Concat" ["System.String[]"] string (fun a ->
        let st, _, _ = view a.(0) in concat (Array.to_list st.r));
    stat "Concat" ["System.Object[]"] string (fun a ->
        let st, _, _ = view a.(0) in concat (Array.to_list st.r));
  ]

(* the console's text: a byte above 127 (Latin-1) as UTF-8, as .NET writes it *)
let utf8 (s : string) : string =
  if not (String.exists (fun c -> Char.code c >= 128) s) then s
  else begin
    let b = Buffer.create (String.length s + 8) in
    String.iter (fun c -> Buffer.add_utf_8_uchar b (Uchar.of_int (Char.code c))) s;
    Buffer.contents b
  end

(* Console.OutputEncoding = Encoding.Latin1: a character a byte, as
 * mini-tiger's programs ask *)
let latin1 = ref false

let write (s : string) : unit = hooks.out (if !latin1 then s else utf8 s)

let console =
  let both name typ =
    [ stat "Write" [name] void (fun a -> write (format typ a.(0)); Null);
      stat "WriteLine" [name] void (fun a -> write (format typ a.(0) ^ "\n"); Null) ] in
  spec d "System.Console" (
    [ stat "WriteLine" [] void (fun _ -> write "\n"; Null);
      stat "Write" [string] void (fun a -> write (match a.(0) with Str s -> s | _ -> ""); Null);
      stat "WriteLine" [string] void (fun a -> write ((match a.(0) with Str s -> s | _ -> "") ^ "\n"); Null);
      stat "Write" [obj] void (fun a -> write (hooks.to_string a.(0)); Null);
      stat "WriteLine" [obj] void (fun a -> write (hooks.to_string a.(0) ^ "\n"); Null);
      stat "Read" [] int (fun _ -> i4 (hooks.read ()));
      (* (the input is read a byte at a time whatever the encoding) *)
      stat "set_InputEncoding" ["System.Text.Encoding"] void (fun _ -> Null);
      stat "set_OutputEncoding" ["System.Text.Encoding"] void (fun a ->
          latin1 := (match a.(0) with
              | Obj st -> (match st.native with N_message "Latin1" -> true | _ -> false)
              | _ -> false);
          Null);
      stat "ReadLine" [] string (fun _ ->
          let b = Buffer.create 80 in
          let rec go () = match hooks.read () with
            | -1 -> if Buffer.length b = 0 then Null else Str (Buffer.contents b)
            | 10 -> Str (Buffer.contents b)
            | c -> Buffer.add_char b (Char.chr c); go () in
          go ()) ]
    @ both int T_i4 @ both long T_i8 @ both double T_r8 @ both bool T_bool
    @ both char T_char @ both "System.UInt32" T_u4 @ both "System.Single" T_r4)

(* ------------------------------------------------------------------ *)
(* The exceptions *)
(* ------------------------------------------------------------------ *)

let message (v : value) : string =
  match get v "_message" with Str s -> s | _ -> ""

(* an exception's class: its message when none is given *)
let exception_ (name : string) (parent : string) (default : string) =
  let ctor0 = inst ".ctor" [] void (fun a -> set a.(0) "_message" (Str default); Null) in
  let ctor1 = inst ".ctor" [string] void (fun a -> set a.(0) "_message" a.(1); Null) in
  if name = "System.Exception" then
    spec { d with sfields = ["_message", string] } name [
      ctor0; ctor1;
      virt "get_Message" [] string (fun a -> Str (message a.(0)));
      virt "ToString" [] string (fun a ->
          let st, _, _ = view a.(0) in
          Str (st.cls.name ^ ": " ^ message a.(0)));
    ]
  else spec { d with sparent = parent } name [ ctor0; ctor1 ]

let exceptions = [
  exception_ "System.Exception" obj "Exception of type 'System.Exception' was thrown.";
  exception_ "System.SystemException" "System.Exception" "System error.";
  exception_ "System.ArithmeticException" "System.SystemException" "Overflow or underflow in the arithmetic operation.";
  exception_ "System.DivideByZeroException" "System.ArithmeticException" "Attempted to divide by zero.";
  exception_ "System.OverflowException" "System.ArithmeticException" "Arithmetic operation resulted in an overflow.";
  exception_ "System.IndexOutOfRangeException" "System.SystemException" "Index was outside the bounds of the array.";
  exception_ "System.NullReferenceException" "System.SystemException" "Object reference not set to an instance of an object.";
  exception_ "System.InvalidCastException" "System.SystemException" "Specified cast is not valid.";
  exception_ "System.InvalidOperationException" "System.SystemException" "Operation is not valid due to the current state of the object.";
  exception_ "System.FormatException" "System.SystemException" "One of the identified items was in an invalid format.";
  exception_ "System.ArgumentException" "System.SystemException" "Value does not fall within the expected range.";
  exception_ "System.ArgumentOutOfRangeException" "System.ArgumentException" "Specified argument was out of the range of valid values.";
  exception_ "System.ArgumentNullException" "System.ArgumentException" "Value cannot be null.";
  exception_ "System.NotSupportedException" "System.SystemException" "Specified method is not supported.";
  exception_ "System.NotImplementedException" "System.SystemException" "The method or operation is not implemented.";
  exception_ "System.ArrayTypeMismatchException" "System.SystemException" "Attempted to access an element as a type incompatible with the array.";
  exception_ "System.Collections.Generic.KeyNotFoundException" "System.SystemException" "The given key was not present in the dictionary.";
  exception_ "System.StackOverflowException" "System.SystemException" "Operation caused a stack overflow.";
]

(* ------------------------------------------------------------------ *)
(* StringBuilder, the interpolation's handler, Type *)
(* ------------------------------------------------------------------ *)

let buffer (v : value) : Buffer.t =
  let st, _, _ = view v in
  match st.native with
  | N_buffer b -> b
  | _ -> let b = Buffer.create 16 in st.native <- N_buffer b; b

let append (s : string) (a : value array) : value = Buffer.add_string (buffer a.(0)) s; a.(0)

let string_builder =
  let sb = "System.Text.StringBuilder" in
  spec d sb [
    inst ".ctor" [] void (fun a -> ignore (buffer a.(0)); Null);
    inst ".ctor" [string] void (fun a -> Buffer.add_string (buffer a.(0)) (match a.(1) with Str s -> s | _ -> ""); Null);
    inst "Append" [string] sb (fun a -> append (match a.(1) with Str s -> s | _ -> "") a);
    inst "Append" [int] sb (fun a -> append (format T_i4 a.(1)) a);
    inst "Append" [long] sb (fun a -> append (format T_i8 a.(1)) a);
    inst "Append" [char] sb (fun a -> append (format T_char a.(1)) a);
    inst "Append" [bool] sb (fun a -> append (format T_bool a.(1)) a);
    inst "Append" [double] sb (fun a -> append (format T_r8 a.(1)) a);
    inst "Append" [obj] sb (fun a -> append (hooks.to_string a.(1)) a);
    inst "get_Length" [] int (fun a -> i4 (Buffer.length (buffer a.(0))));
    virt "ToString" [] string (fun a -> Str (Buffer.contents (buffer a.(0))));
  ]

(* what C# makes of $"n is {n}": a struct of the library's, a local,
 * its methods called on its address *)
let interpolation =
  spec { d with sparent = "System.ValueType"; skind = Struct; sfields = ["_unused", int] }
    "System.Runtime.CompilerServices.DefaultInterpolatedStringHandler" [
    inst ".ctor" [int; int] void (fun a -> Buffer.clear (buffer a.(0)); Null);
    inst "AppendLiteral" [string] void (fun a -> ignore (append (to_str a.(1)) a); Null);
    inst "AppendFormatted" [string] void (fun a ->
        ignore (append (match a.(1) with Str s -> s | _ -> "") a); Null);
    { (inst "AppendFormatted" ["!!0"] void (fun a ->
          ignore (append (hooks.to_string a.(1)) a); Null)) with mgeneric = 1 };
    inst "ToStringAndClear" [] string (fun a ->
        let b = buffer a.(0) in
        let s = Buffer.contents b in
        Buffer.clear b; Str s);
  ]

let type_of (v : value) : typ =
  let st, _, _ = view v in
  match st.native with N_type t -> t | _ -> invalid_arg "Library: not a Type"

(* Type.Name: the class's name without its namespace or arguments *)
let short_name (t : typ) : string =
  match t with
  | T_class c | T_value c -> c.short
  | t -> let k = typ_key t in
      (match String.rindex_opt k '.' with Some i -> String.sub k (i + 1) (String.length k - i - 1) | None -> k)

let reflection = [
  spec { d with sparent = "System.ValueType"; skind = Struct; sfields = ["_unused", int] }
    "System.RuntimeTypeHandle" [];
  spec d "System.Reflection.MemberInfo" [
    virt "get_Name" [] string (fun a -> Str (short_name (type_of a.(0))));
  ];
  spec { d with sparent = "System.Reflection.MemberInfo" } "System.Type" [
    stat "GetTypeFromHandle" ["System.RuntimeTypeHandle"] "System.Type" (fun a ->
        match a.(0) with
        | Handle t ->
            let st = make_store (hooks.instance "System.Type" [||]) 0 in
            st.native <- N_type t;
            Obj st
        | _ -> invalid_arg "Library: GetTypeFromHandle");
    virt "ToString" [] string (fun a -> Str (typ_key (type_of a.(0))));
    virt "get_FullName" [] string (fun a -> Str (typ_key (type_of a.(0))));
  ];
  spec d "System.Attribute" [];
  spec { d with sparent = "System.ValueType"; skind = Struct; sfields = ["_unused", int] }
    "System.RuntimeFieldHandle" [];
  spec d "System.Runtime.CompilerServices.RuntimeHelpers" [
    stat "InitializeArray" ["System.Array"; "System.RuntimeFieldHandle"] void (fun a ->
        (match a.(0), a.(1) with
         | Obj st, Data (file, off) -> Bytes.blit_string file off st.s 0 (Bytes.length st.s)
         | _ -> invalid_arg "InitializeArray");
        Null);
  ];
]

(* ------------------------------------------------------------------ *)
(* The collections *)
(* ------------------------------------------------------------------ *)

let vec (v : value) : vec =
  let st, _, _ = view v in
  match st.native with
  | N_list l -> l
  | _ -> let l = { items = [||]; count = 0 } in st.native <- N_list l; l

let check_index (l : vec) (i : int) : unit =
  if i < 0 || i >= l.count then
    ignore (hooks.throw "System.ArgumentOutOfRangeException"
              "Index was out of range. Must be non-negative and less than the size of the collection. (Parameter 'index')")

let list_add (l : vec) (x : value) : unit =
  if l.count = Array.length l.items then begin
    let bigger = Array.make (max 4 (2 * l.count)) Null in
    Array.blit l.items 0 bigger 0 l.count;
    l.items <- bigger
  end;
  l.items.(l.count) <- x;
  l.count <- l.count + 1

let list_ = "System.Collections.Generic.List`1"
let enumerator = "System.Collections.Generic.List`1+Enumerator"

let list =
  spec { d with sgeneric = 1 } list_ [
    inst ".ctor" [] void (fun a -> ignore (vec a.(0)); Null);
    inst ".ctor" [int] void (fun a -> ignore (vec a.(0)); Null);
    inst "Add" ["!0"] void (fun a -> list_add (vec a.(0)) a.(1); Null);
    inst "get_Count" [] int (fun a -> i4 (vec a.(0)).count);
    inst "get_Item" [int] "!0" (fun a ->
        let l = vec a.(0) and i = to_int a.(1) in check_index l i; l.items.(i));
    inst "set_Item" [int; "!0"] void (fun a ->
        let l = vec a.(0) and i = to_int a.(1) in check_index l i; l.items.(i) <- a.(2); Null);
    inst "Clear" [] void (fun a -> (vec a.(0)).count <- 0; Null);
    inst "Contains" ["!0"] bool (fun a ->
        let l = vec a.(0) in
        let rec go i = i < l.count && (hooks.equals l.items.(i) a.(1) || go (i + 1)) in
        bool_v (go 0));
    inst "GetEnumerator" [] (enumerator ^ "<!0>") (fun a ->
        let st, _, _ = view a.(0) in
        let e = make_store (hooks.instance enumerator st.cls.args) 0 in
        let v = Vt e in
        set v "_list" a.(0);
        set v "_index" (i4 0);
        v);
  ]

(* foreach's struct: List<T>.Enumerator, a generic value type nested in
 * a generic class; its current element a field of type T *)
let list_enumerator =
  spec { d with sparent = "System.ValueType"; skind = Struct; sgeneric = 1;
              sinterfaces = ["System.IDisposable"];
              sfields = ["_list", list_ ^ "<!0>"; "_index", int; "_current", "!0"] }
    enumerator [
    inst "MoveNext" [] bool (fun a ->
        let l = vec (get a.(0) "_list") in
        let i = to_int (get a.(0) "_index") in
        if i < l.count then begin
          set a.(0) "_current" l.items.(i);
          set a.(0) "_index" (i4 (i + 1));
          bool_v true
        end else bool_v false);
    inst "get_Current" [] "!0" (fun a -> get a.(0) "_current");
    virt "Dispose" [] void (fun _ -> Null);
  ]

let dict (v : value) : dict =
  let st, _, _ = view v in
  match st.native with
  | N_dict d -> d
  | _ -> let d = { index = Hashtbl.create 8; keys = [||]; vals = [||]; used = 0 } in
      st.native <- N_dict d; d

(* the entry of a key, -1 if none *)
let find (d : dict) (k : value) : int =
  let rec go l = match l with
    | [] -> -1
    | i :: rest -> if hooks.equals d.keys.(i) k then i else go rest in
  go (Hashtbl.find_all d.index (hooks.hash k))

let dict_set (d : dict) (k : value) (v : value) : unit =
  match find d k with
  | -1 ->
      if d.used = Array.length d.keys then begin
        let n = max 4 (2 * d.used) in
        let grow a = let b = Array.make n Null in Array.blit a 0 b 0 d.used; b in
        d.keys <- grow d.keys; d.vals <- grow d.vals
      end;
      d.keys.(d.used) <- k; d.vals.(d.used) <- v;
      Hashtbl.add d.index (hooks.hash k) d.used;
      d.used <- d.used + 1
  | i -> d.vals.(i) <- v

let no_key (k : value) =
  hooks.throw "System.Collections.Generic.KeyNotFoundException"
    ("The given key '" ^ hooks.to_string k ^ "' was not present in the dictionary.")

let dictionary =
  spec { d with sgeneric = 2 } "System.Collections.Generic.Dictionary`2" [
    inst ".ctor" [] void (fun a -> ignore (dict a.(0)); Null);
    inst "get_Count" [] int (fun a -> i4 (dict a.(0)).used);
    inst "ContainsKey" ["!0"] bool (fun a -> bool_v (find (dict a.(0)) a.(1) >= 0));
    inst "get_Item" ["!0"] "!1" (fun a ->
        let d = dict a.(0) in
        match find d a.(1) with -1 -> no_key a.(1) | i -> d.vals.(i));
    inst "set_Item" ["!0"; "!1"] void (fun a -> dict_set (dict a.(0)) a.(1) a.(2); Null);
    inst "Add" ["!0"; "!1"] void (fun a ->
        let d = dict a.(0) in
        if find d a.(1) >= 0 then
          ignore (hooks.throw "System.ArgumentException"
                    ("An item with the same key has already been added. Key: " ^ hooks.to_string a.(1)));
        dict_set d a.(1) a.(2); Null);
    inst "TryGetValue" ["!0"; "!1&"] bool (fun a ->
        let d = dict a.(0) in
        let out x = match a.(2) with
          | Ptr (Slot (arr, i)) -> arr.(i) <- x
          | Ptr (Bytes (st, off, t)) -> store_at st.s off t x
          | _ -> invalid_arg "TryGetValue: its out" in
        match find d a.(1) with
        | -1 -> bool_v false
        | i -> out d.vals.(i); bool_v true);
  ]

(* the delegates: their .ctor and Invoke made by the machine *)
let delegate (name : string) (generic : int) (params : string list) (ret : string) =
  spec { d with sparent = "System.MulticastDelegate"; skind = Delegate; sgeneric = generic } name [
    { (inst ".ctor" [obj; "System.IntPtr"] void (fun _ -> Null)) with impl = By_runtime };
    { (virt "Invoke" params ret (fun _ -> Null)) with impl = By_runtime };
  ]

let delegates = [
  spec d "System.Delegate" [];
  spec { d with sparent = "System.Delegate" } "System.MulticastDelegate" [];
  delegate "System.Action" 0 [] void;
  delegate "System.Action`1" 1 ["!0"] void;
  delegate "System.Action`2" 2 ["!0"; "!1"] void;
  delegate "System.Func`1" 1 [] "!0";
  delegate "System.Func`2" 2 ["!0"] "!1";
  delegate "System.Func`3" 3 ["!0"; "!1"] "!2";
  (* (named by a delegate's BeginInvoke and EndInvoke, which .NET Core
   * does not run either) *)
  spec { d with skind = Interface } "System.IAsyncResult" [];
  delegate "System.AsyncCallback" 0 ["System.IAsyncResult"] void;
  spec { d with skind = Interface } "System.IDisposable" [
    { (virt "Dispose" [] void (fun _ -> Null)) with impl = Abstract };
  ];
]

let specs : (string, spec) Hashtbl.t =
  let h = Hashtbl.create 64 in
  List.iter (fun s -> Hashtbl.replace h s.sname s)
    ([ object_; string_; console; environment; encoding; string_builder; interpolation; list;
       list_enumerator; dictionary ]
     @ primitives @ exceptions @ reflection @ delegates);
  h
