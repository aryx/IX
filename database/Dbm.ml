(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Dbm.mli *)

type reg = R of int [@@unboxed]
type cursor = C of int [@@unboxed]
type value = Unspecified | Null | Int of int | Text of string | Record of string
type cmp = Eq | Ne | Lt | Le | Gt | Ge
type order = Lt | Le | Gt | Ge

type 'j instr =
  | Noop
  | Open_read of cursor * reg * int
  | Open_write of cursor * reg * int
  | Close of cursor
  | Rewind of cursor * 'j
  | Next of cursor * 'j
  | Prev of cursor * 'j
  | Seek of Cursor.seek * cursor * 'j * reg
  | Column of cursor * int * reg
  | Key of cursor * reg
  | Integer of int * reg
  | String of int * reg * string
  | Null of reg
  | Result_row of reg * int
  | Make_record of reg * int * reg
  | Insert of cursor * reg * reg
  | Cmp of cmp * reg * 'j * reg
  | Idx_cmp of order * cursor * 'j * reg
  | Idx_pkey of cursor * reg
  | Idx_insert of cursor * reg * reg
  | Create of Btree.tree * reg
  | Copy of reg * reg
  | Scopy of reg * reg
  | Halt

let map_jump f = function
  | Rewind (c, j) -> Rewind (c, f j)
  | Next (c, j) -> Next (c, f j)
  | Prev (c, j) -> Prev (c, f j)
  | Seek (k, c, j, r) -> Seek (k, c, f j, r)
  | Cmp (k, a, j, b) -> Cmp (k, a, f j, b)
  | Idx_cmp (k, c, j, r) -> Idx_cmp (k, c, f j, r)
  | Noop -> Noop
  | Open_read (c, r, n) -> Open_read (c, r, n)
  | Open_write (c, r, n) -> Open_write (c, r, n)
  | Close c -> Close c
  | Column (c, i, r) -> Column (c, i, r)
  | Key (c, r) -> Key (c, r)
  | Integer (v, r) -> Integer (v, r)
  | String (n, r, s) -> String (n, r, s)
  | Null r -> Null r
  | Result_row (r, n) -> Result_row (r, n)
  | Make_record (r, n, d) -> Make_record (r, n, d)
  | Insert (c, d, k) -> Insert (c, d, k)
  | Idx_pkey (c, r) -> Idx_pkey (c, r)
  | Idx_insert (c, k, p) -> Idx_insert (c, k, p)
  | Create (t, r) -> Create (t, r)
  | Copy (a, b) -> Copy (a, b)
  | Scopy (a, b) -> Scopy (a, b)
  | Halt -> Halt

type row = { opcode : string; p1 : int; p2 : int; p3 : int; p4 : string option }

let seek_name : Cursor.seek -> string = function Eq -> "Seek" | Gt -> "SeekGt" | Ge -> "SeekGe" | Lt -> "SeekLt" | Le -> "SeekLe"
let cmp_name : cmp -> string = function Eq -> "Eq" | Ne -> "Ne" | Lt -> "Lt" | Le -> "Le" | Gt -> "Gt" | Ge -> "Ge"
let order_name : order -> string = function Lt -> "IdxLt" | Le -> "IdxLe" | Gt -> "IdxGt" | Ge -> "IdxGe"

let to_row (i : int instr) : row =
  (* p1 p2 p3 p4, as chidb prints them: 0 and None unused *)
  let r opcode p1 p2 p3 p4 = { opcode; p1; p2; p3; p4 } in
  match i with
  | Noop -> r "Noop" 0 0 0 None
  | Open_read (C c, R n, cols) -> r "OpenRead" c n cols None
  | Open_write (C c, R n, cols) -> r "OpenWrite" c n cols None
  | Close (C c) -> r "Close" c 0 0 None
  | Rewind (C c, j) -> r "Rewind" c j 0 None
  | Next (C c, j) -> r "Next" c j 0 None
  | Prev (C c, j) -> r "Prev" c j 0 None
  | Seek (k, C c, j, R n) -> r (seek_name k) c j n None
  | Column (C c, col, R n) -> r "Column" c col n None
  | Key (C c, R n) -> r "Key" c n 0 None
  | Integer (v, R n) -> r "Integer" v n 0 None
  | String (len, R n, s) -> r "String" len n 0 (Some s)
  | Null (R n) -> r "Null" 0 n 0 None
  | Result_row (R n, count) -> r "ResultRow" n count 0 None
  | Make_record (R n, count, R d) -> r "MakeRecord" n count d None
  | Insert (C c, R d, R k) -> r "Insert" c d k None
  | Cmp (k, R a, j, R b) -> r (cmp_name k) a j b None
  | Idx_cmp (k, C c, j, R n) -> r (order_name k) c j n None
  | Idx_pkey (C c, R n) -> r "IdxPKey" c n 0 None
  | Idx_insert (C c, R k, R p) -> r "IdxInsert" c k p None
  | Create (Table, R n) -> r "CreateTable" n 0 0 None
  | Create (Index, R n) -> r "CreateIndex" n 0 0 None
  | Copy (R a, R b) -> r "Copy" a b 0 None
  | Scopy (R a, R b) -> r "SCopy" a b 0 None
  | Halt -> r "Halt" 0 0 0 None

