(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Mail_compose.mli *)

type draft = {
  id : string;
  to_ : string;
  cc : string;
  subject : string;
  in_reply_to : string;
  references : string;
  forward : string;
  attach : string;
  text : string;
}

let blank ~(id : string) : draft =
  { id; to_ = ""; cc = ""; subject = ""; in_reply_to = ""; references = "";
    forward = ""; attach = ""; text = "" }

let header (m : Mail.t) (name : string) : string =
  match Mail.get m name with Some v -> Mime.decode_words v | None -> ""

(* "Re: x" once, whatever the case of the Re: there *)
let prefixed (prefix : string) (subject : string) : string =
  let n = String.length prefix in
  if
    String.length subject >= n
    && String.lowercase_ascii (String.sub subject 0 n)
       = String.lowercase_ascii prefix
  then subject
  else prefix ^ subject

let quoted (text : string) : string =
  String.concat "\n"
    (List.map
       (fun l -> if l = "" then ">" else "> " ^ l)
       (String.split_on_char '\n' (String.trim text)))

let same_mailbox (a : Mail.address) (b : Mail.address) : bool =
  String.lowercase_ascii a.mailbox = String.lowercase_ascii b.mailbox

let reply ~(id : string) ~(all : bool) ~(me : string) (m : Mail.t)
    (text : string) : draft =
  let target =
    let r = header m "reply-to" in
    if r <> "" then r else header m "from"
  in
  let targets = Mail.addresses target in
  let others =
    if not all then []
    else
      List.filter
        (fun (a : Mail.address) ->
          String.lowercase_ascii a.mailbox <> String.lowercase_ascii me
          && not (List.exists (same_mailbox a) targets))
        (Mail.addresses (header m "to") @ Mail.addresses (header m "cc"))
  in
  (* (an address once, though in To: and Cc: both) *)
  let others =
    List.fold_left
      (fun acc a -> if List.exists (same_mailbox a) acc then acc else acc @ [ a ])
      [] others
  in
  let msgid = header m "message-id" in
  let references =
    String.trim (String.concat " " [ header m "references"; msgid ])
  in
  {
    (blank ~id) with
    to_ = String.concat ", " (List.map Mail.address_to_string targets);
    cc = String.concat ", " (List.map Mail.address_to_string others);
    subject = prefixed "Re: " (header m "subject");
    in_reply_to = msgid;
    references;
    text =
      Printf.sprintf "\n\nOn %s, %s wrote:\n%s\n" (header m "date")
        (header m "from") (quoted text);
  }

let forward ~(id : string) ~(key : string) (m : Mail.t) (text : string) :
    draft =
  let line name label =
    let v = header m name in
    if v = "" then [] else [ label ^ ": " ^ v ]
  in
  let head =
    List.concat
      [ line "from" "From"; line "date" "Date"; line "subject" "Subject";
        line "to" "To"; line "cc" "Cc" ]
  in
  {
    (blank ~id) with
    subject = prefixed "Fwd: " (header m "subject");
    forward = key;
    text =
      "\n\n---------- Forwarded message ---------\n"
      ^ String.concat "\n" head ^ "\n\n" ^ String.trim text ^ "\n";
  }

(*****************************************************************************)
(* A draft as an item *)
(*****************************************************************************)

let fields (d : draft) : (string * string) list =
  List.filter
    (fun (_, v) -> v <> "")
    [ ("to", d.to_); ("cc", d.cc); ("subject", d.subject);
      ("in-reply-to", d.in_reply_to); ("references", d.references);
      ("forward", d.forward); ("attach", d.attach) ]

let to_item (d : draft) : Item.t =
  Item.make ~id:d.id ~stamps:[ "draft" ] (fields d) d.text

let of_item (t : Item.t) : draft =
  let f = Item.field t in
  { id = Item.id t; to_ = f "to"; cc = f "cc"; subject = f "subject";
    in_reply_to = f "in-reply-to"; references = f "references";
    forward = f "forward"; attach = f "attach"; text = t.body }

(*****************************************************************************)
(* The message sent *)
(*****************************************************************************)

let date_string ~(date : float) ~(offset : int) : string =
  let day, time = Clock.local ~offset date in
  (* (whole seconds: Date: has no fraction) *)
  let time = { time with second = Float.of_int (int_of_float time.second) } in
  Mail.date_to_string { day; time; offset }

let new_msgid ~(from : string) (date : float) (n : int) : string =
  let domain =
    match Mail.address from with
    | Some a -> (
        match String.index_opt a.mailbox '@' with
        | Some i -> String.sub a.mailbox (i + 1) (String.length a.mailbox - i - 1)
        | None -> "mini-pim")
    | None -> "mini-pim"
  in
  Printf.sprintf "<%.0f.%d.mini-pim@%s>" date n domain

let message ~(from : string) ~(date : float) ~(offset : int)
    ~(msgid : string) ~(files : (string * string) list) (d : draft) : Mail.t =
  let text = Mime.text_part d.text in
  let content, body =
    match files with
    | [] ->
        ( List.filter_map
            (fun name ->
              match Mail.get text name with
              | Some v -> Some (name, v)
              | None -> None)
            [ "Content-Type"; "Content-Transfer-Encoding" ],
          text.body )
    | _ ->
        Mime.multipart
          ~boundary:("=_mini-pim." ^ msgid)
          (text
          :: List.map
               (fun (name, bytes) -> Mime.attachment ~filename:name bytes)
               files)
  in
  let optional name v = if v = "" then [] else [ (name, v) ] in
  Mail.make
    (List.concat
       [ [ ("From", from); ("To", d.to_) ]; optional "Cc" d.cc;
         [ ("Subject", Mime.encode_words d.subject);
           ("Date", date_string ~date ~offset); ("Message-ID", msgid) ];
         optional "In-Reply-To" d.in_reply_to;
         optional "References" d.references;
         [ ("MIME-Version", "1.0") ]; content ])
    body

let complete (m : Mail.t) : Mail.t =
  if
    Mail.get m "content-type" <> None
    || String.for_all (fun c -> Char.code c < 128) m.body
  then m
  else
    let text = Mime.text_part m.body in
    let m = Mail.set "MIME-Version" "1.0" m in
    let m =
      List.fold_left
        (fun m name ->
          match Mail.get text name with
          | Some v -> Mail.set name v m
          | None -> m)
        m
        [ "Content-Type"; "Content-Transfer-Encoding" ]
    in
    { m with body = text.body }
