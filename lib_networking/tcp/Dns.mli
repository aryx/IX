(* Dns finds a name's addresses by asking a name server (Paul
 * Mockapetris, 1983; RFC 1035). That is what getaddrinfo does in a C
 * library. mini-ml's Unix has no such resolver (its getaddrinfo knows
 * only an address written in numbers and /etc/hosts), so Tcp asks here
 * when getaddrinfo finds nothing.
 *
 * It sends one question in a UDP packet to port 53 of the first
 * "nameserver" of /etc/resolv.conf, and gets one packet back:
 *
 *     id | flags | 1 question | n answers | ...        12 bytes
 *     2 en 9 wikipedia 3 org 0 | A | IN                the question
 *     (name | type | class | ttl | length | data)*     the answers
 *
 * A name is a list of labels, each with its length first, ended by 0.
 * In an answer, a name is mostly two bytes pointing back into the
 * packet (with the top two bits set). The server asked is a resolver:
 * it follows the aliases (CNAME) itself and gives the addresses (A,
 * four bytes) with them. It is IPv4 only, as lib_core's Unix is; there
 * is no TCP for an answer cut short; the question is asked three
 * times, waiting two seconds each time.
 *
 * Here is every byte of [question ~id:0x1234 "en.wikipedia.org"]
 * (numbers have the high byte first, the network's order):
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
 * The answer repeats the question (with the flags now 81 80, which mean
 * a response with recursion available, and the count of answers filled
 * in) and adds its records after those 34 bytes. The first record
 * starts with c0 0c: the top two bits are set, and 12 is the offset of
 * the name in the question. [answers] skips names without reading
 * them, takes each record of type A and length 4, and skips the others
 * (such as a CNAME on the way) by their lengths.
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
 * Here is who walks that tree. An *authoritative* server answers for its
 * part of the tree and no more. A *recursive resolver* (an Internet
 * provider's, 8.8.8.8, 1.1.1.1) takes a whole question, asks down
 * from the root, and remembers the answers for the time each says
 * (the ttl). A *stub resolver* asks one recursive resolver and waits:
 * the C library has one, and this module is one.
 *
 * cs-history:
 * Until the 1980s the names of the ARPANET were one file, HOSTS.TXT,
 * kept by hand at SRI and copied by every host; /etc/hosts is its
 * descendant, and is still read first. A list every machine downloads
 * could not follow a network that kept growing, and one office could
 * not be asked for every name. Mockapetris's design (1983; RFC 1034
 * and 1035, 1987, still the reference) gave each organization its
 * part of the tree to run, and made the whole a database with no
 * centre but the root, which has thirteen names of root servers, a to
 * m.
 *
 * modern:
 * The question above travels in the clear and the answer is
 * believed: anyone on the path sees which names are asked, and
 * whoever answers first with the right id is believed (the id is 16
 * bits, and here it is the name's hash plus a count of the questions).
 * Resolvers now pick the port at random too, DNSSEC (2005) signs the
 * records, and browsers ask over TLS or HTTPS (RFC 8484, 2018), as one
 * more request. None of
 * that is done here: nobody checks the address this module gives,
 * except, for https://, the certificate (X509), which names the
 * host.
 *
 * References: P. Mockapetris, RFC 1034, "Domain Names: Concepts and
 * Facilities", and RFC 1035, "Domain Names: Implementation and
 * Specification" (1987): section 4.1 for the message, and 4.1.4 for
 * the pointers. *)

(* The first name server of /etc/resolv.conf, or on Plan 9 the dns= of
 * /net/ndb. It is "" when /net/ndb has no dns= (then [resolve] gives
 * []), and 127.0.0.1 when there is no /net/ndb either. *)
val server : < Cap.open_in; .. > -> string

(* The packet of a question, and the addresses in an answer to it. *)
val question : id:int -> string -> string
val answers : id:int -> string -> string list

(* The name's addresses, each as "93.184.216.34". It is [] when no
 * answer came, or when the answer had no address. *)
val resolve : < Cap.network; Cap.open_in; .. > -> string -> string list
