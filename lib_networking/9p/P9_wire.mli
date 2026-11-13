(* This is 9P2000's messages on the wire (principia's convS2M and
 * convM2S, and convD2M and convM2D for a file's entry). A message is
 * the size (4 bytes, counting itself), the type (1 byte), the tag (2),
 * then the type's fields. Numbers have the low byte first, and a
 * string is its length (2 bytes) and its bytes.
 *
 * The first message of any session is Tversion, with the kernel's size
 * (8216: 8192 bytes of data and a read's header) and the protocol's
 * name. It is these 19 bytes:
 *
 *     13 00 00 00   64   ff ff   18 20 00 00   06 00   39 50 32 30 30 30
 *     size: 19      T-   NOTAG   msize: 8216   6       9  P  2  0  0  0
 *                   version
 *
 * A request's type is even, and its response's type is the next number:
 * 100 is Tversion and 101 Rversion, up to 126 Twstat and 127 Rwstat.
 * 106, which would be Terror, is never sent, only 107 Rerror. Since the
 * size comes first a reader needs to know nothing else to cut a
 * stream into messages ([read]), and a program in the middle can
 * carry them without understanding them.
 *
 * A file's entry (what stat gives, and what a read of a directory
 * returns, as many whole entries as fit) has its own count: 2 bytes of
 * size, then the type and the device, the qid (13 bytes: type,
 * version, path), the mode, two times, the length (8 bytes) and four
 * strings (name, owner, group, and who last wrote it). In Rstat and
 * Twstat that entry is sent as a string, so it has its size twice, the
 * string's and its own: a wart of 9P2000 that every implementation
 * reproduces.
 *
 * Where it stands: P9_server reads its requests and writes its
 * responses with it, for the programs that serve files. mini-9pi's
 * kernel has a P9_wire of its own, over the kernel's types, by which
 * its Devmnt writes the requests that a system call becomes. The two
 * know nothing of each other, and agree on these bytes.
 *
 * design:
 * It is a format with no schema and no compiler: fixed fields in a
 * fixed order, one byte order, one way to say a string, nothing
 * aligned, and nothing optional. Sun's RPC for NFS, of the same years, had a
 * description language (XDR) and a generator of C; the whole of 9P's
 * marshalling is two functions a person can read, here some 160
 * lines. The price is paid on a change: a new field is a new
 * protocol version (9P2000 itself).
 *
 * References: intro(5), "Messages"; stat(5), for the entry; principia's
 * convS2M.c, convM2S.c, convD2M.c and convM2D.c. *)

(* a message's bytes *)
val encode : P9.message -> string

(* A message from its bytes (the size first). It raises Failure when
 * they are malformed. *)
val decode : string -> P9.message

(* The next message's bytes from a descriptor (a pipe, a connection):
 * it reads the size, then the rest. None at the end. *)
val read : Unix.file_descr -> string option

(* A file's entry, as a read of a directory gives it, and as Rstat
 * has it. *)
val encode_dir : Sys_plan9.dir -> string
