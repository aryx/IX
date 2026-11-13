(* Pushing: git9's git/send (send.c, sendpack).
 *
 * Our side is the branches given (-b, as refs/heads/X) or all the
 * references (-a, as listrefs names them), and the ones to delete
 * (-r, with the zero hash). Their side is the references that the
 * server lists. A branch is sent only if theirs is an ancestor of ours
 * (otherwise "remote has diverged"), unless it is forced. Then come
 * the update lines ("OLD NEW REF", with report-status asked for on the
 * first one if the server offers it), a flush, and a pack of what they
 * lack. The output, for push.rc, is:
 *
 *   update refs/heads/master 0e4c... 1f7a...
 *   uptodate refs/heads/front *)

type opts = { all : bool; force : bool; branches : string list; removed : string list }

(* raises Proto.Error on a failure (the server's, or "remote diverged") *)
val send : Store.t -> Proto.conn -> opts -> print:(string -> unit) -> eprint:(string -> unit) -> unit
