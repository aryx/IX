(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Mail_window.mli *)

open Playground
open Pim_look
open Mail_model

type caps = Mail_model.caps
type model = Mail_model.model

let initial = Mail_model.initial
let refresh = Mail_model.refresh

(*****************************************************************************)
(* What the keys and the menus do *)
(*****************************************************************************)

let current (m : model) : Imap.summary list =
  match List.nth_opt m.conversations m.selected with Some c -> c | None -> []

(* [f] in a session, its error the status *)
let online (caps : caps) (m : model) (password : string)
    (f : Imap.t -> ('a, string) result) : ('a, string) result =
  Mail_sync.session caps m.server ~user:m.account ~password ~mailbox:m.mailbox f

(* the conversation opened: its texts from the server (and so the
 * cache) when the password is known, from the cache else *)
let open_ (caps : caps) (m : model) : model =
  let messages = List.rev (current m) in
  let cached (s : Imap.summary) = Items.cached caps (store caps) s.msgid in
  let texts =
    match m.password with
    | None -> Ok (List.map (fun s -> (s, cached s)) messages)
    | Some p ->
        online caps m p (fun t ->
            Ok
              (List.map
                 (fun (s : Imap.summary) ->
                   match
                     Mail_sync.message caps (store caps) t ~account:m.account
                       ~mailbox:m.mailbox s.uid
                   with
                   | Ok text -> (s, Some text)
                   | Error _ -> (s, cached s))
                 messages))
  in
  match texts with
  | Error e -> { m with status = e }
  | Ok reading ->
      let missing = List.exists (fun (_, t) -> t = None) reading in
      (* (back from a snooze, and now seen: in its place again) *)
      List.iter
        (fun (s : Imap.summary) ->
          match Items.find caps (store caps) (Mail_item.id s) with
          | Some i when Item.field i "woke" <> "" ->
              Items.save caps (store caps) (Mail.remove "woke" i)
          | _ -> ())
        messages;
      let m = load caps m in
      {
        m with
        reading;
        scroll = 0;
        mode = Reading;
        status = (if missing then "g: get the mail to read it all" else "");
      }

let run (caps : caps) (m : model) (action : action) : model =
  match m.password with
  | None -> { m with mode = Asking Password; field = ""; after = Some action }
  | Some p -> (
      match action with
      | Open -> open_ caps m
      | Fetch -> (
          (* (the snoozed whose day has come back first) *)
          let woken =
            if m.mailbox <> "INBOX" then Ok 0
            else
              Mail_sync.wake caps (store caps) m.server ~user:m.account
                ~password:p ~today:m.today
          in
          let listed =
            match woken with
            | Error e -> Error e
            | Ok _ ->
                online caps m p (fun t ->
                    Mail_sync.list caps (store caps) t ~account:m.account
                      ~mailbox:m.mailbox ~query:None 50)
          in
          match (woken, listed) with
          | _, Error e | Error e, _ -> { m with status = e; password = None }
          | Ok k, Ok l ->
              let m = load caps m in
              let back =
                if k = 0 then "" else Printf.sprintf ", %d back from snooze" k
              in
              {
                m with
                status =
                  count (List.length l) "message" ^ " fetched" ^ back;
              })
      | Snooze until -> (
          let uids = List.map (fun (s : Imap.summary) -> s.uid) (current m) in
          match
            online caps m p (fun t ->
                Mail_sync.snooze caps (store caps) t ~account:m.account
                  ~mailbox:m.mailbox uids ~until)
          with
          | Error e -> { m with status = e }
          | Ok () ->
              let m = load caps { m with mode = Browsing } in
              { m with status = "snoozed until " ^ Mail_sync.day until })
      | Send -> (
          match
            Mail_sync.send_draft caps (store caps) m.smtp ~user:m.account
              ~password:p m.draft
          with
          | Error e -> { m with mode = Composing; status = e }
          | Ok said -> load caps { m with mode = m.back_to; status = said })
      | Archive -> (
          let uids = List.map (fun (s : Imap.summary) -> s.uid) (current m) in
          match
            online caps m p (fun t ->
                Mail_sync.archive caps (store caps) t ~account:m.account
                  ~mailbox:m.mailbox uids)
          with
          | Error e -> { m with status = e }
          | Ok () ->
              let m = load caps { m with mode = Browsing } in
              { m with status = "archived" })
      | Star on -> (
          (* (the newest message, as Gmail's s in a list) *)
          let uids =
            match current m with (s : Imap.summary) :: _ -> [ s.uid ] | [] -> []
          in
          match
            online caps m p (fun t ->
                Mail_sync.star caps (store caps) t ~account:m.account
                  ~mailbox:m.mailbox uids ~on)
          with
          | Error e -> { m with status = e }
          | Ok () ->
              let m = load caps m in
              { m with status = (if on then "starred" else "unstarred") }))

(* the next or the previous conversation; opened, when one is *)
let next (caps : caps) (m : model) (d : int) : model =
  let n =
    if m.mailbox = drafts then List.length m.drafts
    else List.length m.conversations
  in
  let m = { m with selected = max 0 (min (n - 1) (m.selected + d)) } in
  if m.mode = Reading then open_ caps m else m

(* what a person can ask, by a key or by a menu *)
type command =
  | Get
  | Search_
  | Open_
  | Back
  | Archive_
  | Star_
  | Starred_list
  | Unread_list
  | Next
  | Previous
  | Inbox
  | All_mail
  | Compose
  | Reply
  | Reply_all
  | Forward
  | Send_
  | Save_draft
  | Discard
  | Drafts
  | Snooze_
  | Task
  | Add_sender
  | Invitation
  | Screener_on
  | List_of of Screen.place
  | Sender_to of Screen.place

(* the menu bar, after the suite's: each menu its title, then its
 * items, each with its command and its key, said in the item (a menu
 * is where the keys are learnt) *)
let menus : (string * (string * command) list) list =
  [ ( "Mail",
      [ ("Get Mail  (g)", Get); ("Compose  (c)", Compose);
        ("Search...  (/)", Search_);
        ("Turn On the Screener", Screener_on) ] );
    ( "Conversation",
      [ ("Open  (o)", Open_); ("Back to List  (u)", Back);
        ("Reply  (r)", Reply); ("Reply All  (a)", Reply_all);
        ("Forward  (f)", Forward); ("Archive  (e)", Archive_);
        ("Star  (s)", Star_);
        ("Next  (j)", Next); ("Previous  (k)", Previous);
        ("Snooze...  (z)", Snooze_); ("Make a Task...  (t)", Task);
        ("Sender to People  (p)", Add_sender);
        ("Add to Calendar  (i)", Invitation) ] );
    ( "Message",
      [ ("Send", Send_); ("Save Draft  (Esc)", Save_draft);
        ("Discard", Discard) ] );
    ( "Mailbox",
      [ ("Inbox  (Tab)", List_of Screen.Imbox); ("All Mail  (Tab)", All_mail);
        ("Drafts", Drafts); ("Unread", Unread_list); ("Starred", Starred_list);
        ("The Screener", List_of Screen.Screener);
        ("The Feed", List_of Screen.Feed); ("Paper Trail", List_of Screen.Paper);
        (* (the Screener's decisions, the sender's: Screen) *)
        ("Sender: Imbox  (y)", Sender_to Screen.Imbox);
        ("Sender: Feed", Sender_to Screen.Feed);
        ("Sender: Paper Trail", Sender_to Screen.Paper);
        ("Sender: Out  (n)", Sender_to Screen.Out) ] ) ]

(* [action] at the next frame, this one saying it (Gmail's answer takes
 * seconds, during which nothing is drawn) *)
let later (m : model) (action : action) : model =
  let what =
    match action with
    | Fetch -> "getting " ^ Mail_view.name m ^ " from the server..."
    | _ -> "..."
  in
  { m with soon = Some action; status = what }

let switch (caps : caps) (m : model) (mailbox : string) : model =
  let m =
    load caps { m with mailbox; selected = 0; mode = Browsing; status = "" }
  in
  (* (fetched when the password is known: what the store has of the
   * other mailbox may be old, or nothing) *)
  if m.password <> None && mailbox <> drafts then later m Fetch else m

(* the conversation of the message whose item is [id], opened: in the
 * Inbox if it is there, else the mailbox it was last listed in *)
let show (caps : caps) (m : model) (id : string) : model =
  match Items.find caps (store caps) id with
  | None -> { m with status = id ^ ": not in the store" }
  | Some i -> (
      let inbox =
        List.exists
          (fun v -> String.length (String.trim v) > 6
                    && String.sub (String.trim v) 0 6 = "INBOX ")
          (Mail.get_all i "in")
        && List.mem "\\Inbox" (Mail_item.summary i).labels
      in
      let mailbox =
        if inbox then "INBOX"
        else match Item.field i "mailbox" with "" -> "INBOX" | b -> b
      in
      let m =
        load caps { m with mailbox; query = ""; mode = Browsing; status = "" }
      in
      let has (c : Imap.summary list) =
        List.exists (fun s -> Mail_item.id s = id) c
      in
      let rec find k l =
        match l with
        | [] -> None
        | c :: rest -> if has c then Some k else find (k + 1) rest
      in
      match find 0 m.conversations with
      | None -> { m with status = id ^ ": not listed in " ^ mailbox }
      | Some k ->
          let m = { m with selected = k } in
          if m.password = None then open_ caps m else run caps m Open)

(*****************************************************************************)
(* Writing *)
(*****************************************************************************)

let made = ref 0

(* a draft's id: the time, and a count *)
let new_id () : string =
  incr made;
  Printf.sprintf "draft:%.0f.%d" (Unix.gettimeofday ()) !made

(* the window writing [d]; back after to the list, or the conversation *)
let compose (m : model) (d : Mail_compose.draft) : model =
  { m with
    draft = d;
    body = Text_edit.of_string d.text;
    mode = Composing;
    back_to = (if m.mode = Reading then Reading else Browsing);
    status = "" }

let write (m : model) (to_ : string) : model =
  compose { m with mode = Browsing }
    { (Mail_compose.blank ~id:(new_id ())) with to_ }

let write_mailto (m : model) (t : Mailto.t) : model =
  let m =
    compose { m with mode = Browsing }
      { (Mail_compose.blank ~id:(new_id ())) with
        to_ = String.concat ", " t.to_;
        cc = String.concat ", " t.cc;
        subject = t.subject;
        text = t.body }
  in
  (* (the composer has no Bcc: said, not sent) *)
  if t.bcc = [] then m
  else { m with status = "bcc left out: " ^ String.concat ", " t.bcc }

(* a reply to the conversation's newest message read, or its forward;
 * the conversation opened first when only listed *)
let answer (caps : caps) (m : model) (c : command) : model =
  let m =
    if m.mode = Reading || current m = [] then m else open_ caps m
  in
  let read = List.filter (fun (_, t) -> t <> None) m.reading in
  match List.rev read with
  | ((s : Imap.summary), Some text) :: _ ->
      let mail = Mail.parse text in
      let shown = Mail_text.text mail in
      let id = new_id () in
      compose m
        (if c = Forward then Mail_compose.forward ~id ~key:s.msgid mail shown
         else
           Mail_compose.reply ~id ~all:(c = Reply_all) ~me:m.account mail
             shown)
  | _ -> { m with status = "g: get the mail to answer it" }

(* t: the conversation's newest message stamped task, due that day: the
 * same item, now in the tasks too (plan_pim.md, idea 1) *)
let task (caps : caps) (m : model) (due : Civil.date) : model =
  match current m with
  | [] -> m
  | s :: _ -> (
      match Items.find caps (store caps) (Mail_item.id s) with
      | None -> { m with status = "not in the store: g first" }
      | Some i ->
          let i =
            if Item.has_stamp i "task" then i
            else Mail.set "stamp" (String.concat " " (Item.stamps i @ [ "task" ])) i
          in
          Items.save caps (store caps)
            (Mail.remove "done" (Mail.set "due" (Mail_sync.day due) i));
          load caps { m with status = "a task, due " ^ Mail_sync.day due })

(* i: the invitations of the conversation's messages read (iMIP, RFC
 * 6047: a text/calendar part) made events, each linked to its mail
 * (Events.of_ics) *)
let invitation (caps : caps) (m : model) : model =
  let m =
    if m.mode = Reading || current m = [] then m else open_ caps m
  in
  let events =
    List.concat_map
      (fun ((s : Imap.summary), t) ->
        match t with
        | None -> []
        | Some t ->
            List.concat_map
              (fun (l : Mime.leaf) ->
                if String.lowercase_ascii l.mime = "text/calendar" then
                  Events.of_ics (Zone.local caps) ~message:(Mail_item.id s) l.data
                else [])
              (Mime.leaves (Mail.parse t)))
      m.reading
  in
  List.iter (Items.save caps (store caps)) events;
  { m with
    status =
      (match events with
      | [] -> "no invitation here"
      | [ e ] -> "in the Calendar: " ^ title e
      | l -> count (List.length l) "event" ^ " in the Calendar") }

let opened (m : model) : (string * Mail.t) list =
  if m.mode <> Reading then []
  else
    List.filter_map
      (fun ((s : Imap.summary), t) ->
        match t with
        | Some t -> Some (Mail_item.id s, Mail.parse t)
        | None -> None)
      m.reading

(* the draft kept, the window back where it was *)
let leave (caps : caps) (m : model) (status : string) : model =
  load caps { m with mode = m.back_to; status }

let command (caps : caps) (m : model) (c : command) : model =
  (* (writing, the conversation's commands wait) *)
  let while_writing =
    match c with
    | Send_ | Save_draft | Discard | Inbox | All_mail | Drafts | Get -> true
    | _ -> false
  in
  if m.mode = Composing && not while_writing then m
  else if m.mode <> Composing && (c = Send_ || c = Save_draft || c = Discard)
  then m
  else
  match c with
  | Get -> if m.password = None then run caps m Fetch else later m Fetch
  | Search_ -> { m with mode = Asking Search; field = m.query }
  | Open_ when m.mailbox = drafts -> (
      match List.nth_opt m.drafts m.selected with
      | Some d -> compose m d
      | None -> m)
  | Open_ ->
      if current m = [] then m
      else if m.password = None then open_ caps m
      else run caps m Open
  | Back -> { m with mode = Browsing }
  | Archive_ -> if current m = [] then m else run caps m Archive
  | Star_ ->
      (* (starred: any of its messages flagged; s takes it off) *)
      let starred =
        List.exists
          (fun (s : Imap.summary) -> List.mem "\\Flagged" s.flags)
          (current m)
      in
      if current m = [] then m else run caps m (Star (not starred))
  | Starred_list -> switch caps m Mail_sync.starred
  | Next -> next caps m 1
  | Previous -> next caps m (-1)
  | Inbox -> switch caps m "INBOX"
  | List_of p -> switch caps { m with screen = p; unread = false } "INBOX"
  | Unread_list ->
      switch caps { m with screen = Screen.Imbox; unread = true } "INBOX"
  | Screener_on ->
      Items.save caps (store caps) (Screen.turn_on m.today);
      load caps { m with status = "the Screener on: new senders wait in it" }
  | Sender_to p -> (
      match current m with
      | [] -> m
      | c -> (
          let me = String.lowercase_ascii m.account in
          match List.find_opt (fun s -> Screen.address s <> me) c with
          | None -> m
          | Some s ->
              let a = Screen.address s in
              Items.save caps (store caps) (Screen.decide a p);
              load caps
                { m with
                  status =
                    a ^ (match p with
                        | Screen.Imbox -> ": in the Imbox"
                        | Screen.Feed -> ": in the Feed"
                        | Screen.Paper -> ": in the Paper Trail"
                        | Screen.Out -> ": screened out"
                        | Screen.Screener -> "") }))
  | All_mail -> switch caps m Mail_sync.all_mail
  | Drafts -> switch caps m drafts
  | Add_sender -> (
      match current m with
      | [] -> m
      | s :: _ -> (
          let st = store caps in
          match
            Option.bind (Items.find caps st (Mail_item.id s)) People.of_sender
          with
          | None -> { m with status = "no sender here" }
          | Some c when Items.find caps st (Item.id c) <> None ->
              { m with status = Item.id c ^ ": already in People" }
          | Some c ->
              Items.save caps st c;
              load caps { m with status = title c ^ " added to People" }))
  | Snooze_ ->
      if current m = [] then m
      else { m with mode = Asking Until; field = ""; status = "" }
  | Task ->
      if current m = [] then m
      else { m with mode = Asking Due; field = ""; status = "" }
  | Invitation -> if current m = [] then m else invitation caps m
  | Compose -> compose m (Mail_compose.blank ~id:(new_id ()))
  | Reply | Reply_all | Forward -> answer caps m c
  | Send_ -> run caps m Send
  | Save_draft ->
      Items.save caps (store caps) (Mail_compose.to_item m.draft);
      leave caps m "draft saved"
  | Discard ->
      Items.remove caps (store caps) m.draft.id;
      leave caps m "discarded"

(* the message's widgets this frame (immediate mode), the draft written
 * to the store as it changes (the Palm's: no Save needed); a button's
 * command, or the menu's *)
let writing (caps : caps) (computer : computer) (m : model)
    (menu : command option) (escape : bool) : model =
  let d = m.draft in
  let field i v =
    Gui.field_in ~enabled:true computer (Mail_view.field_box computer i) v
  in
  let to_ = field 0 d.to_ in
  let cc = field 1 d.cc in
  let subject = field 2 d.subject in
  let attach = field 3 d.attach in
  let body = Gui.text_area_in computer (Mail_view.area_box computer) m.body in
  let button i label =
    Gui.button_in ~enabled:true computer (Mail_view.button_box computer i) label
  in
  let send = button 0 "Send" in
  let save = button 1 "Save Draft" in
  let discard = button 2 "Discard" in
  let d' =
    { d with to_; cc; subject; attach; text = Text_edit.to_string body }
  in
  if d' <> d then Items.save caps (store caps) (Mail_compose.to_item d');
  let m = { m with draft = d'; body } in
  let c =
    match menu with
    | Some c -> Some c
    | None ->
        if send then Some Send_
        else if save || escape then Some Save_draft
        else if discard then Some Discard
        else None
  in
  match c with Some c -> command caps m c | None -> m

let update (caps : caps) (computer : computer) (m : model) : model =
  match m.soon with
  (* (the frame before said it: now done) *)
  | Some action -> run caps { m with soon = None } action
  | None ->
  let keys = computer.keyboard.keys in
  let pressed name = Set_.mem name keys && not (Set_.mem name m.held) in
  let menu = chosen computer ~first:1 menus in
  let m =
    match m.mode with
    | Asking a ->
        if pressed "Escape" then
          { m with
            mode = (if m.after = Some Send then Composing else Browsing);
            field = "";
            after = None }
        else if pressed "Enter" then
          match a with
          | Password -> (
              let m =
                { m with password = Some m.field; field = ""; mode = Browsing }
              in
              match m.after with
              | Some action -> run caps { m with after = None } action
              | None -> m)
          | Search ->
              load caps
                { m with query = m.field; field = ""; mode = Browsing;
                  selected = 0 }
          | Until | Due -> (
              let m' = { m with field = ""; mode = Browsing } in
              match When.parse ~today:m.today m.field with
              | None ->
                  { m' with
                    status = m.field ^ ": not a day (monday, in 3 days)" }
              | Some d when a = Until -> run caps m' (Snooze d)
              | Some d -> task caps m' d)
        else if pressed "Backspace" then { m with field = without_last m.field }
        else { m with field = m.field ^ printable computer.keyboard.typed }
    | Composing -> writing caps computer m menu (pressed "Escape")
    | (Browsing | Reading) when Gui.modal () -> m
    | Browsing | Reading -> (
        let reading = m.mode = Reading in
        let key =
          if pressed "j" || ((not reading) && pressed "ArrowDown") then Some Next
          else if pressed "k" || ((not reading) && pressed "ArrowUp") then
            Some Previous
          else if pressed "o" || pressed "Enter" then Some Open_
          else if pressed "u" || pressed "Escape" then Some Back
          else if pressed "e" then Some Archive_
          else if pressed "s" then Some Star_
          else if pressed "c" then Some Compose
          else if pressed "r" then Some Reply
          else if pressed "a" then Some Reply_all
          else if pressed "f" then Some Forward
          else if pressed "z" then Some Snooze_
          else if pressed "t" then Some Task
          else if pressed "p" then Some Add_sender
          else if pressed "i" then Some Invitation
          else if pressed "g" then Some Get
          else if pressed "/" then Some Search_
          (* (the Screener's yes and no, HEY's) *)
          else if pressed "y" && m.screen = Screen.Screener then
            Some (Sender_to Screen.Imbox)
          else if pressed "n" && m.screen = Screen.Screener then
            Some (Sender_to Screen.Out)
          else if pressed "Tab" then
            Some (if m.mailbox = "INBOX" then All_mail else List_of Screen.Imbox)
          else None
        in
        (* the mouse: a place of the sidebar, a conversation of the list
         * (opened, as Gmail's click) *)
        let row =
          match Pim_look.row_click computer with
          | Some k when not reading ->
              let fits = Mail_view.list_fits computer in
              let i = max 0 (m.selected - fits + 1) + k in
              let n =
                if m.mailbox = drafts then List.length m.drafts
                else List.length m.conversations
              in
              if i < n then Some i else None
          | _ -> None
        in
        (* the scrollbar pressed or dragged: the list's row, the
         * reading's line at that place *)
        let bar_at =
          if reading then
            Pim_look.scrollbar_press computer ~bottom:(Mail_view.bottom computer)
              ~n:(Mail_view.lines computer m) ~fits:(Mail_view.reading_fits computer)
          else
            Pim_look.scrollbar_press computer ~bottom:(Mail_view.bottom computer)
              ~n:(List.length m.conversations) ~fits:(Mail_view.list_fits computer)
        in
        match (menu, key, Pim_look.sidebar_click computer, row) with
        | None, None, _, _ when bar_at <> None -> (
            match bar_at with
            | Some k when reading ->
                { m with scroll = max 0 (k - (Mail_view.reading_fits computer / 2)) }
            | Some k -> { m with selected = k }
            | None -> m)
        | Some c, _, _, _ | None, Some c, _, _ -> command caps m c
        | None, None, Some k, _ when k < List.length (places m) -> (
            match List.nth_opt (places m) k with
            | Some { mailbox = "INBOX"; list; unread; _ } ->
                command caps { m with screen = list; unread } Inbox
            | Some p when p.mailbox = drafts -> command caps m Drafts
            | Some p when p.mailbox = Mail_sync.starred ->
                command caps m Starred_list
            | Some _ -> command caps m All_mail
            | None -> m)
        | None, None, _, Some i -> command caps { m with selected = i } Open_
        | None, None, _, _ when wheel computer <> 0 ->
            (* the wheel: the message read scrolled, the list's selection
             * moved (the list follows it) *)
            if reading then { m with scroll = max 0 (m.scroll + wheel computer) }
            else
              let n =
                if m.mailbox = drafts then List.length m.drafts
                else List.length m.conversations
              in
              { m with selected = moved m.selected (wheel computer) n }
        | None, None, _, _ ->
            if reading && (pressed "ArrowDown" || pressed "space") then
              { m with scroll = (m.scroll + if pressed "space" then 10 else 1) }
            else if reading && pressed "ArrowUp" then
              { m with scroll = max 0 (m.scroll - 1) }
            else m)
  in
  { m with held = keys }

let view = Mail_view.view
