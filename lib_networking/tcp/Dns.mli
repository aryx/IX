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
 * question asked three times, two seconds each.
 *
 * [question ~id:0x1234 "en.wikipedia.org"], every byte (numbers the
 * high byte first, the network's order):
 *
 *     12 34   01 00   00 01   00 00   00 00   00 00
 *     id      flags   1       no      no      no
 *             (recursion       answer, authority or additional record
 *              desired)
 *     02 65 6e   09 77 69 6b 69 70 65 64 69 61   03 6f 72 67   00
 *      2  e  n    9  w  i  k  i  p  e  d  i  a    3  o  r  g   the root
 *     00 01   00 01
 *     A       IN
 *
 * The answer repeats the question (the flags now 81 80: a response,
 * recursion available; the count of answers filled in) and adds its
 * records after those 34 bytes, the first starting c0 0c:
 * the top two bits set, and 12, the offset of the name in the
 * question. [answers] skips names without reading them, takes each
 * record of type A and length 4, and skips the others (a CNAME on
 * the way) by their lengths.
 *
 * A name is a path in a tree read from the right: the root, org,
 * wikipedia, en. Each node may hand the names under it to other
 * servers, so nobody keeps the whole list:
 *
 *     a root server       "org is served by these"
 *     an org server       "wikipedia.org is served by these"
 *     wikipedia's server  "en.wikipedia.org is at this address"
 *
 * terminology:
 * Who walks that tree. An *authoritative* server answers for its
 * part of the tree and no more. A *recursive resolver* (an Internet
 * provider's, 8.8.8.8, 1.1.1.1) takes a whole question, asks down
 * from the root, and remembers the answers for the time each says
 * (the ttl). A *stub resolver* asks one recursive resolver and waits:
 * the C library's, and this module.
 *
 * cs-history:
 * Until the 1980s the names of the ARPANET were one file, HOSTS.TXT,
 * kept by hand at SRI and copied by every host; /etc/hosts is its
 * descendant, and still read first. A list every machine downloads
 * could not follow a network that kept growing, and one office could
 * not be asked for every name. Mockapetris's design (1983; RFC 1034
 * and 1035, 1987, still the reference) gave each organization its
 * part of the tree to run, and made the whole a database with no
 * centre but the root: thirteen names of root servers, a to m.
 *
 * modern:
 * The question above travels in the clear and the answer is
 * believed: anyone on the path sees which names are asked, and
 * whoever answers first with the right id is the answer (the id is
 * 16 bits; here taken from the clock). Resolvers now take the port
 * at random too, DNSSEC (2005) signs the records, and browsers ask
 * over TLS or HTTPS (RFC 8484, 2018), as one more request. None of
 * it here: the address this gives is then checked by nobody, except,
 * for https://, by the certificate (X509), which names the host.
 *
 * References: P. Mockapetris, RFC 1034, "Domain Names: Concepts and
 * Facilities", and RFC 1035, "Domain Names: Implementation and
 * Specification" (1987): 4.1 the message, 4.1.4 the pointers. *)

(* the first name server of /etc/resolv.conf (127.0.0.1 without one) *)
val server : < Cap.open_in; .. > -> string

(* the question's packet, and the addresses of an answer to it *)
val question : id:int -> string -> string
val answers : id:int -> string -> Unix.inet_addr list

(* [] when no answer came, or none with an address *)
val resolve : < Cap.network; Cap.open_in; .. > -> string -> Unix.inet_addr list
