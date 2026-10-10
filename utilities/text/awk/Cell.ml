(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Cell.mli *)
open Ast

exception Fatal of string
exception Syntax of string

let warning = ref (fun (_ : string) -> ())

(* tran.c's tables: 50 lists at first, four times more when there are
 * twice as many cells as lists, a new cell at its list's front *)

let table () = { size = 50; count = 0; buckets = Array.make 50 [] }

(* (a char is signed, the sum an unsigned of 32 bits) *)
let hash s n =
  let h = ref 0L in
  String.iter (fun c ->
    let c = Char.code c in
    h := Int64.logand (Int64.add (Int64.of_int (if c >= 128 then c - 256 else c)) (Int64.mul 31L !h)) 0xFFFFFFFFL) s;
  Int64.to_int (Int64.rem !h (Int64.of_int n))

let lookup (t : table) name = List.find_opt (fun (c : cell) -> c.name = name) t.buckets.(hash name t.size)

let rehash (t : table) =
  let size = 4 * t.size in
  let buckets = Array.make size [] in
  Array.iter (List.iter (fun (c : cell) -> let h = hash c.name size in buckets.(h) <- c :: buckets.(h))) t.buckets;
  t.buckets <- buckets;
  t.size <- size

let install (t : table) name v =
  match lookup t name with
  | Some c -> c
  | None ->
      let c = { name; v; kind = Variable } in
      t.count <- t.count + 1;
      if t.count > 2 * t.size then rehash t;
      let h = hash name t.size in
      t.buckets.(h) <- c :: t.buckets.(h);
      c

let remove (t : table) name =
  let h = hash name t.size in
  if List.exists (fun (c : cell) -> c.name = name) t.buckets.(h) then begin
    t.buckets.(h) <- List.filter (fun (c : cell) -> c.name <> name) t.buckets.(h);
    t.count <- t.count - 1
  end

(* (the table's size is asked at each list: the loop's body may grow it) *)
let iter (t : table) f =
  let rec go k = if k < t.size then (List.iter f t.buckets.(k); go (k + 1)) in
  go 0

let of_float f = { num = true; str = false; f; s = "" }
let of_string s = { num = false; str = true; f = 0.; s }
let unset = Scalar { num = true; str = true; f = 0.; s = "" }
let temp v = { name = ""; v = Scalar v; kind = Temporary }

let symtab = table ()
let constant name v = let c = { name; v = Scalar v; kind = Constant } in symtab.buckets.(hash name symtab.size) <- c :: symtab.buckets.(hash name symtab.size); symtab.count <- symtab.count + 1; c
let zero = constant "0" { num = true; str = true; f = 0.; s = "0" }
let null = constant "$zero&null" { num = true; str = true; f = 0.; s = "" }
let variable name v = install symtab name (Scalar v)
let fs = variable "FS" (of_string " ")
let rs = variable "RS" (of_string "\n")
let ofs = variable "OFS" (of_string " ")
let ors = variable "ORS" (of_string "\n")
let _ofmt = variable "OFMT" (of_string "%.6g")
let convfmt = variable "CONVFMT" (of_string "%.6g")
let filename = variable "FILENAME" (of_string "")
let nf = variable "NF" (of_float 0.)
let nr = variable "NR" (of_float 0.)
let fnr = variable "FNR" (of_float 0.)
let subsep = variable "SUBSEP" (of_string "\028")
let rstart = variable "RSTART" (of_float 0.)
let rlength = variable "RLENGTH" (of_float 0.)
let _symtab = install symtab "SYMTAB" (Array symtab)

(* lib.c's to_number and is_float, on the text from an offset: the
 * number and where it ends, None when there is none *)

let is_float s =
  let n = String.length s in
  let digit k = k < n && s.[k] >= '0' && s.[k] <= '9' in
  let rec spaces k = if k < n && (s.[k] = ' ' || (s.[k] >= '\t' && s.[k] <= '\r')) then spaces (k + 1) else k in
  let rec digits k = if digit k then digits (k + 1) else k in
  let start = spaces 0 in
  let k = if start < n && (s.[start] = '-' || s.[start] = '+') then start + 1 else start in
  let int_end = digits k in
  let frac_end = if int_end < n && s.[int_end] = '.' then digits (int_end + 1) else int_end in
  (* digits before or after the point *)
  if int_end = k && frac_end <= int_end + 1 then None
  else begin
    let stop =
      if frac_end < n && (s.[frac_end] = 'e' || s.[frac_end] = 'E') then begin
        let e = if frac_end + 1 < n && (s.[frac_end + 1] = '-' || s.[frac_end + 1] = '+') then frac_end + 2 else frac_end + 1 in
        if digit e then digits e else frac_end
      end else frac_end in
    let f = float_of_string (String.sub s start (stop - start)) in
    if f = infinity || f = neg_infinity then None else Some (f, stop)
  end

let number_prefix s =
  let n = String.length s in
  let rec spaces k = if k < n && (s.[k] = ' ' || (s.[k] >= '\t' && s.[k] <= '\r')) then spaces (k + 1) else k in
  let start = spaces 0 in
  let negative = start < n && s.[start] = '-' in
  let k = if start < n && (s.[start] = '-' || s.[start] = '+') then start + 1 else start in
  let value c = match c with '0' .. '9' -> Char.code c - 48 | 'a' .. 'f' -> Char.code c - 87 | 'A' .. 'F' -> Char.code c - 55 | _ -> 99 in
  let rec digits base k acc = if k < n && value s.[k] < base then digits base (k + 1) ((acc *. float_of_int base) +. float_of_int (value s.[k])) else (k, acc) in
  (* strtoll, base 0: 0x and hexadecimal, 0 and octal, or decimal *)
  let stop, v =
    if k + 2 < n && s.[k] = '0' && (s.[k + 1] = 'x' || s.[k + 1] = 'X') && value s.[k + 2] < 16 then digits 16 (k + 2) 0.
    else if k < n && s.[k] = '0' then digits 8 k 0.
    else digits 10 k 0. in
  let stop = if stop = k then 0 else stop in
  if stop < n && String.contains ".EINein" s.[stop] then is_float s
  else if stop = 0 then None
  else Some ((if negative then -. v else v), stop)

let to_number s =
  match number_prefix s with
  | Some (f, stop) ->
      let rec blank k = k >= String.length s || ((s.[k] = ' ' || (s.[k] >= '\t' && s.[k] <= '\r')) && blank (k + 1)) in
      if blank stop then Some f else None
  | None -> None

let of_input s = match to_number s with Some f -> { num = true; str = true; f; s } | None -> of_string s

(* lib.c's record: $0 and the fields, each made from the other when it
 * is read after the other changed *)

let record = { name = "0"; v = Scalar (of_string ""); kind = Field 0 }
let fields : cell array ref = ref [||]
let fields_done = ref true     (* the fields are the record's *)
let record_done = ref true     (* the record is the fields' *)
let last_field = ref 0
(* FS when the record was read *)
let input_fs = ref " "
(* is $0 the text last read, or made of the fields (the C's buffer),
 * not a string assigned to it *)
let record_is_input = ref true

let empty_field = Scalar (of_string "")

let grow n =
  if n > Array.length !fields then
    fields := Array.init (max n (max 200 (2 * Array.length !fields))) (fun k ->
      if k < Array.length !fields then !fields.(k) else { name = string_of_int (k + 1); v = empty_field; kind = Field (k + 1) })

let set_nf n = nf.v <- Scalar (of_float (float_of_int n))

let rec build_fields () =
  if not !fields_done then begin
    let r = (match record.v with Scalar v when v.str -> v.s | _ -> getsval record) in
    let n = String.length r in
    let count = ref 0 in
    let add s =
      incr count;
      grow !count;
      !fields.(!count - 1).v <- Scalar (of_input s) in
    let fs = !input_fs in
    let blank c = c = ' ' || c = '\t' || c = '\n' in
    if String.length fs > 1 then begin
      (* a regular expression *)
      if n > 0 then begin
        let re = Re.compile fs in
        let rec go from =
          match Re.find_nonempty re r from with
          | Some (start, len) -> add (String.sub r from (start - from)); go (start + len)
          | None -> add (String.sub r from (n - from)) in
        go 0
      end
    end else if fs = " " then begin
      let rec go k =
        let rec skip k = if k < n && blank r.[k] then skip (k + 1) else k in
        let start = skip k in
        if start < n then begin
          let rec word k = if k < n && not (blank r.[k]) then word (k + 1) else k in
          let stop = word start in
          add (String.sub r start (stop - start));
          go stop
        end in
      go 0
    end else if fs = "" then begin
      (* a character a field *)
      let chars, rest = Utf8.chars r in
      List.iter add chars;
      if rest <> "" then add rest
    end
    else if n > 0 then begin
      (* (a newline is always a separator) *)
      let rec go start k =
        if k >= n then add (String.sub r start (k - start))
        else if r.[k] = fs.[0] || r.[k] = '\n' then (add (String.sub r start (k - start)); go (k + 1) (k + 1))
        else go start (k + 1) in
      go 0 0
    end;
    for k = !count to !last_field - 1 do !fields.(k).v <- empty_field done;
    last_field := !count;
    fields_done := true;
    set_nf !count
  end

and build_record () =
  if not !record_done then begin
    let n = int_of_float (match nf.v with Scalar v -> v.f | _ -> 0.) in
    grow n;
    let sep = getsval ofs in
    let b = Buffer.create 256 in
    for k = 1 to n do
      Buffer.add_string b (getsval !fields.(k - 1));
      if k < n then Buffer.add_string b sep
    done;
    record.v <- Scalar (of_string (Buffer.contents b));
    record_is_input := true;
    record_done := true
  end

(* what a cell must be made of before it is read *)
and fresh (c : cell) =
  match c.kind with
  | Field 0 -> build_record ()
  | Field _ -> build_fields ()
  | Variable | Constant | Temporary -> ()

and scalar (c : cell) what =
  match c.v with
  | Scalar v -> v
  | Array _ -> raise (Fatal (Printf.sprintf "can't %s %s; it's an array name." what c.name))
  | Function _ -> raise (Fatal (Printf.sprintf "can't %s %s; it's a function." what c.name))

and getfval (c : cell) =
  fresh c;
  let v = scalar c "read value of" in
  if v.num then v.f
  else match to_number v.s with
    (* (a number from now on, but not a constant: "10" < 9 stays a comparison of strings) *)
    | Some f -> if c.kind <> Constant then c.v <- Scalar { v with num = true; f }; f
    (* not a number, but the one it starts with is its value: "3x" + 1 is 4 *)
    | None -> (match number_prefix v.s with Some (f, _) -> f | None -> 0.)

and getsval (c : cell) =
  fresh c;
  let v = scalar c "read value of" in
  if v.str then v.s
  else begin
    let s =
      if v.f = 0. then "0"
      else if Float.trunc v.f = v.f then Cformat.number "%.30g" v.f
      else Cformat.number (getsval convfmt) v.f in
    c.v <- Scalar { v with str = true; s };
    s
  end

(* an assignment: to a field, the record is to be made again (and the
 * fields are that many at least); to the record, its fields *)
let assigned (c : cell) =
  ignore (scalar c "assign to");
  match c.kind with
  | Field 0 -> fields_done := false; record_done := true; record_is_input := false
  | Field n ->
      build_fields ();
      record_done := false;
      if n > !last_field then begin
        grow n;
        last_field := n;
        set_nf n
      end
  | Variable | Constant | Temporary -> ()

let setfval (c : cell) f = assigned c; c.v <- Scalar (of_float f)
let setsval (c : cell) s = assigned c; c.v <- Scalar (of_string s)

let array (c : cell) =
  match c.v with
  | Array t -> t
  | Scalar _ | Function _ -> let t = table () in c.v <- Array t; t

let set_record s =
  record.v <- Scalar (of_input s);
  record_is_input := true;
  fields_done := false;
  record_done := true

let end_of_input () =
  (match record.v with
   | Scalar v when !record_is_input -> record.v <- Scalar { v with str = true; s = "" }
   | _ -> ());
  fields_done := false;
  record_done := true

let remember_fs () = input_fs := getsval fs

(* a cell's value, made from the record or the fields first if it is one of them *)
let value (c : cell) = fresh c; scalar c "read value of"

let field n =
  if n < 0 then raise (Fatal (Printf.sprintf "trying to access field %d" n));
  if n = 0 then record else (grow n; !fields.(n - 1))
