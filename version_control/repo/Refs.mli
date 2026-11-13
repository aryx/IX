(* References are names for commits. They are files under .git that
 * hold a hash, or "ref: " and the name of another reference (git9's
 * ref.c: readref, listrefs).
 *
 *   .git/HEAD               ref: refs/heads/master
 *   .git/refs/heads/master  1f7a7a472abf3dd9643fd615f6da379c4acb3e3a
 *
 * A name is looked for as given, then under refs/, refs/heads/,
 * refs/remotes/ and refs/tags/, and the first file found decides. If
 * there is none, the name is taken as an abbreviated hash. C git also
 * keeps references in one file, .git/packed-refs, with a "HASH NAME"
 * line for each. It is read here after the loose file of each place
 * (git9 does not read it: deliberate difference 2). *)

(* the name's hash; the store is for abbreviations *)
val read : Store.t -> string -> Hash.t option

(* what HEAD points to, such as "refs/heads/master", unless HEAD is
 * detached *)
val head_ref : Fpath.t -> string option

(* all references under refs/, as "heads/master", sorted *)
val list : Store.t -> (string * Hash.t) list

(* a reference such as "refs/heads/x" or "HEAD" is written through a
 * temporary file and a rename *)
val write : Store.t -> string -> Hash.t -> unit
val write_symbolic : Store.t -> string -> string -> unit
val remove : Store.t -> string -> unit
