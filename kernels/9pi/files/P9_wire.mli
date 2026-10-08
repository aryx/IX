(* 9P2000's messages on the wire (principia's convS2M and convM2S), the
 * client's half: a request encoded, a response decoded (devmnt). *)

(* a request's bytes (size[4] first) *)
val encode : P9.message -> string

(* a response from its bytes (size[4] first; Error ebadstat when
 * malformed or a request) *)
val decode : string -> P9.message