let of_row { opcode; p1; p2; p3; p4 } : int instr =
  match opcode with
  | "Noop" -> Noop
  | "OpenRead" -> Open_read (C p1, R p2, p3)
  | "OpenWrite" -> Open_write (C p1, R p2, p3)
  | "Close" -> Close (C p1)
  | "Rewind" -> Rewind (C p1, p2)
  | "Next" -> Next (C p1, p2)
  | "Prev" -> Prev (C p1, p2)
  | "Seek" -> Seek (Eq, C p1, p2, R p3)
  | "SeekGt" -> Seek (Gt, C p1, p2, R p3)
  | "SeekGe" -> Seek (Ge, C p1, p2, R p3)
  | "SeekLt" -> Seek (Lt, C p1, p2, R p3)
  | "SeekLe" -> Seek (Le, C p1, p2, R p3)
  | "Column" -> Column (C p1, p2, R p3)
  | "Key" -> Key (C p1, R p2)
  | "Integer" -> Integer (p1, R p2)
  | "String" -> (match p4 with Some s -> String (p1, R p2, s) | None -> invalid_arg "String without its string")
  | "Null" -> Null (R p2)
  | "ResultRow" -> Result_row (R p1, p2)
  | "MakeRecord" -> Make_record (R p1, p2, R p3)
  | "Insert" -> Insert (C p1, R p2, R p3)
  | "Eq" -> Cmp (Eq, R p1, p2, R p3)
  | "Ne" -> Cmp (Ne, R p1, p2, R p3)
  | "Lt" -> Cmp (Lt, R p1, p2, R p3)
  | "Le" -> Cmp (Le, R p1, p2, R p3)
  | "Gt" -> Cmp (Gt, R p1, p2, R p3)
  | "Ge" -> Cmp (Ge, R p1, p2, R p3)
  | "IdxGt" -> Idx_cmp (Gt, C p1, p2, R p3)
  | "IdxGe" -> Idx_cmp (Ge, C p1, p2, R p3)
  | "IdxLt" -> Idx_cmp (Lt, C p1, p2, R p3)
  | "IdxLe" -> Idx_cmp (Le, C p1, p2, R p3)
  | "IdxPKey" -> Idx_pkey (C p1, R p2)
  | "IdxInsert" -> Idx_insert (C p1, R p2, R p3)
  | "CreateTable" -> Create (Table, R p1)
  | "CreateIndex" -> Create (Index, R p1)
  | "Copy" -> Copy (R p1, R p2)
  | "SCopy" -> Scopy (R p1, R p2)
  | "Halt" -> Halt
  | op -> invalid_arg ("unknown opcode " ^ op)

exception Constraint

