(* The server side: git9's git/serve (serve.c). It runs on its standard
 * input and output, in git daemon's place, under ssh, or for a local
 * clone.
 *
 * The first pkt-line names the service and the repository,
 * "git-upload-pack /path\000host=h\000". The repository is that path,
 * under -r's prefix. (git9 binds the prefix to / and the repository to
 * /, in a namespace; here the paths are joined and ".." is refused.)
 * The server offers HEAD and refs/heads/*, and the capabilities
 * "symref=HEAD:... no-thin", and nothing else: no side-band, no
 * multi_ack, no report-status.
 * - Upload: it reads the wants and the haves. The first have that we
 *   have is ACKed; otherwise there is a NAK at a flush and at the end.
 *   Then the pack is sent, raw.
 * - Receive (with -w): it reads the updates and the pack, to the end
 *   of the input, and then writes the references under .git/_lock,
 *   each one checked against its old hash. If HEAD names nothing and
 *   no reference existed, HEAD is pointed at the updated branch whose
 *   commit is newest. *)

exception Fatal of string

val serve : Store.caps -> allow_write:bool -> prefix:string option -> Proto.conn -> unit
