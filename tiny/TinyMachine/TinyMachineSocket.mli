(* This is tiny-machine's way out to other programs (plan_tiny_network.md, "On
 * Linux"). This program holds one connection of the host's and moves
 * its bytes through its standard input and output. It is a separate
 * program, as TinyMachineWindow is for the screen: tiny-machine has no
 * sockets and does no name lookups (nor does the library that mini-ml
 * puts under it). Instead, tiny-machine runs this program beside
 * itself, once for each connection, with two pipes.
 *
 *     tiny-machine-socket dial example.com 80     a connection there
 *     tiny-machine-socket listen 8080             each connection made to
 *                                                 port 8080 of this
 *                                                 machine (127.0.0.1)
 *     tiny-machine-socket name example.com        prints its address
 *
 * dial first writes one byte: + when the connection is made (within
 * five seconds), - when it cannot be. Then what it reads on its
 * standard input is written to the connection, and what comes from the
 * connection is written to its standard output, until either side ends.
 *
 * listen writes a line, + when it listens, - when it cannot. Then,
 * until its standard input ends, it writes a line for each connection
 * with the names of two named pipes. A child process relays the
 * connection through them: the first pipe is written to the
 * connection, the second is read from it, like dial's input and
 * output. The socket stays open the whole time, and connections wait
 * in its queue, so a connection that arrives before the next one is
 * taken is not refused.
 *
 *     tiny-kernel         tiny-machine                this program   the world
 *
 *     get / example.com
 *       dial, IL  ======> TinyMachinePeer: a sync for
 *                         another address: connect -> dial example.com 70
 *                                                     "+"            a TCP
 *       messages  <=====> a relay: two pipes  <=====> bytes  <=====> connection
 *
 * The machine speaks IL and the world speaks TCP; the two are joined
 * here and in TinyMachinePeer's relay, which cuts the bytes into
 * messages. This is what a home router does for the machines behind
 * it (address translation), one connection at a time, and what Plan
 * 9's machines needed a gateway for when the world did not speak IL.
 *
 * mini-qemu has the same way out inside itself (Usernet in raspberry/,
 * which is like QEMU's slirp: it answers the guest's TCP and opens a socket of
 * the host's for each of its connections). Here it is a separate
 * program, so that tiny-machine links no socket code.
 *
 * mini-ml does not compile this program, since it asks the system to
 * look up names (getaddrinfo). It is not counted among t-ix's tiny
 * programs either: it is a helper on the host side. *)