type t = {
  bt : Btree.t;
  program : int instr array;
  mutable pc : int;
  mutable regs : value array;
  mutable cursors : Cursor.t option array;
  mutable result : int * int;    (* the last ResultRow's first register and count *)
}

type step = Row | Done

let create bt program = { bt; program; pc = 0; regs = Array.make 10 Unspecified; cursors = Array.make 10 None; result = (0, 0) }

let get t (R n) : value = if n < Array.length t.regs then t.regs.(n) else Unspecified

let set t (R n) (v : value) =
  if n >= Array.length t.regs then t.regs <- Array.append t.regs (Array.make (n + 1 - Array.length t.regs) Unspecified);
  t.regs.(n) <- v

let cursor t (C c) =
  match if c < Array.length t.cursors then t.cursors.(c) else None with
  | Some cur -> cur
  | None -> invalid_arg (Printf.sprintf "cursor %d is not open" c)

let open_cursor t (C c) cur =
  if c >= Array.length t.cursors then t.cursors <- Array.append t.cursors (Array.make (c + 1 - Array.length t.cursors) None);
  t.cursors.(c) <- Some cur

(* a register's integer as a B-tree key: unsigned, as chidb casts it *)
let key_of t r = match get t r with Int n -> n land 0xffffffff | _ -> 0

(* a key in a 32-bit register: signed, as chidb casts it *)
let of_key k = Int32.to_int (Int32.of_int k)

let int_of t r = match get t r with Int n -> n | _ -> 0

let compare_values a b =
  match a, b with
  | Int x, Int y -> compare x y
  | Text x, Text y -> compare x y
  | _ -> invalid_arg "comparing values of different types"

(* the current row's record, the current index entry's value and key *)
let current_data t c = match Cursor.current (cursor t c) with Cursor.Row r -> r.data | Cursor.Entry _ -> invalid_arg "not a table cursor"
let current_entry t c = match Cursor.current (cursor t c) with Cursor.Entry e -> e.key, e.pkey | Cursor.Row _ -> invalid_arg "not an index cursor"

let insert f = try f () with Btree.Duplicate -> raise Constraint

(* what an instruction does next: go on, or yield a row *)
type next = Go | Yield

(* one instruction; the pc already past it *)
let exec t : int instr -> next =
  let jump_if b j = if b then t.pc <- j in
  function
  | Noop -> Go
  | Open_read (c, r, _) | Open_write (c, r, _) -> open_cursor t c (Cursor.open_ t.bt (int_of t r land 0xffffffff)); Go
  | Close (C c) -> if c < Array.length t.cursors then t.cursors.(c) <- None; Go
  | Rewind (c, j) -> jump_if (not (Cursor.rewind (cursor t c))) j; Go
  | Next (c, j) -> jump_if (Cursor.next (cursor t c)) j; Go
  | Prev (c, j) -> jump_if (Cursor.prev (cursor t c)) j; Go
  | Seek (k, c, j, r) -> jump_if (not (Cursor.seek (cursor t c) k (key_of t r))) j; Go
  | Column (c, col, r) ->
      (match List.nth (Record.unpack (current_data t c) 0) col with
       | Record.Null -> set t r Null
       | Record.Int (_, n) -> set t r (Int n)
       | Record.Text s -> set t r (Text s));
      Go
  | Key (c, r) ->
      let k = match Cursor.current (cursor t c) with Cursor.Row x -> x.key | Cursor.Entry x -> x.key in
      set t r (Int (of_key k));
      Go
  | Integer (v, r) -> set t r (Int v); Go
  | String (_, r, s) -> set t r (Text s); Go
  | Null r -> set t r Null; Go
  | Result_row (R n, count) -> t.result <- (n, count); Yield
  | Make_record (R n, count, r) ->
      let values = List.filter_map (fun i -> match get t (R (n + i)) with
        | Null -> Some Record.Null
        | Int v -> Some (Record.Int (W32, v))
        | Text s -> Some (Record.Text s)
        | Unspecified | Record _ -> None) (List.init count Fun.id) in
      set t r (Record (Record.pack values));
      Go
  | Insert (c, rd, rk) ->
      let root = Cursor.root (cursor t c) in
      (match get t rd with
       | Record data -> insert (fun () -> Btree.insert_in_table t.bt root (key_of t rk) (Bytes.of_string data))
       | Unspecified | Null | Int _ | Text _ -> invalid_arg "Insert: not a record");
      Go
  | Cmp (k, a, j, b) ->
      (* chidb's: Eq and Ne compare the first with the third, the orders
       * the third with the first *)
      let c = compare_values (get t b) (get t a) in
      jump_if (match k with Eq -> c = 0 | Ne -> c <> 0 | Lt -> c < 0 | Le -> c <= 0 | Gt -> c > 0 | Ge -> c >= 0) j;
      Go
  | Idx_cmp (k, c, j, r) ->
      let key = fst (current_entry t c) and v = key_of t r in
      jump_if (match k with Lt -> key < v | Le -> key <= v | Gt -> key > v | Ge -> key >= v) j;
      Go
  | Idx_pkey (c, r) -> set t r (Int (of_key (snd (current_entry t c)))); Go
  | Idx_insert (c, rk, rp) ->
      let root = Cursor.root (cursor t c) in
      insert (fun () -> Btree.insert_in_index t.bt root (key_of t rk) (key_of t rp));
      Go
  | Create (tree, r) -> set t r (Int (Btree.new_node t.bt tree Leaf)); Go
  | Copy (a, b) | Scopy (a, b) -> set t b (get t a); Go
  | Halt -> t.pc <- Array.length t.program; Go

let rec step t =
  if t.pc >= Array.length t.program then Done
  else begin
    let i = t.program.(t.pc) in
    t.pc <- t.pc + 1;
    match exec t i with Yield -> Row | Go -> step t
  end

let n_registers t = Array.length t.regs
let register t n = get t (R n)

let result_row t = let n, count = t.result in List.init count (fun i -> get t (R (n + i)))

let registers t = List.filter_map (fun (i, v) -> if v = Unspecified then None else Some (i, v)) (List.mapi (fun i v -> i, v) (Array.to_list t.regs))

let show_value = function
  | Unspecified -> ""
  | Null -> "NULL"
  | Int n -> string_of_int n
  | Text s -> "\"" ^ s ^ "\""
  | Record s -> Printf.sprintf "(%d bytes)" (String.length s)
