(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Money_window.mli *)

open Playground
open Pim_look

type caps = Mail_window.caps

(*****************************************************************************)
(* The model *)
(*****************************************************************************)

type mode =
  | Register
  | Report
  | Envelopes
  | Assigning
  | Form
  | Statement
  | Reconciling

(* a new line, as typed in the register's columns *)
type form = {
  date : string;
  num : string;
  payee : string;
  category : string;
  payment : string;
  deposit : string;
}

type model = {
  accounts : string list; (* Assets: and Liabilities:, Checking first *)
  account : string;
  (* the register's lines, each with the balance after it *)
  lines : (Item.t * Ledger.txn * Money.cents) list;
  report : (string * Money.cents) list; (* the month's *)
  envelopes : Envelopes.envelope list;
  to_assign : Money.cents;
  selected : int;
  mode : mode;
  form : form;
  statement : Money.cents; (* the bank's ending balance, reconciling *)
  today : Civil.date;
  field : string; (* the statement's balance, typed *)
  status : string;
  held : string Set_.t;
}

let store (caps : caps) : Items.t = Items.at (Items.place caps)

let checking = "Assets:Checking"

let blank (m : model) : form =
  { date = Civil.to_string m.today; num = ""; payee = ""; category = "";
    payment = ""; deposit = "" }

let load (caps : caps) (m : model) : model =
  let items = Items.all caps (store caps) in
  let own a =
    let p s =
      String.length a > String.length s
      && String.sub a 0 (String.length s) = s
    in
    p "Assets:" || p "Liabilities:"
  in
  let accounts =
    checking :: List.filter (fun a -> own a && a <> checking) (Books.accounts items)
  in
  let reg = Books.register items m.account in
  let bal = Ledger.balances (List.map snd reg) in
  let lines = List.map2 (fun (i, _) (t, b) -> (i, t, b)) reg bal in
  { m with accounts; lines;
    report = Books.report items ~year:m.today.year ~month:m.today.month;
    envelopes = Envelopes.envelopes items;
    to_assign = Envelopes.to_assign items;
    selected = max 0 (min m.selected (List.length lines - 1)) }

let initial (caps : caps) (flags : Playground.flags) : model =
  let today =
    match List.assoc_opt "today" flags with
    | Some d -> (
        match Search.date d with Some d -> d | None -> When.today caps)
    | None -> When.today caps
  in
  let m =
    { accounts = []; account = checking; lines = []; report = [];
      envelopes = []; to_assign = 0;
      selected = max_int; mode = Register;
      form = { date = ""; num = ""; payee = ""; category = ""; payment = "";
               deposit = "" };
      statement = 0; today; field = ""; status = ""; held = Set_.empty }
  in
  load caps { m with form = blank m }

let refresh (caps : caps) (keys : string Set_.t) (m : model) : model =
  load caps { m with held = keys }

(* the line [id] selected, in the register of the first own account it
 * posts to *)
let show (caps : caps) (m : model) (id : string) : model =
  match Items.find caps (store caps) id with
  | None -> { m with status = id ^ ": not in the store" }
  | Some i -> (
      let m = load caps { m with mode = Register } in
      let posts =
        List.map (fun (p : Books.posting) -> p.account) (Books.postings i)
      in
      match List.find_opt (fun a -> List.mem a posts) m.accounts with
      | None -> { m with status = id ^ ": in no account's register" }
      | Some account ->
          let m = load caps { m with account } in
          let rec index k l =
            match l with
            | [] -> m.selected
            | (j, _, _) :: rest ->
                if Item.id j = id then k else index (k + 1) rest
          in
          { m with selected = index 0 m.lines; status = "" })

(*****************************************************************************)
(* What the keys and the menus do *)
(*****************************************************************************)

type command =
  | New_line
  | Record
  | Cancel
  | Clear
  | Reconcile_
  | Finish
  | Next
  | Previous
  | Next_account
  | Report_
  | Envelopes_
  | Assign

let menus : (string * (string * command) list) list =
  [ ( "Register",
      [ ("New Line  (n)", New_line); ("Record  (Enter)", Record);
        ("Cancel  (Esc)", Cancel); ("Mark Cleared  (c)", Clear);
        ("Next  (j)", Next); ("Previous  (k)", Previous) ] );
    ( "Account",
      [ ("Reconcile...  (r)", Reconcile_); ("Finish  (f)", Finish);
        ("Next Account  (Tab)", Next_account);
        ("Categories", Report_); ("Envelopes", Envelopes_);
        ("Assign...  (a)", Assign) ] ) ]

let made = ref 0

(* the form a line in the books, its amount the deposit less the
 * payment *)
let record (caps : caps) (m : model) : model =
  let f = m.form in
  let amount s = if String.trim s = "" then Some 0 else Money.of_string s in
  match (Search.date f.date, amount f.payment, amount f.deposit) with
  | None, _, _ -> { m with status = f.date ^ ": not a date (2026-10-30)" }
  | _, None, _ | _, _, None -> { m with status = "an amount: 42.17" }
  | Some date, Some pay, Some dep ->
      if String.trim f.payee = "" || dep - pay = 0 then
        { m with status = "a payee and an amount" }
      else begin
        incr made;
        let id = Printf.sprintf "money:%.0f.%d" (Unix.gettimeofday ()) !made in
        let t : Ledger.txn =
          { date; num = String.trim f.num; payee = String.trim f.payee;
            category = String.trim f.category; memo = ""; amount = dep - pay;
            status = Open }
        in
        Items.save caps (store caps) (Books.of_txn ~id ~account:m.account t);
        let m = load caps { m with mode = Register; selected = max_int } in
        { m with form = blank m; status = "recorded: " ^ t.payee }
      end

(* the selected line's cleared mark, ticked or not (a reconciled line
 * stays so) *)
let clear (caps : caps) (m : model) : model =
  match List.nth_opt m.lines m.selected with
  | Some (i, t, _) when t.status <> Reconciled ->
      let s : Ledger.status = if t.status = Cleared then Open else Cleared in
      Items.save caps (store caps) (Books.with_status s i);
      load caps m
  | _ -> m

let txns (m : model) : Ledger.txn list = List.map (fun (_, t, _) -> t) m.lines

let finish (caps : caps) (m : model) : model =
  if Reconcile.difference ~statement:m.statement (txns m) <> 0 then
    { m with status = "the difference is not zero" }
  else begin
    List.iter
      (fun (i, (t : Ledger.txn), _) ->
        if t.status = Cleared then
          Items.save caps (store caps) (Books.with_status Reconciled i))
      m.lines;
    load caps { m with mode = Register; status = "reconciled" }
  end

let command (caps : caps) (m : model) (c : command) : model =
  match c with
  | New_line -> { m with mode = Form; form = blank m; status = "" }
  | Record -> if m.mode = Form then record caps m else m
  | Cancel -> { m with mode = Register; status = "" }
  | Clear -> clear caps m
  | Reconcile_ -> { m with mode = Statement; field = ""; status = "" }
  | Finish -> if m.mode = Reconciling then finish caps m else m
  | Next -> { m with selected = min (List.length m.lines - 1) (m.selected + 1) }
  | Previous -> { m with selected = max 0 (m.selected - 1) }
  | Next_account -> (
      (* the accounts, then the report, the envelopes, the first again *)
      if m.mode = Report then { m with mode = Envelopes }
      else if m.mode = Envelopes then
        load caps
          { m with account = checking; mode = Register; selected = max_int }
      else
        let rec after l =
          match l with
          | a :: (b :: _ as rest) -> if a = m.account then Some b else after rest
          | _ -> None
        in
        match after m.accounts with
        | Some a ->
            load caps
              { m with account = a; mode = Register; selected = max_int }
        | None -> { m with mode = Report })
  | Report_ -> { m with mode = Report }
  | Envelopes_ -> { m with mode = Envelopes }
  | Assign -> { m with mode = Assigning; field = ""; status = "" }

(* the register's columns, from the text's left edge: where each
 * begins, or ends for the amounts (right-aligned) *)
let col_num = 124.
let col_payee = 172.
let col_category = 336.
let end_payment = 574.
let end_deposit = 668.
let col_c = 682.

(* the form's fields, in the columns, at the window's foot *)
let form_y (computer : computer) : float = (-.computer.screen.height /. 2.) +. 60.

let form_box (computer : computer) (left : float) (right : float) : Widget.box =
  let a = area computer in
  { Widget.x = a.x0 +. ((left +. right) /. 2.); y = form_y computer;
    w = right -. left -. 6.; h = 26. }

(* 2000.00: an amount in a field, no commas (they take its room) *)
let plain (c : Money.cents) : string = Printf.sprintf "%d.%02d" (c / 100) (c mod 100)

let writing (caps : caps) (computer : computer) (m : model)
    (menu : command option) (key : string -> bool) : model =
  let f = m.form in
  let field l r v = Gui.field_in ~enabled:true computer (form_box computer l r) v in
  let date = field (-4.) col_num f.date in
  let num = field col_num col_payee f.num in
  let payee = field col_payee col_category f.payee in
  let category = field col_category (end_payment -. 100.) f.category in
  let payment = field (end_payment -. 100.) end_payment f.payment in
  let deposit = field end_payment end_deposit f.deposit in
  let a = area computer in
  let record_ =
    Gui.button_in ~enabled:true computer
      { Widget.x = a.x0 +. a.room -. 50.; y = form_y computer; w = 96.; h = 30. }
      "Record"
  in
  let f' = { date; num; payee; category; payment; deposit } in
  (* QuickFill: a payee typed, the rest of their last line copied *)
  let f' =
    if
      f'.payee <> f.payee && f.category = "" && f.payment = "" && f.deposit = ""
    then
      match Ledger.quickfill (txns m) f'.payee with
      | Some t ->
          { f' with
            payee = t.payee; category = t.category;
            payment = (if t.amount < 0 then plain (-t.amount) else "");
            deposit = (if t.amount > 0 then plain t.amount else "") }
      | None -> f'
    else f'
  in
  let m = { m with form = f' } in
  match menu with
  | Some c -> command caps m c
  | None ->
      if record_ || key "Enter" then record caps m
      else if key "Escape" then command caps m Cancel
      else m

let update (caps : caps) (computer : computer) (m : model) : model * go option =
  let keys = computer.keyboard.keys in
  let pressed name = Set_.mem name keys && not (Set_.mem name m.held) in
  let menu = chosen computer ~first:1 menus in
  let m =
    match m.mode with
    | Form -> writing caps computer m menu pressed
    | Statement ->
        if pressed "Escape" then { m with mode = Register; field = "" }
        else if pressed "Enter" then
          match Money.of_string m.field with
          | Some c ->
              { m with mode = Reconciling; statement = c; field = "";
                status = "" }
          | None ->
              { m with mode = Register; status = m.field ^ ": not an amount" }
        else if pressed "Backspace" then { m with field = without_last m.field }
        else { m with field = m.field ^ printable computer.keyboard.typed }
    | Assigning ->
        (* "Groceries 400": an envelope's name, then the amount *)
        if pressed "Escape" then { m with mode = Envelopes; field = "" }
        else if pressed "Enter" then
          let words = String.split_on_char ' ' (String.trim m.field) in
          match List.rev words with
          | amount :: (_ :: _ as name) -> (
              match Money.of_string amount with
              | Some c ->
                  incr made;
                  let id =
                    Printf.sprintf "budget:%.0f.%d" (Unix.gettimeofday ()) !made
                  in
                  let name = String.concat " " (List.rev name) in
                  Items.save caps (store caps)
                    (Envelopes.assign ~id m.today name c);
                  load caps
                    { m with mode = Envelopes; field = "";
                      status = Money.to_string c ^ " to " ^ name }
              | None ->
                  { m with mode = Envelopes;
                    status = amount ^ ": not an amount" })
          | _ -> { m with mode = Envelopes; status = "an envelope and an amount" }
        else if pressed "Backspace" then { m with field = without_last m.field }
        else { m with field = m.field ^ printable computer.keyboard.typed }
    | (Register | Report | Envelopes | Reconciling) when Gui.modal () -> m
    | Register | Report | Envelopes | Reconciling -> (
        let key =
          if pressed "j" || pressed "ArrowDown" then Some Next
          else if pressed "k" || pressed "ArrowUp" then Some Previous
          else if pressed "n" then Some New_line
          else if pressed "c" || (m.mode = Reconciling && pressed "space") then
            Some Clear
          else if pressed "r" then Some Reconcile_
          else if pressed "f" then Some Finish
          else if pressed "Escape" then Some Cancel
          else if pressed "Tab" then Some Next_account
          else if pressed "a" then Some Assign
          else None
        in
        (* the mouse: an account, the categories, the envelopes of the
         * sidebar; a line of the register (under its head, row 0) *)
        let n = List.length m.accounts in
        let line =
          match row_click computer with
          | Some k when k > 0 && (m.mode = Register || m.mode = Reconciling) ->
              let foot = if m.mode = Reconciling then 7 else 3 in
              let fits =
                int_of_float
                  ((computer.screen.height -. menu_bar -. bar -. 40.) /. row)
                - foot
              in
              let i = max 0 (m.selected - fits + 1) + k - 1 in
              if i < List.length m.lines then Some i else None
          | _ -> None
        in
        match (menu, key, sidebar_click computer, line) with
        | Some c, _, _, _ | None, Some c, _, _ -> command caps m c
        | None, None, Some k, _ when k < n ->
            load caps
              { m with account = List.nth m.accounts k; mode = Register;
                selected = max_int }
        | None, None, Some k, _ when k = n -> { m with mode = Report }
        | None, None, Some k, _ when k = n + 1 -> { m with mode = Envelopes }
        | None, None, _, Some i -> { m with selected = i }
        | None, None, _, _
          when (m.mode = Register || m.mode = Reconciling)
               && wheel computer <> 0 ->
            (* (selected is max_int at first: the last line) *)
            let n = List.length m.lines in
            { m with selected = moved (min m.selected (n - 1)) (wheel computer) n }
        | None, None, _, _ -> m)
  in
  ({ m with held = keys }, None)

(*****************************************************************************)
(* The picture *)
(*****************************************************************************)

(* "Checking" of "Assets:Checking" *)
let short (account : string) : string =
  match String.index_opt account ':' with
  | Some i -> String.sub account (i + 1) (String.length account - i - 1)
  | None -> account

let hint_text (h : Reconcile.hint) : string =
  let line (t : Ledger.txn) =
    t.payee ^ " " ^ Money.to_string t.amount ^ " (" ^ Civil.to_string t.date ^ ")"
  in
  match h with
  | Missing l ->
      "not ticked, on the statement? " ^ String.concat ", " (List.map line l)
  | Extra t -> "ticked, not on the statement? " ^ line t
  | Wrong_sign t -> "entered with the wrong sign? " ^ line t
  | Transposed (t, c) ->
      "two digits swapped? " ^ line t ^ ", which should say " ^ Money.to_string c
  | Nine -> "a multiple of 9: two digits swapped somewhere"

let view (computer : computer) (m : model) : shape list =
  let a = area computer in
  let x0 = a.x0 in
  let balance =
    match List.rev m.lines with (_, _, b) :: _ -> b | [] -> 0
  in
  let title_ =
    match m.mode with
    | Statement -> "the statement's ending balance: " ^ m.field ^ "_"
    | Report ->
        Printf.sprintf "Categories, %s %d" (Civil.month_name m.today.month)
          m.today.year
    | Reconciling -> "Reconcile " ^ short m.account
    | Envelopes -> "Envelopes"
    | Assigning -> "assign: " ^ m.field ^ "_   (Groceries 400)"
    | Register | Form -> short m.account
  in
  let right =
    if m.status <> "" then m.status
    else if m.mode = Report then ""
    else if m.mode = Envelopes || m.mode = Assigning then
      "to assign " ^ Money.to_string m.to_assign
    else "balance " ^ Money.to_string balance
  in
  let amount_at (right_edge : float) (y : float) (s : string) (color : color) =
    text color ~bold:false ~room:(width s +. 4.) (x0 +. right_edge -. width s) y s
  in
  let main =
    match m.mode with
    | Report ->
        let total = List.fold_left (fun s (_, c) -> s + c) 0 m.report in
        if m.report = [] then
          [ text grey ~bold:false ~room:a.room x0 (row_y a 0)
              "Nothing this month." ]
        else
          List.concat
            (List.mapi
               (fun k (acct, c) ->
                 let y = row_y a k in
                 [ text ink ~bold:false ~room:300. x0 y acct;
                   amount_at 400. y (Money.to_string (-c))
                     (if c > 0 then red else ink) ])
               m.report)
          @ [ text ink ~bold:true ~room:300. x0 (row_y a (List.length m.report + 1))
                "what is left";
              amount_at 400. (row_y a (List.length m.report + 1))
                (Money.to_string (-total)) ink ]
    | Envelopes | Assigning ->
        let head_y = row_y a 0 in
        let money x y s c = amount_at x y (Money.to_string s) c in
        [ text grey ~bold:false ~room:200. x0 head_y "Envelope";
          amount_at 400. head_y "Assigned" grey;
          amount_at 520. head_y "Spent" grey;
          amount_at 640. head_y "Available" grey ]
        @ (if m.envelopes = [] then
             [ text grey ~bold:false ~room:a.room x0 (row_y a 1)
                 "No envelopes: a assigns money to one (Groceries 400)." ]
           else [])
        @ List.concat
            (List.mapi
               (fun k (e : Envelopes.envelope) ->
                 let y = row_y a (k + 1) in
                 [ text ink ~bold:false ~room:250. x0 y
                     (Books.category e.account);
                   money 400. y e.assigned ink; money 520. y e.spent ink;
                   money 640. y e.available
                     (if e.available < 0 then red else ink) ])
               m.envelopes)
        @
        (* every dollar a job when it is 0 *)
        let y = row_y a (List.length m.envelopes + 2) in
        [ text ink ~bold:true ~room:250. x0 y "to assign";
          money 640. y m.to_assign (if m.to_assign < 0 then red else ink) ]
    | Register | Form | Statement | Reconciling ->
        let head_y = row_y a 0 in
        let head =
          [ text grey ~bold:false ~room:90. x0 head_y "Date";
            text grey ~bold:false ~room:40. (x0 +. col_num) head_y "Num";
            text grey ~bold:false ~room:170. (x0 +. col_payee) head_y "Payee";
            text grey ~bold:false ~room:170. (x0 +. col_category) head_y "Category";
            amount_at end_payment head_y "Payment" grey;
            amount_at end_deposit head_y "Deposit" grey;
            text grey ~bold:false ~room:20. (x0 +. col_c) head_y "C";
            amount_at a.room head_y "Balance" grey ]
        in
        let foot = if m.mode = Reconciling then 7 else 3 in
        let fits =
          int_of_float ((computer.screen.height -. menu_bar -. bar -. 40.) /. row)
          - foot
        in
        let first = max 0 (m.selected - fits + 1) in
        let rows =
          List.concat
            (List.mapi
               (fun k (_, (t : Ledger.txn), b) ->
                 if k < first || k >= first + fits then []
                 else
                   let y = row_y a (k - first + 1) in
                   (if k = m.selected && m.mode <> Form then [ selected a y ]
                    else [])
                   @ [ text ink ~bold:false ~room:(col_num -. 4.) x0 y
                         (Civil.to_string t.date);
                       text ink ~bold:false ~room:44. (x0 +. col_num) y t.num;
                       text ink ~bold:false ~room:(col_category -. col_payee -. 6.)
                         (x0 +. col_payee) y t.payee;
                       text grey ~bold:false
                         ~room:(end_payment -. col_category -. 90.)
                         (x0 +. col_category) y t.category ]
                   @ (if t.amount < 0 then
                        [ amount_at end_payment y (Money.to_string (-t.amount)) ink ]
                      else
                        [ amount_at end_deposit y (Money.to_string t.amount) ink ])
                   @ [ text ink ~bold:true ~room:20. (x0 +. col_c) y
                         (match t.status with
                         | Open -> ""
                         | Cleared -> "*"
                         | Reconciled -> "R");
                       amount_at a.room y (Money.to_string b)
                         (if b < 0 then red else ink) ])
               m.lines)
        in
        let empty =
          if m.lines = [] then
            [ text grey ~bold:false ~room:a.room x0 (row_y a 1)
                "No lines yet: n writes one (QuickFill: a payee's last line)." ]
          else []
        in
        let reconciling =
          if m.mode <> Reconciling then []
          else
            let t = txns m in
            let d = Reconcile.difference ~statement:m.statement t in
            let say k s c =
              text c ~bold:(k = 0) ~room:a.room x0
                ((-.computer.screen.height /. 2.) +. 150.
                -. (float_of_int k *. 24.))
                s
            in
            say 0
              (Printf.sprintf "statement %s   cleared %s   difference %s"
                 (Money.to_string m.statement)
                 (Money.to_string (Reconcile.cleared t))
                 (Money.to_string d))
              (if d = 0 then blue else ink)
            :: List.mapi
                 (fun k h -> say (k + 1) (hint_text h) grey)
                 (List.filteri
                    (fun k _ -> k < 3)
                    (Reconcile.hints ~statement:m.statement t))
            @ [ say 5
                  (if d = 0 then "f: finish, the ticked lines reconciled"
                   else "space or c ticks a line the statement lists")
                  grey ]
        in
        head @ rows @ empty @ reconciling
  in
  (rectangle white computer.screen.width computer.screen.height
   :: title_bar computer title_ right)
  @ sidebar a
      (List.map
         (fun acct ->
           ( short acct,
             acct = m.account
             && not (List.mem m.mode [ Report; Envelopes; Assigning ]) ))
         m.accounts
      @ [ ("Categories", m.mode = Report);
          ("Envelopes", m.mode = Envelopes || m.mode = Assigning) ])
  @ main
