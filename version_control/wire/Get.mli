(* Fetching: git9's git/get (get.c, fetchpack).
 *
 * The server lists its references. For each of HEAD, refs/heads/* and
 * refs/tags/* (or for the one branch asked for), what we have of it is
 * our copy, refs/remotes/UPSTREAM/X or refs/tags/UPSTREAM/X. We ask
 * for what differs and what we lack ("want H", with the capabilities
 * on the first line). Then we say what we have ("have H"): those
 * copies, the -h heads, and then their ancestors newest first, up to
 * 256 of them, and then "done". The pack comes back, in side-band
 * packets if the server offered them, and it is checked, indexed and
 * saved. The output is for the scripts:
 *
 *   uri: "git://host/path"                     (a remote)
 *   symref HEAD refs/heads/master
 *   remote refs/heads/master 1f7a... local 0e4c...
 *
 * (with local 0000... for what we had no copy of). *)

type opts = {
  upstream : string;           (* -u, "origin" *)
  heads : Hash.t list;         (* -h: more haves *)
  listonly : bool;             (* -l *)
  branch : string option;      (* -b: only that branch *)
}

(* The output lines go through [print], and progress and warnings
 * through [eprint]. A failure raises Proto.Error or Object.Corrupt. *)
val fetch : Store.t -> Proto.conn -> opts -> print:(string -> unit) -> eprint:(string -> unit) -> unit

(* helpers that Send and Serve share: the 40 hex digits at a string's
 * start, a line's fields between blanks, and a C string cut at its NUL *)
val hparse : string -> Hash.t option
val fields : string -> string -> string list
val cut_nul : string -> string
