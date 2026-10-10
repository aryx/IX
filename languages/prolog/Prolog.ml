(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Prolog.mli *)

type term =
  | Atom of string
  | Int of int
  | Var of var
  | Struct of string * term list 
  | Local of int
and var = { id : int; mutable value : term option }

(*****************************************************************************)
(* Variables *)
(*****************************************************************************)

let counter : int ref = ref 0

let fresh () : term =
  incr counter;
  Var { id = !counter; value = None }

let newest () : int = !counter

let rec deref (t : term) : term =
  match t with
  | Var v -> ( match v.value with Some t' -> deref t' | None -> t)
  | _ -> t

(*****************************************************************************)
(* Lists *)
(*****************************************************************************)

let nil : term = Atom "[]"
let cons (h : term) (t : term) : term = Struct (".", [ h; t ])

let rec of_list (xs : term list) : term =
  match xs with
  | [] -> nil
  | x :: rest -> cons x (of_list rest)

let to_list (t : term) : term list option =
  let rec go (t : term) (acc : term list) : term list option =
    match deref t with
    | Atom "[]" -> Some (List.rev acc)
    | Struct (".", [ h; rest ]) -> go rest (h :: acc)
    | _ -> None in
  go t []

let of_string (s : string) : term = of_list (List.init (String.length s) (fun (i : int) -> Int (Char.code s.[i])))

(*****************************************************************************)
(* The operators *)
(*****************************************************************************)

type fixity = Xfx | Xfy | Yfx | Fy | Fx | Xf | Yf

type ops = { prefix : (string, int * fixity) Hashtbl.t; infix : (string, int * fixity) Hashtbl.t }

let fixity_of_string (s : string) : fixity option =
  match s with
  | "xfx" -> Some Xfx | "xfy" -> Some Xfy | "yfx" -> Some Yfx
  | "fy" -> Some Fy | "fx" -> Some Fx | "xf" -> Some Xf | "yf" -> Some Yf
  | _ -> None

let string_of_fixity (f : fixity) : string =
  match f with Xfx -> "xfx" | Xfy -> "xfy" | Yfx -> "yfx" | Fy -> "fy" | Fx -> "fx" | Xf -> "xf" | Yf -> "yf"

let add_op (ops : ops) (priority : int) (fixity : fixity) (name : string) : unit =
  let table : (string, int * fixity) Hashtbl.t =
    match fixity with Fy | Fx -> ops.prefix | Xfx | Xfy | Yfx -> ops.infix | Xf | Yf -> ops.infix in
  match fixity with
  | Xf | Yf -> ()
  | _ -> if priority = 0 then Hashtbl.remove table name else Hashtbl.replace table name (priority, fixity)

let default_ops () : ops =
  let ops : ops = { prefix = Hashtbl.create 31; infix = Hashtbl.create 61 } in
  let add (priority : int) (fixity : fixity) (names : string list) : unit =
    List.iter (fun (name : string) -> add_op ops priority fixity name) names in
  add 1200 Xfx [ ":-"; "-->" ];
  add 1200 Fx [ ":-"; "?-" ];
  add 1150 Fx [ "dynamic"; "discontiguous"; "multifile"; "initialization" ];
  add 1100 Xfy [ ";"; "|" ];
  add 1050 Xfy [ "->"; "*->" ];
  add 1000 Xfy [ "," ];
  add 900 Fy [ "\\+" ];
  add 700 Xfx [ "="; "\\="; "=="; "\\=="; "@<"; "@>"; "@=<"; "@>="; "=.."; "is"; "=:="; "=\\="; "<"; ">"; "=<"; ">=" ];
  add 600 Xfy [ ":" ];
  add 500 Yfx [ "+"; "-"; "/\\"; "\\/"; "xor" ];
  add 400 Yfx [ "*"; "/"; "//"; "rem"; "mod"; "div"; "<<"; ">>" ];
  add 200 Xfx [ "**" ];
  add 200 Xfy [ "^" ];
  add 200 Fy [ "-"; "+"; "\\" ];
  ops

(*****************************************************************************)
(* Printing *)
(*****************************************************************************)

let is_lower (c : char) : bool = c >= 'a' && c <= 'z'
let is_upper (c : char) : bool = (c >= 'A' && c <= 'Z') || c = '_'
let is_digit (c : char) : bool = c >= '0' && c <= '9'
let is_alnum (c : char) : bool = is_lower c || is_upper c || is_digit c
let is_symbol (c : char) : bool = String.contains "+-*/\\^<>=~:.?@#&$" c

let all (p : char -> bool) (s : string) : bool =
  let ok = ref true in
  String.iter (fun (c : char) -> if not (p c) then ok := false) s;
  !ok

(* an atom as it must be written to be read back *)
let atom_text (quoted : bool) (s : string) : string =
  let plain : bool =
    s <> ""
    && ((is_lower s.[0] && all is_alnum s) || all is_symbol s || s = "[]" || s = "!" || s = ";" || s = "{}") in
  if plain || not quoted then s
  else begin
    let b = Buffer.create (String.length s + 2) in
    Buffer.add_char b '\'';
    String.iter
      (fun (c : char) ->
        match c with
        | '\'' -> Buffer.add_string b "\\'"
        | '\\' -> Buffer.add_string b "\\\\"
        | '\n' -> Buffer.add_string b "\\n"
        | '\t' -> Buffer.add_string b "\\t"
        | c -> Buffer.add_char b c)
      s;
    Buffer.add_char b '\'';
    Buffer.contents b
  end

