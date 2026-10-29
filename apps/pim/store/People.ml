(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See People.mli *)

let lower = String.lowercase_ascii
let id (a : Mail.address) : string = "contact:" ^ lower a.mailbox

let of_sender (message : Item.t) : Item.t option =
  match Mail.address (Item.field message "from") with
  | None -> None
  | Some a ->
      let name =
        if a.display <> "" then Mime.decode_words a.display else a.mailbox
      in
      Some
        (Item.make ~id:(id a) ~stamps:[ "contact" ]
           [ ("name", name); ("email", lower a.mailbox) ]
           "")

let emails (contact : Item.t) : string list =
  List.map (fun v -> lower (String.trim v)) (Mail.get_all contact "email")

let contacts (items : Item.t list) : Item.t list =
  List.stable_sort
    (fun a b ->
      compare (lower (Item.field a "name")) (lower (Item.field b "name")))
    (List.filter (fun i -> Item.has_stamp i "contact") items)

(* the addresses of a message's From:, To: and Cc: *)
let addresses (m : Item.t) : string list =
  List.concat_map
    (fun f ->
      List.map
        (fun (a : Mail.address) -> lower a.mailbox)
        (Mail.addresses (Mime.decode_words (Item.field m f))))
    [ "from"; "to"; "cc" ]

let with_ (items : Item.t list) (contact : Item.t) : Item.t list =
  let mine = emails contact in
  let seconds (m : Item.t) =
    match Mail.date (Item.field m "date") with
    | Some d -> Mail.seconds d
    | None -> 0.
  in
  List.stable_sort
    (fun a b -> compare (seconds b) (seconds a))
    (List.filter
       (fun m ->
         Item.has_stamp m "message"
         && List.exists (fun a -> List.mem a mine) (addresses m))
       items)

let who (items : Item.t list) (address : string) : Item.t option =
  let a = lower address in
  List.find_opt
    (fun i -> Item.has_stamp i "contact" && List.mem a (emails i))
    items
