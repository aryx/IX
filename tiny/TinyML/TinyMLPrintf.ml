(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMLPrintf.mli *)
open TinyMLLexer
open TinyMLTree

(* Printf's sprintf, ksprintf and bprintf, their format a string written
 * there, read as the concatenation they make: Printf.sprintf "r%d, %s"
 * a b is String.concat "" [ "r"; string_of_int a; ", "; b ], so the
 * type checker sees no format (OCaml's has a type of its own, which
 * HM would need to be told). %d %s %c %x %S and %%, a width, - and 0;
 * TinyLibCore's Printf has what %x, %S and a width call. A format
 * given fewer values than it has holes is a function of the others.
 * (old: no Printf, plan_tiny_self_hosting.md's step 7: its 176 calls
 * written as ^, a string made for each piece) *)
type piece =
  | Text of string
  | Hole of char * bool * bool * int   (* the letter, -, 0, the width *)

let pieces fmt =
  let n = String.length fmt and b = Buffer.create 16 and out = ref [] in
  let text () =
    if Buffer.length b > 0 then
      (out := Text (Buffer.contents b) :: !out; Buffer.clear b)
  in
  let rec digits k w =
    if k < n && fmt.[k] >= '0' && fmt.[k] <= '9' then
      digits (k + 1) ((w * 10) + Char.code fmt.[k] - 48)
    else k, w
  in
  let rec go i =
    if i < n then
      if fmt.[i] <> '%' then (Buffer.add_char b fmt.[i]; go (i + 1))
      else if i + 1 < n && fmt.[i + 1] = '%' then (Buffer.add_char b '%'; go (i + 2))
      else begin
        let left = i + 1 < n && fmt.[i + 1] = '-' in
        let j = if left then i + 2 else i + 1 in
        let zero = j < n && fmt.[j] = '0' in
        let k, width = digits j 0 in
        if k >= n || not (String.contains "dscxS" fmt.[k]) then
          error ("a format of Printf's that tiny-ml does not read: " ^ fmt);
        text ();
        out := Hole (fmt.[k], left, zero, width) :: !out;
        go (k + 1)
      end in
  go 0;
  text ();
  List.rev !out

let printf_call name args =
  let first, args =
    if name = "Printf.sprintf" then None, args
    else
      match args with
      | a :: r -> Some a, r
      | [] -> error (name ^ ": no format")
  in
  match args with
  | Const (CStr fmt) :: given ->
      let ps = pieces fmt in
      let holes =
        List.length (List.filter (function Hole _ -> true | Text _ -> false) ps)
      in
      let missing =
        List.init (max 0 (holes - List.length given))
          (fun i -> Printf.sprintf "%%p%d" i)
      in
      let bool b = Con ((if b then "true" else "false"), []) in
      let hole c left zero w v =
        let s = match c with
          | 'd' -> App (var "string_of_int", [ v ])
          | 'c' -> App (var "String.make", [ Const (CInt 1); v ])
          | 'x' -> App (var "Printf.hex", [ v ])
          | 'S' -> App (var "Printf.quoted", [ v ])
          | _ -> v in
        if w = 0 then s
        else App (var "Printf.pad", [ bool left; bool zero; Const (CInt w); s ])
      in
      let rec build ps vs =
        match ps, vs with
        | [], _ -> Con ("[]", [])
        | Text t :: r, _ -> Con ("::", [ Const (CStr t); build r vs ])
        | Hole (c, left, zero, w) :: r, v :: vr ->
            Con ("::", [ hole c left zero w v; build r vr ])
        | Hole _ :: _, [] -> error "printf: a hole without its value" in
      let values =
        List.filteri (fun i _ -> i < holes) given @ List.map var missing in
      let s = App (var "String.concat", [ Const (CStr ""); build ps values ]) in
      (* bprintf's pieces each added to the buffer, when the values are
       * names or constants (evaluated in any order, the same; else the
       * concatenation, its values evaluated as OCaml's are) *)
      let simple =
        List.for_all (function Var _ | Const _ -> true | _ -> false) values in
      let rec adds b ps vs =
        match ps, vs with
        | [], _ -> Con ("()", [])
        | [ Text t ], _ -> App (var "Buffer.add_string", [ b; Const (CStr t) ])
        | Text t :: r, _ ->
            Seq (App (var "Buffer.add_string", [ b; Const (CStr t) ]), adds b r vs)
        | [ Hole (c, left, zero, w) ], v :: _ ->
            App (var "Buffer.add_string", [ b; hole c left zero w v ])
        | Hole (c, left, zero, w) :: r, v :: vr ->
            Seq (App (var "Buffer.add_string", [ b; hole c left zero w v ]),
              adds b r vr)
        | Hole _ :: _, [] -> error "printf: a hole without its value" in
      let e = match name, first with
        | "Printf.ksprintf", Some k -> App (k, [ s ])
        | "Printf.bprintf", Some b
          when simple && (match b with Var _ -> true | _ -> false) ->
            adds b ps values
        | "Printf.bprintf", Some b -> App (var "Buffer.add_string", [ b; s ])
        | _ -> s in
      let e = if missing = [] then e else Fun (missing, e) in
      (match List.filteri (fun i _ -> i >= holes) given with
       | [] -> e
       | extra -> App (e, extra))
  | _ ->
      error
        (name ^ ": its format must be a string written there (tiny-ml reads it)")
