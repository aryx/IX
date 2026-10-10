(* 9P2000's messages on the wire (principia's convS2M and convM2S, and
 * convD2M, convM2D for a file's entry): the size (4 bytes, itself
 * counted), the type (1), the tag (2), then the type's fields, numbers
 * the low byte first, a string its length (2) and its bytes.
 *
 * The first message of any session, Tversion with the kernel's size
 * (8216: 8192 bytes of data and a read's header) and the protocol's
 * name, is these 19 bytes:
 *
 *     13 00 00 00   64   ff ff   18 20 00 00   06 00   39 50 32 30 30 30
 *     size: 19      T-   NOTAG   msize: 8216   6       9  P  2  0  0  0
 *                   version
 *
 * A request's type is even and its response's the next number: 100
 * Tversion and 101 Rversion, up to 126 Twstat and 127 Rwstat; 106,
 * which would be Terror, is never sent, only 107 Rerror. Since the
 * size comes first a reader needs to know nothing else to cut a
 * stream into messages ([read]), and a program in the middle can
 * carry them without understanding them.
 *
 * A file's entry (stat's, and what a read of a directory returns, as
 * many whole entries as fit) is itself counted: 2 bytes of size, then
 * the type and device, the qid (13 bytes: type, version, path), the
 * mode, two times, the length (8) and four strings (name, owner,
 * group, who last wrote it). In Rstat and Twstat that entry is sent
 * as a string, so it has its size twice, the string's and its own:
 * a wart of 9P2000 every implementation reproduces.
 *
 * Where it stands: P9_server reads its requests and writes its
 * responses with it, for the programs that serve files. mini-9pi's
 * kernel has a P9_wire of its own, over the kernel's types, by which
 * its Devmnt writes the requests a system call becomes: the two
 * know nothing of each other and agree on these bytes.
 *
 * design:
 * A format with no schema and no compiler: fixed fields in a fixed
 * order, one byte order, one way to say a string, nothing aligned,
 * nothing optional. Sun's RPC for NFS, of the same years, had a
 * description language (XDR) and a generator of C; the whole of 9P's
 * marshalling is two functions a person can read, here some 160
 * lines. The price is paid on a change: a new field is a new
 * protocol version (9P2000 itself).
 *
 * References: intro(5), "Messages"; stat(5), the entry; principia's
 * convS2M.c, convM2S.c, convD2M.c and convM2D.c. *)

(* a message's bytes *)
val encode : P9.message -> string

(* a message from its bytes (the size first); Failure when malformed *)
val decode : string -> P9.message

(* the next message's bytes from a descriptor (a pipe, a connection):
 * its size read, then the rest; None at the end *)
val read : Unix.file_descr -> string option

(* a file's entry as a read of a directory gives it, and as Stat's *)
val encode_dir : Sys_plan9.dir -> string