(* a clause's k-th variable, as listing names it: A, B... Z, A1... *)
let var_name (k : int) : string =
  let letter = String.make 1 (Char.chr (65 + (k mod 26))) in
  if k < 26 then letter else letter ^ string_of_int (k / 26)

let to_string (ops : ops) ~(quoted : bool) (t : term) : string =
  (* does a text put after an operator need a space before it? *)
  let glued (name : string) (text : string) : bool =
    text <> "" && name <> ""
    &&
    let last = name.[String.length name - 1] and first = text.[0] in
    (is_alnum last && (is_alnum first || first = '(')) || (is_symbol last && is_symbol first) in
  let rec text (prec : int) (t : term) : string =
    match deref t with
    | Int n -> string_of_int n
    | Var v -> "_G" ^ string_of_int v.id
    | Local k -> var_name k
    | Atom s -> atom_text quoted s
    | Struct (".", [ h; rest ]) -> "[" ^ text 999 h ^ tail rest
    | Struct ("{}", [ x ]) -> "{" ^ text 1200 x ^ "}"
    | Struct ("$VAR", [ n ]) -> ( match deref n with Int k -> var_name k | n -> "$VAR(" ^ text 999 n ^ ")")
    | Struct (name, [ a; b ]) when Hashtbl.mem ops.infix name ->
        let p, fixity = Hashtbl.find ops.infix name in
        let left = text (if fixity = Yfx then p else p - 1) a in
        let right = text (if fixity = Xfy then p else p - 1) b in
        let op : string =
          if name = "," then ","
          else if is_alnum name.[0] then " " ^ name ^ " "
          else if glued name right then name ^ " "
          else name in
        let s = (if glued left op then left ^ " " else left) ^ op ^ right in
        if p > prec then "(" ^ s ^ ")" else s
    | Struct (name, [ a ]) when Hashtbl.mem ops.prefix name ->
        let p, fixity = Hashtbl.find ops.prefix name in
        let arg = text (if fixity = Fy then p else p - 1) a in
        (* (- 1 is not the number -1) *)
        let space : bool = glued name arg || (arg <> "" && is_digit arg.[0]) in
        let s = atom_text quoted name ^ (if space then " " else "") ^ arg in
        if p > prec then "(" ^ s ^ ")" else s
    | Struct (name, args) ->
        atom_text quoted name ^ "(" ^ String.concat "," (List.map (fun (a : term) -> text 999 a) args) ^ ")"
  and tail (t : term) : string =
    match deref t with
    | Atom "[]" -> "]"
    | Struct (".", [ h; rest ]) -> "," ^ text 999 h ^ tail rest
    | t -> "|" ^ text 999 t ^ "]" in
  text 1200 t

(*****************************************************************************)
(* The standard order, and copies *)
(*****************************************************************************)

let rank (t : term) : int =
  match t with Var _ -> 0 | Local _ -> 0 | Int _ -> 1 | Atom _ -> 3 | Struct _ -> 4

let rec compare (a : term) (b : term) : int =
  match (deref a, deref b) with
  | Var x, Var y -> Int.compare x.id y.id
  | Int x, Int y -> Int.compare x y
  | Atom x, Atom y -> String.compare x y
  | Struct (f, xs), Struct (g, ys) ->
      let n = List.length xs and m = List.length ys in
      if n <> m then Int.compare n m else if f <> g then String.compare f g else compare_all xs ys
  | x, y -> Int.compare (rank x) (rank y)

and compare_all (xs : term list) (ys : term list) : int =
  match (xs, ys) with
  | x :: xs, y :: ys ->
      let r = compare x y in
      if r <> 0 then r else compare_all xs ys
  | _ -> 0

let variables (t : term) : term list =
  let seen : (int, unit) Hashtbl.t = Hashtbl.create 17 in
  let acc : term list ref = ref [] in
  let rec go (t : term) : unit =
    match deref t with
    | Var v as t ->
        if not (Hashtbl.mem seen v.id) then begin
          Hashtbl.replace seen v.id ();
          acc := t :: !acc
        end
    | Struct (_, args) -> List.iter go args
    | _ -> () in
  go t;
  List.rev !acc

let copy (t : term) : term =
  let fresh_of : (int, term) Hashtbl.t = Hashtbl.create 17 in
  let rec go (t : term) : term =
    match deref t with
    | Var v -> (
        match Hashtbl.find_opt fresh_of v.id with
        | Some t' -> t'
        | None ->
            let t' = fresh () in
            Hashtbl.replace fresh_of v.id t';
            t')
    | Struct (name, args) -> Struct (name, List.map go args)
    | t -> t in
  go t

(* the atom or the number a text is; a list of codes or of characters is
 * its text too *)
let text_of (t : term) : string option =
  match deref t with
  | Atom s -> Some s
  | Int n -> Some (string_of_int n)
  | t -> (
      match to_list t with
      | None -> None
      | Some items ->
          let b = Buffer.create 16 in
          let ok = ref true in
          List.iter
            (fun (item : term) ->
              match deref item with
              | Int c when c >= 0 && c < 256 -> Buffer.add_char b (Char.chr c)
              | Atom s when String.length s = 1 -> Buffer.add_string b s
              | _ -> ok := false)
            items;
          if !ok then Some (Buffer.contents b) else None)
