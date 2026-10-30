(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Books.mli *)

type posting = { account : string; amount : Money.cents }

(* "Expenses:Groceries  42.17": the account, and its amount if it has
 * one; the last two spaces part them *)
let posting (line : string) : string * Money.cents option =
  let line = String.trim line in
  let n = String.length line in
  let rec find i =
    if i < 0 then None
    else if line.[i] = ' ' && line.[i + 1] = ' ' then Some i
    else find (i - 1)
  in
  match find (n - 2) with
  | Some i -> (
      let account = String.trim (String.sub line 0 i) in
      match Money.of_string (String.trim (String.sub line i (n - i))) with
      | Some c -> (account, Some c)
      | None -> (line, None))
  | None -> (line, None)

let postings (i : Item.t) : posting list =
  let ps = List.map posting (Mail.get_all i "posting") in
  let known =
    List.fold_left
      (fun s (_, a) -> match a with Some c -> s + c | None -> s)
      0 ps
  in
  List.map
    (fun (account, a) ->
      { account; amount = (match a with Some c -> c | None -> -known) })
    ps

let is_transaction (i : Item.t) : bool =
  Mail.get_all i "posting" <> []
  && ((not (Item.has_stamp i "task")) || Item.field i "done" <> "")

let accounts (items : Item.t list) : string list =
  List.sort_uniq compare
    (List.concat_map
       (fun i ->
         if is_transaction i then List.map (fun p -> p.account) (postings i)
         else [])
       items)

let balance (items : Item.t list) (account : string) : Money.cents =
  List.fold_left
    (fun s i ->
      if not (is_transaction i) then s
      else
        List.fold_left
          (fun s p -> if p.account = account then s + p.amount else s)
          s (postings i))
    0 items

let prefixed (p : string) (s : string) : bool =
  String.length s > String.length p
  && String.sub s 0 (String.length p) = p

let category (account : string) : string =
  let cut p =
    String.sub account (String.length p)
      (String.length account - String.length p)
  in
  if prefixed "Expenses:" account then cut "Expenses:"
  else if prefixed "Income:" account then cut "Income:"
  else "[" ^ account ^ "]"

let account_of ~(amount : Money.cents) (c : string) : string =
  let c = String.trim c in
  let n = String.length c in
  if n >= 2 && c.[0] = '[' && c.[n - 1] = ']' then String.sub c 1 (n - 2)
  else if String.contains c ':' then c
  else if c = "" then if amount < 0 then "Expenses:Unknown" else "Income:Unknown"
  else if amount < 0 then "Expenses:" ^ c
  else "Income:" ^ c

(* the day it is in the books: date:, else a bill's done: *)
let day (i : Item.t) : Civil.date option =
  match Search.date (Item.field i "date") with
  | Some d -> Some d
  | None -> Search.date (Item.field i "done")

let status (i : Item.t) : Ledger.status =
  match Item.field i "cleared" with
  | "R" -> Reconciled
  | "*" -> Cleared
  | _ -> Open

let register (items : Item.t list) (account : string) :
    (Item.t * Ledger.txn) list =
  let lines =
    List.filter_map
      (fun i ->
        if not (is_transaction i) then None
        else
          let ps = postings i in
          match (List.partition (fun p -> p.account = account) ps, day i) with
          | ([], _), _ | _, None -> None
          | (mine, others), Some date ->
              let category =
                match others with
                | [ p ] -> category p.account
                | [] -> ""
                | _ -> "--Split--"
              in
              let title =
                match Item.field i "payee" with "" -> Item.field i "title" | p -> p
              in
              Some
                ( i,
                  ({ date; num = Item.field i "num"; payee = title; category;
                     memo = Item.field i "memo";
                     amount = List.fold_left (fun s p -> s + p.amount) 0 mine;
                     status = status i } : Ledger.txn) ))
      items
  in
  List.stable_sort
    (fun (_, (a : Ledger.txn)) (_, (b : Ledger.txn)) ->
      compare (Civil.days_from_civil a.date) (Civil.days_from_civil b.date))
    lines

let with_status (s : Ledger.status) (i : Item.t) : Item.t =
  match s with
  | Open -> Mail.remove "cleared" i
  | Cleared -> Mail.set "cleared" "*" i
  | Reconciled -> Mail.set "cleared" "R" i

let of_txn ~(id : string) ~(account : string) (t : Ledger.txn) : Item.t =
  let opt name v = if v = "" then [] else [ (name, v) ] in
  with_status t.status
    (Item.make ~id ~stamps:[ "money" ]
       (List.concat
          [ [ ("date", Civil.to_string t.date) ]; opt "num" t.num;
            [ ("payee", t.payee) ]; opt "memo" t.memo;
            [ ("posting", account_of ~amount:t.amount t.category ^ "  "
                          ^ Money.to_string (-t.amount));
              ("posting", account) ] ])
       "")

let fresh (register : Ledger.txn list) (txns : Ledger.txn list) :
    Ledger.txn list =
  let near (a : Ledger.txn) (b : Ledger.txn) =
    a.amount = b.amount
    && abs (Civil.days_from_civil a.date - Civil.days_from_civil b.date) <= 3
  in
  (* (each line of the register matches one of the file's at most) *)
  let rec go left acc l =
    match l with
    | [] -> List.rev acc
    | t :: rest -> (
        match List.partition (near t) left with
        | _ :: others, kept -> go (others @ kept) acc rest
        | [], _ -> go left (t :: acc) rest)
  in
  go register [] txns

let report (items : Item.t list) ~(year : int) ~(month : int) :
    (string * Money.cents) list =
  let sums = Hashtbl.create 16 in
  List.iter
    (fun i ->
      match day i with
      | Some d when is_transaction i && d.year = year && d.month = month ->
          List.iter
            (fun p ->
              if prefixed "Expenses:" p.account || prefixed "Income:" p.account
              then
                let sum =
                  match Hashtbl.find_opt sums p.account with
                  | Some s -> s
                  | None -> 0
                in
                Hashtbl.replace sums p.account (p.amount + sum))
            (postings i)
      | _ -> ())
    items;
  List.sort compare (Hashtbl.fold (fun a s acc -> (a, s) :: acc) sums [])
