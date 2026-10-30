(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Mail_window.mli *)

open Playground
open Pim_look

type caps =
  < Cap.network ; Cap.open_in ; Cap.open_out ; Cap.readdir ; Cap.env ; Cap.exit >

(*****************************************************************************)
(* The model *)
(*****************************************************************************)

(* what waits for the password *)
type action = Fetch | Open | Archive | Send | Snooze of Civil.date
type asking = Password | Search | Until | Due
type mode = Browsing | Reading | Composing | Asking of asking

type model = {
  account : string;
  server : Mail_sync.server;
  smtp : Mail_sync.server;
  mailbox : string; (* INBOX, All Mail, or the store's drafts *)
  password : string option; (* kept while the window is open *)
  query : string; (* the search's words, "" for none *)
  conversations : Imap.summary list list;
  drafts : Mail_compose.draft list; (* the drafts mailbox's *)
  today : Civil.date; (* today= (the tests'), else the clock's *)
  selected : int;
  (* the conversation opened: its messages, oldest first, each its text
   * when the cache has it *)
  reading : (Imap.summary * string option) list;
  scroll : int; (* the first line of the conversation shown *)
  mode : mode;
  (* the message written: its fields, its text being edited, and the
   * mode its window goes back to *)
  draft : Mail_compose.draft;
  body : Text_edit.t;
  back_to : mode;
  field : string; (* what is typed after a question *)
  after : action option;
  status : string;
  held : string Set_.t; (* the keys down at the last frame *)
}

let store (caps : caps) : Items.t = Items.at (Items.place caps)

(* the drafts, a mailbox of the store's, not the server's *)
let drafts = "Drafts"

let contains (s : string) (word : string) : bool =
  let s = String.lowercase_ascii s and w = String.lowercase_ascii word in
  let n = String.length s and k = String.length w in
  let rec at i = i + k <= n && (String.sub s i k = w || at (i + 1)) in
  at 0

(* every word of the query in who sent one of its messages, or in its
 * subject *)
let matches (query : string) (c : Imap.summary list) : bool =
  List.for_all
    (fun w ->
      List.exists
        (fun (s : Imap.summary) ->
          contains (Conversations.who s.headers) w
          || contains (Conversations.header s.headers "subject") w)
        c)
    (List.filter (fun w -> w <> "") (String.split_on_char ' ' query))

(* the conversations again from the store, those back from a snooze on
 * top; the drafts *)
let load (caps : caps) (m : model) : model =
  let items = Items.all caps (store caps) in
  let l = Mail_item.listed items ~account:m.account ~mailbox:m.mailbox in
  let cs = List.filter (matches m.query) (Conversations.group l) in
  let woke =
    List.filter_map
      (fun i -> if Item.field i "woke" <> "" then Some (Item.id i) else None)
      items
  in
  let back (c : Imap.summary list) =
    List.exists (fun s -> List.mem (Mail_item.id s) woke) c
  in
  let cs = List.filter back cs @ List.filter (fun c -> not (back c)) cs in
  let ds =
    List.map Mail_compose.of_item
      (List.filter (fun i -> Item.has_stamp i "draft") items)
  in
  let n = if m.mailbox = drafts then List.length ds else List.length cs in
  { m with conversations = cs; drafts = ds;
    selected = max 0 (min m.selected (n - 1)) }

let initial (caps : caps) (flags : Playground.flags) : model =
  let flag name =
    match List.assoc_opt name flags with Some v -> v | None -> ""
  in
  (* server=host:port, else Gmail's *)
  let server name (gmail : Mail_sync.server) : Mail_sync.server =
    let plain = List.mem_assoc "plain" flags in
    match String.rindex_opt (flag name) ':' with
    | Some i -> (
        let hp = flag name in
        match
          int_of_string_opt (String.sub hp (i + 1) (String.length hp - i - 1))
        with
        | Some port -> { Mail_sync.host = String.sub hp 0 i; port; plain }
        | None -> gmail)
    | None -> { gmail with plain }
  in
  (* the store's password file, if the author made one *)
  let password, status =
    match Mail_sync.saved_password caps with
    | Ok p -> (p, "")
    | Error e -> (None, e)
  in
  load caps
    {
      account = flag "user";
      server = server "server" Mail_sync.gmail;
      smtp = server "smtp" Mail_sync.gmail_smtp;
      mailbox = "INBOX";
      password;
      query = "";
      conversations = [];
      drafts = [];
      today =
        (match Search.date (flag "today") with
        | Some d -> d
        | None -> When.today ());
      selected = 0;
      reading = [];
      scroll = 0;
      mode = Browsing;
      draft = Mail_compose.blank ~id:"";
      body = Text_edit.of_string "";
      back_to = Browsing;
      field = "";
      after = None;
      status;
      held = Set_.empty;
    }

let refresh (caps : caps) (keys : string Set_.t) (m : model) : model =
  load caps { m with held = keys }

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
                  Printf.sprintf "%d messages fetched%s" (List.length l) back;
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
              { m with status = "archived" }))

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

(* the menu bar, after the suite's: each menu its title, then its
 * items, each with its command and its key, said in the item (a menu
 * is where the keys are learnt) *)
let menus : (string * (string * command) list) list =
  [ ( "Mail",
      [ ("Get Mail  (g)", Get); ("Compose  (c)", Compose);
        ("Search...  (/)", Search_) ] );
    ( "Conversation",
      [ ("Open  (o)", Open_); ("Back to List  (u)", Back);
        ("Reply  (r)", Reply); ("Reply All  (a)", Reply_all);
        ("Forward  (f)", Forward); ("Archive  (e)", Archive_);
        ("Next  (j)", Next); ("Previous  (k)", Previous);
        ("Snooze...  (z)", Snooze_); ("Make a Task...  (t)", Task);
        ("Sender to People  (p)", Add_sender) ] );
    ( "Message",
      [ ("Send", Send_); ("Save Draft  (Esc)", Save_draft);
        ("Discard", Discard) ] );
    ( "Mailbox",
      [ ("Inbox  (Tab)", Inbox); ("All Mail  (Tab)", All_mail);
        ("Drafts", Drafts) ] ) ]

let switch (caps : caps) (m : model) (mailbox : string) : model =
  let m =
    load caps { m with mailbox; selected = 0; mode = Browsing; status = "" }
  in
  (* (fetched when the password is known: what the store has of the
   * other mailbox may be old, or nothing) *)
  if m.password <> None && mailbox <> drafts then run caps m Fetch else m

(* the conversation of the message whose item is [id], opened: in the
 * mailbox it was last listed in *)
let show (caps : caps) (m : model) (id : string) : model =
  match Items.find caps (store caps) id with
  | None -> { m with status = id ^ ": not in the store" }
  | Some i -> (
      let mailbox =
        match Item.field i "mailbox" with "" -> "INBOX" | b -> b
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
  | Get -> run caps m Fetch
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
  | Next -> next caps m 1
  | Previous -> next caps m (-1)
  | Inbox -> switch caps m "INBOX"
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
  | Compose -> compose m (Mail_compose.blank ~id:(new_id ()))
  | Reply | Reply_all | Forward -> answer caps m c
  | Send_ -> run caps m Send
  | Save_draft ->
      Items.save caps (store caps) (Mail_compose.to_item m.draft);
      leave caps m "draft saved"
  | Discard ->
      Items.remove caps (store caps) m.draft.id;
      leave caps m "discarded"

(* where the message's fields, its text and its buttons are: under the
 * title bar, right of the sidebar *)
let field_box (computer : computer) (i : int) : Widget.box =
  let w = computer.screen.width and h = computer.screen.height in
  let x0 = (-.w /. 2.) +. side +. 16. and room = w -. side -. 32. in
  { Widget.x = x0 +. 80. +. ((room -. 80.) /. 2.);
    y = (h /. 2.) -. menu_bar -. bar -. 26. -. (float_of_int i *. 34.);
    w = room -. 80.; h = 26. }

let area_box (computer : computer) : Widget.box =
  let w = computer.screen.width and h = computer.screen.height in
  let x0 = (-.w /. 2.) +. side +. 16. and room = w -. side -. 32. in
  let top = (h /. 2.) -. menu_bar -. bar -. 26. -. (3. *. 34.) -. 26. in
  let bottom = (-.h /. 2.) +. 56. in
  { Widget.x = x0 +. (room /. 2.); y = (top +. bottom) /. 2.; w = room;
    h = top -. bottom }

let button_box (computer : computer) (i : int) : Widget.box =
  let w = computer.screen.width and h = computer.screen.height in
  let x0 = (-.w /. 2.) +. side +. 16. in
  { Widget.x = x0 +. 60. +. (float_of_int i *. 130.); y = (-.h /. 2.) +. 28.;
    w = 120.; h = 30. }

(* the message's widgets this frame (immediate mode), the draft written
 * to the store as it changes (the Palm's: no Save needed); a button's
 * command, or the menu's *)
let writing (caps : caps) (computer : computer) (m : model)
    (menu : command option) (escape : bool) : model =
  let d = m.draft in
  let field i v = Gui.field_in ~enabled:true computer (field_box computer i) v in
  let to_ = field 0 d.to_ in
  let cc = field 1 d.cc in
  let subject = field 2 d.subject in
  let attach = field 3 d.attach in
  let body = Gui.text_area_in computer (area_box computer) m.body in
  let button i label =
    Gui.button_in ~enabled:true computer (button_box computer i) label
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
          else if pressed "c" then Some Compose
          else if pressed "r" then Some Reply
          else if pressed "a" then Some Reply_all
          else if pressed "f" then Some Forward
          else if pressed "z" then Some Snooze_
          else if pressed "t" then Some Task
          else if pressed "p" then Some Add_sender
          else if pressed "g" then Some Get
          else if pressed "/" then Some Search_
          else if pressed "Tab" then
            Some (if m.mailbox = "INBOX" then All_mail else Inbox)
          else None
        in
        match (menu, key) with
        | Some c, _ | None, Some c -> command caps m c
        | None, None ->
            if reading && (pressed "ArrowDown" || pressed "space") then
              { m with scroll = (m.scroll + if pressed "space" then 10 else 1) }
            else if reading && pressed "ArrowUp" then
              { m with scroll = max 0 (m.scroll - 1) }
            else m)
  in
  { m with held = keys }

(*****************************************************************************)
(* The picture *)
(*****************************************************************************)

let mailbox_name (m : model) : string =
  if m.mailbox = "INBOX" then "Inbox"
  else if m.mailbox = Mail_sync.all_mail then "All Mail"
  else if m.mailbox = drafts then "Drafts"
  else m.mailbox

let view (computer : computer) (m : model) : shape list =
  let h = computer.screen.height in
  let a = area computer in
  let x0 = a.x0 and room = a.room and top = a.top in
  let title =
    match m.mode with
    | Asking Password ->
        "password: " ^ String.make (List.length (Text.chars m.field)) '*'
    | Asking Search -> "search: " ^ m.field ^ "_"
    | Asking Until -> "snooze until: " ^ m.field ^ "_"
    | Asking Due -> "a task, due: " ^ m.field ^ "_"
    | Composing ->
        (if m.draft.subject = "" then "New message" else m.draft.subject)
        ^ " \xe2\x80\x94 " ^ m.account
    | Browsing | Reading -> mailbox_name m ^ " \xe2\x80\x94 " ^ m.account
  in
  let right =
    if m.status <> "" then m.status
    else if m.mailbox = drafts then count (List.length m.drafts) "draft"
    else count (List.length m.conversations) "conversation"
  in
  let sidebar =
    Pim_look.sidebar a
      (List.map
         (fun (name, box) -> (name, box = m.mailbox))
         [ ("Inbox", "INBOX"); ("All Mail", Mail_sync.all_mail);
           ("Drafts", drafts) ])
    @
    if m.query <> "" then
      [ text blue ~bold:false ~room:(side -. 24.) (a.left +. 16.) (row_y a 4)
          ("/" ^ m.query) ]
    else []
  in
  let main =
    match m.mode with
    | Composing ->
        (* the fields' names; the fields, the text and the buttons are
         * the toolkit's (Gui.draw) *)
        List.mapi
          (fun i name ->
            let b = field_box computer i in
            text grey ~bold:false ~room:76. x0 (b.y -. 5.) name)
          [ "To"; "Cc"; "Subject"; "Attach" ]
    | Browsing when m.mailbox = drafts ->
        if m.drafts = [] then
          [ text grey ~bold:false ~room x0 (row_y a 0) "No drafts." ]
        else
          List.concat
            (List.mapi
               (fun i (d : Mail_compose.draft) ->
                 let y = row_y a i in
                 (if i = m.selected then [ selected a y ] else [])
                 @ [ text ink ~bold:false ~room:190. x0 y
                       (if d.to_ = "" then "(no one)" else d.to_);
                     text ink ~bold:false ~room:(room -. 200.) (x0 +. 200.) y
                       (if d.subject = "" then "(no subject)" else d.subject) ])
               m.drafts)
    | Reading ->
        let subject =
          match m.reading with
          | (s, _) :: _ -> Conversations.header s.headers "subject"
          | [] -> ""
        in
        let lines =
          List.concat_map
            (fun ((s : Imap.summary), t) ->
              let head =
                Conversations.who s.headers
                ^ "   "
                ^ Conversations.day s.headers
              in
              let body =
                match t with
                | Some t -> wrap room (String.trim (Mail_text.text (Mail.parse t)))
                | None -> [ "(not fetched: g gets the mail)" ]
              in
              ((true, head) :: List.map (fun l -> (false, l)) body)
              @ [ (false, "") ])
            m.reading
        in
        let fits = int_of_float ((h -. bar -. 60.) /. 22.) in
        let shown =
          List.filteri (fun i _ -> i >= m.scroll && i < m.scroll + fits) lines
        in
        text ink ~bold:true ~room x0 (top -. bar -. 32.) subject
        :: List.mapi
             (fun i (bold, l) ->
               text
                 (if bold then ink else grey)
                 ~bold ~room x0
                 (top -. bar -. 62. -. (float_of_int i *. 22.))
                 l)
             shown
    | Browsing | Asking _ ->
        if m.conversations = [] then
          [ text grey ~bold:false ~room x0 (row_y a 0) "No mail here: g gets it." ]
        else
          let fits = int_of_float ((h -. bar -. 12.) /. row) in
          let first = max 0 (m.selected - fits + 1) in
          List.concat
            (List.mapi
               (fun i (c : Imap.summary list) ->
                 if i < first || i >= first + fits then []
                 else
                   let s = List.hd c in
                   let y = row_y a (i - first) in
                   let bold = Conversations.unread c in
                   let many =
                     if List.length c > 1 then
                       Printf.sprintf " (%d)" (List.length c)
                     else ""
                   in
                   let day = Conversations.day s.headers in
                   (if i = m.selected then [ selected a y ] else [])
                   @ [
                       text ink ~bold ~room:190. x0 y
                         (Conversations.who s.headers ^ many);
                       text ink ~bold ~room:(room -. 310.) (x0 +. 200.) y
                         (Conversations.header s.headers "subject");
                       text grey ~bold
                         ~room:(width day +. 4.)
                         (x0 +. room -. width day)
                         y day;
                     ])
               m.conversations)
  in
  (rectangle white computer.screen.width h :: title_bar computer title right)
  @ sidebar @ main
