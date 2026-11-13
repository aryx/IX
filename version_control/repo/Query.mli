(* The revision language (git9's ref.c: evalexpr, paint; query.c).
 *
 * An expression is evaluated on a stack of objects:
 * - a word (a reference, a hash, an abbreviation) pushes its object;
 * - ^ or ~ replaces the top by its first parent (a root commit's
 *   "parent" is the empty tree);
 * - @ pops two commits and pushes their lowest common ancestor;
 * - a..b or a:b, which must be the whole expression, pushes the
 *   commits reachable from b and not from a, oldest first.
 *
 *    HEAD~~          the grandparent
 *    master front @  where the two branches forked
 *    v1..HEAD        what came since v1
 *
 * All three history queries are one walk, [paint]. It takes the
 * commits newest first (from a max-heap on commit time) and colours
 * each one keep (when reached from the heads) or drop (when reached
 * from the tails). A commit reached by both becomes skip, and skip
 * colours its ancestors. Commit time is git9's: the seconds plus the
 * zone's offset. The heap and the sets are git9's own (a binary heap
 * that sifts up on equal times, and open addressing keyed by a hash's
 * first four bytes), because the order they give can be seen: it
 * decides which of several common ancestors is "the" one, and the
 * order of a range among commits of equal times. *)

exception Error of string

(* the stack, bottom first *)
val eval : Store.t -> string -> Hash.t list

(* one object, or Error "ambiguous ref expr" *)
val eval1 : Store.t -> string -> Hash.t

val lca : Store.t -> Hash.t -> Hash.t -> Hash.t option

(* the commits reachable from the heads and not from the tails, in the
 * set's order (what a pack must hold: git9's findtwixt) *)
val twixt : Store.t -> Hash.t list -> Hash.t list -> Hash.t list

(* a commit and its ancestors, each once, newest first by git9's heap
 * (log's walk) *)
val history : Store.t -> Hash.t -> (Hash.t * Object.commit) Seq.t

(* git9's heap of commits by time, for get's haves. A hash that does
 * not name a commit is not put in it. *)
type heap

val heap : unit -> heap
val put_commit : Store.t -> heap -> Hash.t -> unit
val pop_commit : heap -> Hash.t option

(* the empty tree, 4b825dc642cb6eb9a060e54bf8d69288fbee4904 *)
val empty_tree : Hash.t

(* query -c's lines between the trees of two commits: "- path" for a
 * path gone, "+ path" for a new one, "@ path" for a changed one, and
 * "! path" for a changed mode. A directory added or removed as a whole
 * lists its files and then itself, as "- dir/". *)
val changes : Store.t -> Hash.t -> Hash.t -> string list
