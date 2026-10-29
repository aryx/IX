(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Item.mli *)

type t = Mail.t

let make ~(id : string) ~(stamps : string list)
    (fields : (string * string) list) (text : string) : t =
  Mail.make ((("id", id) :: [ ("stamp", String.concat " " stamps) ]) @ fields)
    text

let field (t : t) (name : string) : string =
  match Mail.get t name with Some v -> v | None -> ""

let id (t : t) : string = field t "id"

let stamps (t : t) : string list =
  List.concat_map
    (fun v -> List.filter (fun w -> w <> "") (String.split_on_char ' ' v))
    (Mail.get_all t "stamp")

let has_stamp (t : t) (stamp : string) : bool = List.mem stamp (stamps t)

let parse (text : string) : t = Mail.parse text
let to_string (t : t) : string = Mail.to_string t
