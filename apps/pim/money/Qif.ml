(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's appkits/money/Qif.ml
 * (plan_pim.md, stage 6); Option.value a match *)

(* See Qif.mli *)

let write (txns : Ledger.txn list) : string =
  let record (t : Ledger.txn) =
    let field code v = if v = "" then [] else [ code ^ v ] in
    List.concat
      [
        [ "D" ^ Ledger.date_to_string t.date; "T" ^ Money.to_string t.amount ];
        field "N" t.num; field "P" t.payee; field "L" t.category; field "M" t.memo;
        (match t.status with Ledger.Open -> [] | Ledger.Cleared -> [ "C*" ] | Ledger.Reconciled -> [ "CX" ]);
        [ "^" ];
      ]
  in
  String.concat "\n" ("!Type:Bank" :: List.concat_map record txns) ^ "\n"

(* a record's fields, by their letter *)
let of_fields (n : int) (fields : (char * string) list) : (Ledger.txn, string) result =
  let get c = match List.assoc_opt c fields with Some v -> v | None -> "" in
  match (Option.bind (List.assoc_opt 'D' fields) Ledger.date_of_string, Option.bind (List.assoc_opt 'T' fields) Money.of_string) with
  | Some date, Some amount ->
      let status = match get 'C' with "*" | "c" -> Ledger.Cleared | "X" | "R" -> Ledger.Reconciled | _ -> Ledger.Open in
      Ok { Ledger.date; num = get 'N'; payee = get 'P'; category = get 'L'; memo = get 'M'; amount; status }
  | _ -> Error (Printf.sprintf "record %d: no valid date or amount" n)

let read (s : string) : (Ledger.txn list, string) result =
  let lines = List.map String.trim (String.split_on_char '\n' s) in
  (* records, each its fields in reverse; the last one's may be empty *)
  let rec go n fields acc = function
    | [] -> if fields = [] then Ok (List.rev acc) else Result.map (fun t -> List.rev (t :: acc)) (of_fields n fields)
    | "^" :: rest -> ( match of_fields n fields with Ok t -> go (n + 1) [] (t :: acc) rest | Error e -> Error e)
    | line :: rest when line = "" || line.[0] = '!' -> go n fields acc rest
    | line :: rest -> go n ((line.[0], String.sub line 1 (String.length line - 1)) :: fields) acc rest
  in
  go 1 [] [] lines
