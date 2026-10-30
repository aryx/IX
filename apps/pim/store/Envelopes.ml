(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Envelopes.mli *)

type envelope = {
  account : string;
  assigned : Money.cents;
  spent : Money.cents;
  available : Money.cents;
}

let prefix (p : string) (s : string) : bool =
  String.length s >= String.length p && String.sub s 0 (String.length p) = p

let assignment (i : Item.t) : (string * Money.cents) option =
  if not (Item.has_stamp i "budget") then None
  else
    match Money.of_string (Item.field i "amount") with
    | Some c -> Some (Item.field i "envelope", c)
    | None -> None

let envelopes (items : Item.t list) : envelope list =
  let assigned = List.filter_map assignment items in
  let names = List.sort_uniq compare (List.map fst assigned) in
  let txns = List.filter Books.is_transaction items in
  List.map
    (fun account ->
      let a =
        List.fold_left
          (fun s (e, c) -> if e = account then s + c else s)
          0 assigned
      in
      (* what was spent from it: its postings, refunds taken back *)
      let spent =
        List.fold_left
          (fun s i ->
            List.fold_left
              (fun s (p : Books.posting) ->
                if p.account = account then s + p.amount else s)
              s (Books.postings i))
          0 txns
      in
      { account; assigned = a; spent; available = a - spent })
    names

let cash (items : Item.t list) : Money.cents =
  List.fold_left
    (fun s a -> if prefix "Assets:" a then s + Books.balance items a else s)
    0 (Books.accounts items)

let to_assign (items : Item.t list) : Money.cents =
  cash items
  - List.fold_left
      (fun s e -> if e.available > 0 then s + e.available else s)
      0 (envelopes items)

let assign ~(id : string) (today : Civil.date) (envelope : string)
    (c : Money.cents) : Item.t =
  Item.make ~id ~stamps:[ "budget" ]
    [ ("envelope", Books.account_of ~amount:(-1) envelope);
      ("amount", Printf.sprintf "%s%d.%02d" (if c < 0 then "-" else "")
         (abs c / 100) (abs c mod 100));
      ("date", Civil.to_string today) ]
    ""
