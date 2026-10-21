(* tiny-machine's way out to other programs (plan_tiny_network.md, "On
 * Linux"): one connection of the host's, its bytes on the standard
 * input and output. A program apart, as TinyMachineWindow is for the
 * screen: tiny-machine has no socket and looks no name up (nor has the
 * library mini-ml puts under it); it runs this beside itself, once for
 * each connection, with two pipes.
 *
 *     tiny-machine-socket dial example.com 80     a connection there
 *     tiny-machine-socket listen 8080             the first one made to
 *                                                 this machine's port 8080
 *                                                 (127.0.0.1's)
 *     tiny-machine-socket name example.com        its address, a line
 *
 * dial and listen first write one byte, + when the connection is
 * there (dial: within five seconds), - when it cannot be; then what
 * is read on the standard input is written to the connection and what
 * comes from it to the standard output, until either ends.
 *
 *     tiny-kernel         tiny-machine                this program   the world
 *
 *     get / example.com
 *       dial, IL  ======> TinyMachinePeer: a sync for
 *                         another address: connect -> dial example.com 70
 *                                                     "+"            a TCP
 *       messages  <=====> a relay: two pipes  <=====> bytes  <=====> connection
 *
 * The machine speaks IL and the world TCP; the two are joined here
 * and in TinyMachinePeer's relay, which cuts the bytes in messages. It is
 * what a home's router does for the machines behind it (address
 * translation), a connection at a time, and what Plan 9's machines
 * needed a gateway for when the world did not speak IL.
 *
 * Not compiled by mini-ml (it asks the system for names: getaddrinfo),
 * and not in t-ix's count of tiny programs: a helper of the host's. *)

(* A program: it gives nothing to another file. *)
