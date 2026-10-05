(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Schema.mli *)

type item = { kind : Btree.tree; name : string; table : string; root : int; sql : string; key : int }

let load bt =
  let _, cells = Btree.cells bt 1 in
  List.filter_map (function
    | Btree.Table_leaf { key; data } -> (
        match Record.unpack data 0 with
        | [ Text kind; Text name; Text table; Int (_, root); Text sql ] ->
            Some { kind = (if kind = "table" then Btree.Table else Index); name; table; root = root land 0xffffffff; sql; key }
        | _ -> None)
    | Btree.Table_internal _ | Btree.Index_leaf _ | Btree.Index_internal _ -> None) cells

let same a b = String.lowercase_ascii a = String.lowercase_ascii b

let find_table items name = List.find_opt (fun i -> i.kind = Btree.Table && same i.name name) items

let index_column i =
  match Sql.parse_quiet i.sql with Some (Ast.Create_index x) -> Some x.column | _ -> None

let find_index_on items table column =
  List.find_opt (fun i -> i.kind = Btree.Index && same i.table table
                          && match index_column i with Some c -> same c column | None -> false) items

let columns i = match Sql.parse_quiet i.sql with Some (Ast.Create_table t) -> t.columns | _ -> []

let next_key items = 1 + List.fold_left (fun m i -> max m i.key) 0 items
