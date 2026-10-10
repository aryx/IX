(* 9P2000's messages on the wire (principia's convS2M and convM2S), the
 * client's half: a request encoded, a response decoded (devmnt).
 *
 * Every message is size[4] type[1] tag[2], then the type's fields: a
 * number its bytes the lowest first, a string a length[2] and its
 * bytes (no NUL), a qid 13 bytes (type[1] vers[4] path[8]). The size
 * counts itself; a request's type is even (Tversion 100, Tauth 102,
 * Tattach 104, Tflush 108, Twalk 110, Topen 112, Tcreate 114, Tread
 * 116, Twrite 118, Tclunk 120, Tremove 122, Tstat 124, Twstat 126),
 * its response's the next number, and 107 is Rerror.
 *
 *     T Read, tag 3, fid 5, offset 0, count 100:      23 bytes
 *
 *     17 00 00 00   74   03 00   05 00 00 00
 *     size 23       116  tag 3   fid 5
 *     00 00 00 00 00 00 00 00   64 00 00 00
 *     offset 0 (8 bytes)        count 100
 *
 *     T Version, 8216 bytes a message at most, "9P2000":   19 bytes
 *
 *     13 00 00 00   64   ff ff   18 20 00 00   06 00   39 50 32 30 30 30
 *     size 19       100  NOTAG   msize 8216    6       9  P  2  0  0  0
 *
 * A reader takes four bytes, then size - 4 more: the messages need
 * nothing else to be told apart on a stream (a pipe, a TCP
 * connection), which is all 9P asks of what carries it.
 *
 * design:
 * No description language, no generated code, no alignment: a
 * message is its fields end to end, in one byte order whatever the
 * machine, and the whole encoding and decoding is this file's 84
 * lines. Sun's RPC had XDR and a compiler for it; the gain there is
 * a new message without new code, the price a layer no one reads.
 * With thirteen messages that will not change, by hand is shorter.
 *
 * References: intro(5) of the Plan 9 manual, where this layout is
 * given, and fcall(2) for the C functions' names. *)

(* a request's bytes (size[4] first) *)
val encode : P9.message -> string

(* a response from its bytes (size[4] first; Error ebadstat when
 * malformed or a request) *)
val decode : string -> P9.message
