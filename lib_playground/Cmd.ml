(* claude: see Cmd.mli *)
(* ix: the author's playground's libs/core/Cmd.ml (docs/plans/plan_playground.md) *)

(* ix: no Http_get nor Http_post (nor their types): a game on mini-9pi
 * asks nothing of the network yet *)
type 'msg t =
  | None
  | Msg of 'msg
  | Batch of 'msg t list

let none = None
let batch cmds = Batch cmds

let rec to_list (cmd : 'msg t) : 'msg t list =
  match cmd with
  | None -> []
  | Batch cmds -> List.concat_map to_list cmds
  | Msg _ -> [ cmd ]
