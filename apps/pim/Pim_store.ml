(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Pim_store.mli *)

type caps =
  < Cap.open_in ; Cap.open_out ; Cap.readdir ; Cap.env ; Cap.stdout
  ; Cap.stderr >

let fail (caps : < Cap.stderr ; .. >) (why : string) : Exit.t =
  Console.eprint caps (why ^ "\n");
  Exit.Err why

let store (caps : < Cap.env ; .. >) : Items.t = Items.at (Items.place caps)

let line (caps : < Cap.stdout ; .. >) (prefix : string) (item : Item.t) :
    unit =
  Console.print caps
    (Printf.sprintf "%s%-24s %-16s %s\n" prefix (Item.id item)
       (String.concat " " (Item.stamps item))
       (Search.title item))

(*****************************************************************************)
(* Every item *)
(*****************************************************************************)

let search (caps : < caps ; .. >) (query : string) : Exit.t =
  List.iter (line caps "") (Search.search query (Items.all caps (store caps)));
  Exit.OK

(* show: the item's file, and its links both ways *)
let show (caps : < caps ; .. >) (id : string) : Exit.t =
  match Items.find caps (store caps) id with
  | None -> fail caps (id ^ ": no such item")
  | Some item ->
      let items = Items.all caps (store caps) in
      Console.print caps (String.trim (Item.to_string item) ^ "\n");
      let say heading l =
        if l <> [] then begin
          Console.print caps ("\n" ^ heading ^ "\n");
          List.iter
            (fun (field, i) ->
              line caps (if field = "" then "  " else "  " ^ field ^ ": ") i)
            l
        end
      in
      (* (a person's page: the mail with them first, People) *)
      if Item.has_stamp item "contact" then
        say "mail:" (List.map (fun m -> ("", m)) (People.with_ items item));
      say "links:" (Links.links items item);
      say "linked from:" (Links.backlinks items item);
      Exit.OK

let people (caps : < caps ; .. >) : Exit.t =
  List.iter (line caps "") (People.contacts (Items.all caps (store caps)));
  Exit.OK

let assignments (l : string list) : (string * string) list option =
  let one a =
    match String.index_opt a '=' with
    | Some i when i > 0 ->
        Some (String.sub a 0 i, String.sub a (i + 1) (String.length a - i - 1))
    | _ -> None
  in
  let l' = List.filter_map one l in
  if List.length l' = List.length l then Some l' else None

(* due= and until= as words: "friday" is 2026-10-30 (When) *)
let days (today : Civil.date) (fields : (string * string) list) :
    ((string * string) list, string) result =
  List.fold_right
    (fun (name, v) acc ->
      match acc with
      | Error e -> Error e
      | Ok l ->
          if (name <> "due" && name <> "until") || v = "" then Ok ((name, v) :: l)
          else (
            match When.parse ~today v with
            | Some d -> Ok ((name, Mail_sync.day d) :: l)
            | None -> Error (v ^ ": not a day (friday, in 3 days, nov 5)")))
    fields (Ok [])

let add (caps : < caps ; .. >) (id : string) (fields : (string * string) list)
    : Exit.t =
  match (Items.find caps (store caps) id, String.index_opt id ':') with
  | Some _, _ -> fail caps (id ^ ": already an item")
  | None, None -> fail caps (id ^ ": an id is kind:name (task:pay-rent)")
  | None, Some i ->
      let stamps =
        match List.assoc_opt "stamp" fields with
        | Some s -> String.split_on_char ' ' s
        | None -> [ String.sub id 0 i ]
      in
      let fields = List.filter (fun (n, _) -> n <> "stamp") fields in
      Items.save caps (store caps) (Item.make ~id ~stamps fields "");
      Exit.OK

let set (caps : < caps ; .. >) (id : string) (fields : (string * string) list)
    : Exit.t =
  match Items.find caps (store caps) id with
  | None -> fail caps (id ^ ": no such item")
  | Some _ when List.mem_assoc "id" fields -> fail caps "id: an item's name"
  | Some item ->
      let item =
        List.fold_left
          (fun item (name, v) ->
            if v = "" then Mail.remove name item else Mail.set name v item)
          item fields
      in
      Items.save caps (store caps) item;
      Exit.OK

(*****************************************************************************)
(* The calendar and the day *)
(*****************************************************************************)

let event (caps : < caps ; .. >) (today : Civil.date) (words : string) :
    Exit.t =
  let people = People.contacts (Items.all caps (store caps)) in
  let e = Capture.event ~today ~people words in
  let id = Printf.sprintf "event:%.0f" (Unix.gettimeofday ()) in
  let item = Capture.to_item ~id e in
  Items.save caps (store caps) item;
  Console.print caps (String.trim (Item.to_string item) ^ "\n");
  Exit.OK

let import (caps : < caps ; .. >) (account : string) (file : string) : Exit.t
    =
  let text = FS.read caps (Fpath.v file) in
  if Filename.check_suffix (String.lowercase_ascii file) ".qif" then
    match Qif.read text with
    | Error e -> fail caps (file ^ ": " ^ e)
    | Ok txns ->
        let register =
          List.map snd (Books.register (Items.all caps (store caps)) account)
        in
        List.iteri
          (fun k (t : Ledger.txn) ->
            let id = Printf.sprintf "money:%.0f.%d" (Unix.gettimeofday ()) k in
            let item = Books.of_txn ~id ~account t in
            Items.save caps (store caps) item;
            line caps "" item)
          (Books.fresh register txns);
        Exit.OK
  else begin
    let events = Events.of_ics ~message:"" text in
    List.iter (Items.save caps (store caps)) events;
    List.iter (line caps "") events;
    Exit.OK
  end

let today (caps : < caps ; .. >) (today : Civil.date) : Exit.t =
  let items = Items.all caps (store caps) in
  let t = Civil.days_from_civil today in
  let day (i : Item.t) =
    match Search.day i with Some d -> Civil.days_from_civil d | None -> max_int
  in
  let later (i : Item.t) =
    match Search.date (Item.field i "until") with
    | Some d -> Civil.days_from_civil d > t
    | None -> false
  in
  let to_do =
    List.filter
      (fun i ->
        Item.has_stamp i "task" && Item.field i "done" = "" && not (later i))
      items
  in
  let say (what : string) (i : Item.t) =
    Console.print caps (Printf.sprintf "%-10s %s\n" what (Search.title i))
  in
  Console.print caps (Mail_sync.day today ^ "\n");
  List.iter
    (fun (_, time, i) ->
      say (match time with Some m -> Events.clock m | None -> "all day") i)
    (Events.between items ~from:today ~upto:today);
  List.iter (say "late") (List.filter (fun i -> day i < t) to_do);
  List.iter (say "due") (List.filter (fun i -> day i = t) to_do);
  List.iter (fun i -> if Item.field i "woke" <> "" then say "back" i) items;
  Exit.OK

(*****************************************************************************)
(* The money *)
(*****************************************************************************)

let register (caps : < caps ; .. >) (account : string) : Exit.t =
  let reg = Books.register (Items.all caps (store caps)) account in
  List.iter2
    (fun (_, (t : Ledger.txn)) (_, b) ->
      Console.print caps
        (Printf.sprintf "%s %-4s %-18s %-18s %10s %1s %10s\n"
           (Civil.to_string t.date) t.num t.payee t.category
           (Money.to_string t.amount)
           (match t.status with Open -> "" | Cleared -> "*" | Reconciled -> "R")
           (Money.to_string b)))
    reg
    (Ledger.balances (List.map snd reg));
  Exit.OK

let balance (caps : < caps ; .. >) : Exit.t =
  let items = Items.all caps (store caps) in
  List.iter
    (fun a ->
      Console.print caps
        (Printf.sprintf "%12s  %s\n" (Money.to_string (Books.balance items a)) a))
    (Books.accounts items);
  Exit.OK
