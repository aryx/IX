(* Dns: a name's addresses, asked of a name server (Paul Mockapetris,
 * 1983; RFC 1035). What getaddrinfo does in a C library; mini-ml's
 * Unix has none (its getaddrinfo knows an address written in numbers
 * and /etc/hosts), so Tcp asks here when that finds nothing.
 *
 * One question in a UDP packet to port 53 of the first "nameserver" of
 * /etc/resolv.conf, one packet back:
 *
 *     id | flags | 1 question | n answers | ...        12 bytes
 *     2 en 9 wikipedia 3 org 0 | A | IN                the question
 *     (name | type | class | ttl | length | data)*     the answers
 *
 * A name is labels, each its length first, ended by 0; in an answer a
 * name is mostly two bytes pointing back into the packet (the top two
 * bits set). The server asked is a resolver: it follows the aliases
 * (CNAME) itself and gives the addresses (A, four bytes) with them.
 * IPv4 only, as lib_core's Unix; no TCP for an answer cut short; the
 * question asked three times, two seconds each. *)

(* the first name server of /etc/resolv.conf (127.0.0.1 without one) *)
val server : < Cap.open_in; .. > -> string

(* the question's packet, and the addresses of an answer to it *)
val question : id:int -> string -> string
val answers : id:int -> string -> Unix.inet_addr list

(* [] when no answer came, or none with an address *)
val resolve : < Cap.network; Cap.open_in; .. > -> string -> Unix.inet_addr list
